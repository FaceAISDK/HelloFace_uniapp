#!/usr/bin/env python3
"""Check and run a HelloFaceVerify example with its complete Android debug base."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def command(args, capture=False, timeout=None):
    result = subprocess.run([str(arg) for arg in args], text=True, timeout=timeout,
                            stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.STDOUT if capture else None)
    if result.returncode:
        raise RuntimeError((result.stdout or '').strip() or f'Command failed: {args[0]}')
    return (result.stdout or '').strip()


def executable(candidates, name):
    for value in candidates:
        if value and Path(value).is_file():
            return str(value)
    raise RuntimeError(f'{name} not found. Install it or configure its path.')


def inspect_apk(apk, appid):
    """Reject a standard base or compressed models before installing on a device."""
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        models = [item for item in archive.infolist() if item.filename.endswith('.bphfm')]
        if not models or any(item.compress_type != zipfile.ZIP_STORED for item in models):
            raise RuntimeError('The base needs uncompressed .bphfm models. Rebuild with the manifest aaptOptions.')
        abis = {name.split('/')[1] for name in names if name.startswith('lib/') and
                name.endswith('/libhiface_core.so') and
                name.replace('libhiface_core.so', 'libhiface_ncnn.so') in names}
        if not abis:
            raise RuntimeError('The base is missing the HelloFace native libraries. Build a custom base.')
        activity = b'Luts/sdk/modules/HelloFaceVerify/HelloFaceVerifyCameraActivity;'
        if not any(activity in archive.read(name) for name in names if name.endswith('.dex')):
            raise RuntimeError('The base is missing the HelloFaceVerify camera Activity.')
        control = 'assets/data/dcloud_control.xml'
        if control in names:
            apps = {node.get('appid') for node in ET.fromstring(archive.read(control)).iter('app')}
            if apps and appid not in apps:
                raise RuntimeError('The base belongs to another AppID. Rebuild it for this example.')
    return abis


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT, help='Root Vue or independent uvue example')
    parser.add_argument('--device', help='ADB device serial; required when multiple devices are connected')
    parser.add_argument('--check', action='store_true', help='Check only; do not install or launch')
    parser.add_argument('--skip-install', action='store_true', help='Use the custom base already installed')
    args = parser.parse_args()
    project = args.project.resolve()
    manifest = json.loads((project / 'manifest.json').read_text())
    appid = manifest.get('appid', '')
    if not appid or appid == '__UNI__HELLOFACE':
        raise RuntimeError('Get a real AppID in the HBuilderX manifest editor and save it first.')
    android = (manifest.get('app-plus', {}).get('distribute', {}).get('android') or
               manifest.get('app-android', {}).get('distribute', {}))
    package = android.get('packagename')
    if not package:
        raise RuntimeError('Set the Android packagename in manifest.json first.')

    hbuilder = Path(os.environ.get('HBUILDERX_PATH', '/Applications/HBuilderX.app/Contents/HBuilderX'))
    cli = executable([hbuilder / 'cli', hbuilder / 'cli.exe', hbuilder.parent / 'MacOS/cli'], 'HBuilderX CLI')
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or
               str(Path.home() / 'Library/Android/sdk'))
    adb = executable([shutil.which('adb'), sdk / 'platform-tools/adb', sdk / 'platform-tools/adb.exe'], 'ADB')
    command([sys.executable, ROOT / 'scripts/install_sdk.py', '--check', '--platform', 'android'])
    apk = project / 'unpackage/debug/android_debug.apk'
    if not apk.is_file():
        raise RuntimeError('Create the Android custom debug base in HBuilderX first: unpackage/debug/android_debug.apk')
    abis = inspect_apk(apk, appid)
    raw = command([cli, 'base', 'info', '--project', project, '--platform', 'android'], capture=True)
    info = None
    for line in raw.splitlines():
        start = line.find('{')
        if start >= 0:
            try:
                info = json.loads(line[start:])
            except json.JSONDecodeError:
                continue
    if not info or not info.get('succ') or not info.get('custom', {}).get('valid'):
        raise RuntimeError('HBuilderX did not recognize a valid custom base for this project.')
    base = info['custom']
    if base['bundleID'] != package:
        raise RuntimeError('The base package differs from manifest.json. Rebuild the custom base.')
    if base['runTimeVersion'] != info['environment']['compilerVersion']:
        raise RuntimeError('The base and HBuilderX versions differ. Rebuild the custom base.')

    rows = [line.split() for line in command([adb, 'devices'], capture=True).splitlines()[1:]]
    devices = [row[0] for row in rows if len(row) >= 2 and row[1] == 'device']
    serial = args.device
    if not serial:
        if len(devices) != 1:
            raise RuntimeError('Connect and authorize one Android device, or select it with --device SERIAL.')
        serial = devices[0]
    if serial not in devices:
        raise RuntimeError(f'Device {serial} is not connected and authorized.')
    target = [adb, '-s', serial]
    api = int(command(target + ['shell', 'getprop', 'ro.build.version.sdk'], capture=True))
    required = max(int(android.get('minSdkVersion', 23)), int(base['minSdkVersion']))
    if api < required:
        raise RuntimeError(f'Device API {api} is below the required API {required}.')
    device_abis = command(target + ['shell', 'getprop', 'ro.product.cpu.abilist'], capture=True)
    if not device_abis:
        device_abis = command(target + ['shell', 'getprop', 'ro.product.cpu.abi'], capture=True)
    if not abis.intersection(device_abis.split(',')):
        raise RuntimeError('The base does not contain a native library for this device ABI.')
    print(f'PASS: {serial}, API {api}, custom base {base["runTimeVersion"]}, {package}', flush=True)
    if args.check:
        return
    if args.skip_install:
        installed = command(target + ['shell', 'pm', 'path', package], capture=True)
        if not installed.startswith('package:'):
            raise RuntimeError('The custom base is not installed. Run again without --skip-install.')
    else:
        print('Installing the custom base. Confirm the system installation prompt on the phone.', flush=True)
        command(target + ['install', '-r', '-t', apk], timeout=180)
    # This uses the documented installed-base path; it never falls back to the standard base.
    command([cli, 'launch', 'app-android', '--project', project, '--deviceId', serial,
             '--playground', 'custom', '--customType', 'device', '--packageName', package])


if __name__ == '__main__':
    try:
        main()
    except subprocess.TimeoutExpired:
        print('Android run stopped: installation timed out; check the phone confirmation prompt.', file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, ET.ParseError) as error:
        print(f'Android run stopped: {error}', file=sys.stderr)
        raise SystemExit(1)
