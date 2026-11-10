#!/usr/bin/env python3
"""Run real native SDK integration checks against an installed Android debug base."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TEST_PACKAGE = 'dev.helloface.verify.smoke'


def run(args, env=None, timeout=180):
    result = subprocess.run([str(arg) for arg in args], env=env, capture_output=True,
                            text=True, timeout=timeout)
    output = re.sub(r'HF1:[A-Za-z0-9_-]+', '[test feature]', result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(output.strip() or f'Command failed: {args[0]}')
    return output


def instrument(target, package):
    args = target + ['shell', 'am', 'instrument', '-w', '-r',
                     TEST_PACKAGE + '/dev.helloface.smoke.NativeSdkSmoke']
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    timer = threading.Timer(180, process.kill)
    timer.start()
    output = []
    try:
        for line in process.stdout:
            line = re.sub(r'HF1:[A-Za-z0-9_-]+', '[test feature]', line)
            output.append(line)
            print(line, end='', flush=True)
            if 'READY: launch target host' in line:
                component = line.split('READY: launch target host ', 1)[1].strip()
                if not component.startswith(package + '/') or not re.fullmatch(r'[A-Za-z0-9_.$/]+', component):
                    raise RuntimeError('The native test requested an invalid host component.')
                run(target + ['shell', 'am', 'start', '-W', '-n', component], timeout=20)
        if process.wait():
            raise RuntimeError('Native instrumentation stopped or timed out.')
    finally:
        timer.cancel()
        if process.poll() is None:
            process.kill()
            process.wait()
    return ''.join(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--feature-file', type=Path, required=True,
                        help='Upstream SDK test features JSON; never use customer data')
    parser.add_argument('--keystore', type=Path, required=True, help='Same debug keystore as the target base')
    parser.add_argument('--alias', required=True)
    parser.add_argument('--package', default='dev.helloface.uniapp.demo')
    parser.add_argument('--device')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+', args.package, re.ASCII):
        raise RuntimeError('Invalid target package.')
    password = os.environ.get('HELLOFACE_TEST_STOREPASS')
    if not password:
        raise RuntimeError('Set HELLOFACE_TEST_STOREPASS to the debug keystore password first.')
    env = dict(os.environ)
    env['HELLOFACE_TEST_KEYPASS'] = env.get('HELLOFACE_TEST_KEYPASS', password)
    candidates = [env.get('ANDROID_HOME'), env.get('ANDROID_SDK_ROOT'),
                  str(Path.home() / 'Library/Android/sdk')]
    sdk = next((Path(value) for value in candidates if value and
                (Path(value) / 'platforms').is_dir() and (Path(value) / 'build-tools').is_dir()), None)
    if sdk is None:
        raise RuntimeError('Set ANDROID_HOME or ANDROID_SDK_ROOT to an SDK with platforms and build-tools.')
    platforms = [p for p in (sdk / 'platforms').glob('android-*')
                 if re.fullmatch(r'android-\d+', p.name)]
    tools = [p for p in (sdk / 'build-tools').iterdir() if re.fullmatch(r'\d+\.\d+\.\d+', p.name)]
    android = max(platforms, key=lambda p: int(p.name.split('-')[1])) / 'android.jar'
    tools = max(tools, key=lambda p: tuple(map(int, p.name.split('.'))))
    suffix = '.exe' if os.name == 'nt' else ''
    sdk_adb = sdk / 'platform-tools' / ('adb' + suffix)
    adb = str(sdk_adb) if sdk_adb.is_file() else shutil.which('adb')
    if not adb:
        raise RuntimeError('Install Android SDK platform-tools first.')
    devices = [row.split()[0] for row in run([adb, 'devices']).splitlines()[1:]
               if len(row.split()) >= 2 and row.split()[1] == 'device']
    serial = args.device or (devices[0] if len(devices) == 1 else None)
    if serial not in devices:
        raise RuntimeError('Connect one authorized device, or select it with --device.')
    target = [adb, '-s', serial]
    if not run(target + ['shell', 'pm', 'path', args.package]).strip().startswith('package:'):
        raise RuntimeError('Install the complete target debug base first.')
    try:
        run(target + ['shell', 'run-as', args.package, 'id', '-u'])
    except RuntimeError:
        raise RuntimeError('Native instrumentation requires a debuggable custom base; do not target a release APK.') from None
    fixture = json.loads(args.feature_file.read_text())
    if fixture.get('featureSpaceId') != 'jdx-feature-v1':
        raise RuntimeError('Use upstream test data from feature space jdx-feature-v1.')
    feature = fixture['entries'][0]['feature']
    if not re.fullmatch(r'HF1:[A-Za-z0-9_-]{600}', feature):
        raise RuntimeError('Invalid upstream test feature.')
    java_home = env.get('JAVA_HOME')
    javac = str(Path(java_home) / 'bin' / ('javac' + suffix)) if java_home else 'javac'
    script_suffix = '.bat' if os.name == 'nt' else ''
    with tempfile.TemporaryDirectory(prefix='helloface-native-sdk-') as temp:
        temp = Path(temp)
        assets = temp / 'assets'; assets.mkdir()
        (assets / 'fixture.json').write_text(json.dumps({'feature': feature}))
        namespace = 'http://schemas.android.com/apk/res/android'
        ET.register_namespace('android', namespace)
        def attr(key): return '{' + namespace + '}' + key
        manifest = ET.Element('manifest', {'package': TEST_PACKAGE})
        ET.SubElement(manifest, 'uses-sdk', {attr('minSdkVersion'): '23', attr('targetSdkVersion'): '28'})
        ET.SubElement(manifest, 'application', {attr('label'): 'HelloFaceVerify SDK Check', attr('debuggable'): 'true'})
        ET.SubElement(manifest, 'instrumentation', {attr('name'): 'dev.helloface.smoke.NativeSdkSmoke',
                      attr('targetPackage'): args.package})
        ET.ElementTree(manifest).write(temp / 'AndroidManifest.xml', encoding='utf-8', xml_declaration=True)
        classes = temp / 'classes'; classes.mkdir()
        dex = temp / 'dex'; dex.mkdir()
        print('Building native checks; no test features will be printed.', flush=True)
        run([javac, '-source', '8', '-target', '8', '-cp', android, '-d', classes,
             ROOT / 'tests/android/NativeSdkSmoke.java'], env)
        run([tools / ('d8' + script_suffix), '--min-api', '23', '--lib', android, '--output', dex,
             *classes.rglob('*.class')], env)
        unsigned = temp / 'unsigned.apk'; signed = temp / 'native-check.apk'
        run([tools / ('aapt' + suffix), 'package', '-f', '-M', temp / 'AndroidManifest.xml',
             '-I', android, '-A', assets, '-F', unsigned], env)
        with zipfile.ZipFile(unsigned, 'a', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(dex / 'classes.dex', 'classes.dex')
        run([tools / ('apksigner' + script_suffix), 'sign', '--ks', args.keystore.resolve(),
             '--ks-key-alias', args.alias, '--ks-pass', 'env:HELLOFACE_TEST_STOREPASS',
             '--key-pass', 'env:HELLOFACE_TEST_KEYPASS', '--out', signed, unsigned], env)
        print('Installing temporary checks; confirm the phone prompt if shown.', flush=True)
        run(target + ['install', '--no-incremental', '-r', '-t', signed])
        try:
            output = instrument(target, args.package)
            if 'INSTRUMENTATION_CODE: -1' not in output or 'PASS: 17 native integration checks.' not in output:
                raise RuntimeError('Native SDK integration checks failed; inspect the target app logcat.')
        finally:
            run(target + ['uninstall', TEST_PACKAGE])


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, IndexError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f'Android native check stopped: {error}')
