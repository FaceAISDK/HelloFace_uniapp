#!/usr/bin/env python3
"""Check and run a HelloFaceVerify example with its complete Android debug base."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import hashlib
import xml.etree.ElementTree as ET
import zipfile
from check_android_alignment import require_alignment
from install_sdk import matches
from android_debug import adb_path, app_pids, select_device, require_current_base, fingerprint, host_fingerprint, broadcast, sync_resources as app_sync

ROOT = Path(__file__).resolve().parents[1]


def command(args, capture=False, timeout=120):
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


def verify_sdk_libraries(archive, root=ROOT):
    """Derive native libraries from the locked AAR, including backend name changes."""
    root = Path(root)
    lock = json.loads((root / 'sdk-artifacts.json').read_text())
    artifact = next(a for a in lock['artifacts'] if a['platform'] == 'android')
    aar = root / 'uni_modules/HelloFace-Verify/utssdk' / artifact['destination']
    if not matches(aar, artifact):
        raise RuntimeError('Install and verify the locked Android SDK before checking the base.')
    expected = {}
    with zipfile.ZipFile(aar) as sdk:
        for name in sdk.namelist():
            if name.startswith('jni/') and name.endswith('.so'):
                _, abi, library = name.split('/')
                expected.setdefault(abi, {})[library] = hashlib.sha256(sdk.read(name)).digest()
    library_names = {name for libs in expected.values() for name in libs}
    names = set(archive.namelist())
    abis = {name.split('/')[1] for name in names if name.startswith('lib/') and name.split('/')[-1] in library_names}
    if not abis:
        raise RuntimeError('The base is missing the HelloFace native libraries. Build a custom base.')
    for abi in abis:
        if abi not in expected:
            raise RuntimeError(f'The base has a missing or stale SDK ABI: {abi}. Rebuild the custom base.')
        for library, digest in expected.get(abi, {}).items():
            name = f'lib/{abi}/{library}'
            if name not in names or hashlib.sha256(archive.read(name)).digest() != digest:
                raise RuntimeError(f'The base has a missing or stale SDK library: {name}. Rebuild the custom base.')
    return abis


def inspect_apk(apk, appid):
    """Reject a standard base or compressed models before installing on a device."""
    require_alignment(apk)
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        models = [item for item in archive.infolist() if item.filename.endswith('.bphfm')]
        if not models or any(item.compress_type != zipfile.ZIP_STORED for item in models):
            raise RuntimeError('The base needs uncompressed .bphfm models. Rebuild with the manifest aaptOptions.')
        abis = verify_sdk_libraries(archive)
        activity = b'Luts/sdk/modules/HelloFaceVerify/HelloFaceVerifyCameraActivity;'
        if not any(activity in archive.read(name) for name in names if name.endswith('.dex')):
            raise RuntimeError('The base is missing the HelloFaceVerify camera Activity.')
        control = 'assets/data/dcloud_control.xml'
        if control in names:
            apps = {node.get('appid') for node in ET.fromstring(archive.read(control)).iter('app')}
            if apps and appid not in apps:
                raise RuntimeError('The base belongs to another AppID. Rebuild it for this example.')
    return abis


def exported_resources(project, appid):
    directory = project / 'unpackage/resources' / appid / 'www'
    required = ['manifest.json', '__uniappview.html', 'app-service.js']
    if not all((directory / name).is_file() for name in required):
        raise RuntimeError('The exported uni-app page resources are incomplete.')
    if json.loads((directory / 'manifest.json').read_text()).get('id') != appid:
        raise RuntimeError('The exported page resources belong to another AppID.')
    return directory


def migrate_legacy_resources(target, package, appid):
    """Move only known shell-created demo cache aside; never delete app data."""
    uid = command(target + ['shell', 'run-as', package, 'id', '-u'], capture=True)
    apps = f'/storage/emulated/0/Android/data/{package}/apps'
    for path in [apps, apps + '/' + appid]:
        stat = subprocess.run(target + ['shell', 'stat', '-c', '%u', path], capture_output=True, text=True)
        if stat.returncode or stat.stdout.strip() == uid:
            continue
        if stat.stdout.strip() != '2000':
            raise RuntimeError('资源目录归属异常，请使用 HBuilderX 清理该基座缓存。')
        if path == apps and command(target + ['shell', 'ls', apps], capture=True).split() != [appid]:
            raise RuntimeError('旧缓存含其他 AppID，停止自动迁移。')
        source = apps + '/' + appid
        children = command(target + ['shell', 'ls', source], capture=True).split()
        if any(name not in ['www', 'www.debug-backup'] and not name.startswith('www.debug-stage-') for name in children):
            raise RuntimeError('旧 AppID 目录含非页面数据，停止自动迁移；请手工保留并迁移这些目录。')
        command(target + ['shell', 'mv', path, path + f'.shell-backup-{time.time_ns()}'])
        break
    # A previously active www can contain shell-owned nested page directories.
    # Preserve that legacy backup before the app attempts to rotate its own backup.
    backup = apps + '/' + appid + '/www.debug-backup'
    stat = subprocess.run(target + ['shell', 'stat', '-c', '%u', backup], capture_output=True, text=True)
    if stat.returncode == 0:
        owners = command(target + ['shell', 'find', backup, '-type', 'd', '-exec', 'stat', '-c', '%u', '{}', '+'], capture=True).split()
        if any(owner not in [uid, '2000'] for owner in owners):
            raise RuntimeError('页面备份目录归属异常，停止自动迁移。')
        if '2000' in owners:
            command(target + ['shell', 'mv', backup, backup + f'.shell-backup-{time.time_ns()}'])


def installed_hash(target, package):
    result = subprocess.run(target + ['shell', 'pm', 'path', package], capture_output=True, text=True)
    paths = [line.partition(':')[2] for line in result.stdout.splitlines() if line.startswith('package:')]
    if len(paths) != 1:
        return None
    result = subprocess.run(target + ['shell', 'sha256sum', paths[0]], capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.split():
        return result.stdout.split()[0]
    # The APK is public code, not app-private user data. Support older vendor shells.
    result = subprocess.run(target + ['exec-out', 'cat', paths[0]], capture_output=True, timeout=60)
    return hashlib.sha256(result.stdout).hexdigest() if result.returncode == 0 else None


def startup_health(target, package, api):
    # Do not treat Activity launch confirmation alone as evidence that the Vue page loaded.
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        pid = ' '.join(app_pids(target, package))
        if pid and api >= 24:
            raw = command(target + ['logcat', '-d', '--pid=' + pid.split()[0], '-t', '600', '-v', 'brief'], capture=True)
            if 'FATAL EXCEPTION' in raw:
                raise RuntimeError('应用启动期间发生原生异常。执行 npm run android:logs 查看当前进程日志。')
            if '请求的页面无法打开' in raw:
                raise RuntimeError('App 无法读取页面资源，请重新执行应用内同步；不要直接向外部目录 mkdir/push。')
        time.sleep(.5)
    if not pid:
        raise RuntimeError('启动后未检测到 App 进程，请执行 npm run android:logs 排查。')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT, help='Root Vue or independent uvue example')
    parser.add_argument('--device', help='ADB device serial; required when multiple devices are connected')
    parser.add_argument('--check', action='store_true', help='Check only; do not install or launch')
    parser.add_argument('--skip-install', action='store_true', help='Use the custom base already installed')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--sync-resources', action='store_true', help='Use app-owned Vue resource synchronization (default for Vue)')
    mode.add_argument('--hbuilder', action='store_true', help='Use the standard HBuilderX run/watch channel')
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
    is_uvue = (project / 'App.uvue').exists()
    use_sync = not is_uvue and not args.hbuilder
    if args.sync_resources and is_uvue:
        raise RuntimeError('uvue 使用 HBuilderX 原生编译，不能走 Vue 页面资源同步。')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', appid) or not re.fullmatch(
            r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+', package, re.ASCII):
        raise RuntimeError('Invalid AppID or Android package for resource synchronization.')

    hbuilder = Path(os.environ.get('HBUILDERX_PATH', '/Applications/HBuilderX.app/Contents/HBuilderX'))
    cli = executable([hbuilder / 'cli', hbuilder / 'cli.exe', hbuilder.parent / 'MacOS/cli'], 'HBuilderX CLI')
    adb = adb_path()
    selected = select_device(adb, args.device)
    serial = selected['serial']
    print(f'设备：{selected["model"]} ({serial})', flush=True)
    command([sys.executable, ROOT / 'scripts/install_sdk.py', '--check', '--platform', 'android'])
    apk = project / 'unpackage/debug/android_debug.apk'
    if not apk.is_file():
        raise RuntimeError('Create the Android custom debug base in HBuilderX first: unpackage/debug/android_debug.apk')
    abis = inspect_apk(apk, appid)
    expected = require_current_base(apk)
    expected_host = host_fingerprint(project)
    if project != ROOT and fingerprint(project) != expected:
        raise RuntimeError('目标工程插件副本不同步；uvue 请先执行 npm run demo:prepare。')
    raw = command([cli, 'base', 'info', '--project', project, '--platform', 'android'], capture=True)
    info = None
    for line in raw.splitlines():
        start = line.find('{')
        if start >= 0:
            try:
                info = json.loads(line[start:])
            except json.JSONDecodeError:
                continue
    if '未检测到已打开的HBuilderX' in raw:
        raise RuntimeError('请先打开 HBuilderX 和当前工程。')
    if not info or not info.get('succ') or not info.get('custom', {}).get('valid'):
        raise RuntimeError('HBuilderX did not recognize a valid custom base for this project.')
    base = info['custom']
    if base['bundleID'] != package:
        raise RuntimeError('The base package differs from manifest.json. Rebuild the custom base.')
    if base['runTimeVersion'] != info['environment']['compilerVersion']:
        raise RuntimeError('The base and HBuilderX versions differ. Rebuild the custom base.')

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
    page_size = command(target + ['shell', 'getconf', 'PAGE_SIZE'], capture=True)
    apk_hash = hashlib.sha256(apk.read_bytes()).hexdigest()
    receipt = project / 'unpackage/debug/base-build.json'
    if receipt.is_file():
        recorded = json.loads(receipt.read_text())
        if recorded.get('apkSha256') == apk_hash and recorded.get('hostFingerprint') != expected_host:
            raise RuntimeError('宿主原生配置已改变，请执行 npm run android:base 重建基座。')
    print(f'PASS: API {api}, 内存页 {page_size} B, 基座 {base["runTimeVersion"]}, 原生指纹一致', flush=True)
    if args.check:
        return
    same_base = installed_hash(target, package) == apk_hash
    if args.skip_install and not same_base:
        raise RuntimeError('手机安装包与已校验的基座不同，请去掉 --skip-install 重新安装。')
    if same_base:
        print('手机已安装相同基座，跳过安装。', flush=True)
    else:
        print('正在安装调试基座；如手机出现提示，请允许本次安装。', flush=True)
        command(target + ['install', '--no-incremental', '-r', '-t', apk], timeout=180)
        if installed_hash(target, package) != apk_hash:
            raise RuntimeError('安装后 APK 指纹不一致，停止同步。')
    if use_sync:
        try:
            info = broadcast(target, package, 'INFO')
        except RuntimeError as error:
            if not str(error).startswith('调试接收器未响应'):
                raise
            info = None
        if info and info.get('busy'):
            raise RuntimeError('人脸操作正在进行，请先返回示例页面。')
        state = command(target + ['shell', 'dumpsys', 'activity', 'activities'], capture=True)
        foreground = next((line for line in state.splitlines() if 'topResumedActivity' in line or 'mResumedActivity' in line), '')
        if package + '/' not in foreground:
            # MIUI Greezer defers even explicit broadcasts to a cached background app.
            command(target + ['shell', 'am', 'start', '-W', '-n', f'{package}/io.dcloud.PandoraEntry'], capture=True, timeout=30)
        info = broadcast(target, package, 'INFO')
        if info.get('fingerprint') != expected:
            raise RuntimeError('手机基座原生指纹不同，请重新安装。')
        if info.get('busy'):
            raise RuntimeError('人脸操作正在进行，请先返回示例页面。')
        print('正在编译 Vue 页面资源…', flush=True)
        command([cli, 'publish', 'app-android', '--type', 'appResource', '--project', project], timeout=180)
        resources = exported_resources(project, appid)
        if fingerprint() != expected or host_fingerprint(project) != expected_host:
            raise RuntimeError('页面编译期间原生源码或宿主配置发生变化，停止同步；请重建相应基座。')
        if api >= 30:
            migrate_legacy_resources(target, package, appid)
        response = app_sync(target, package, appid, resources, expected)
        command(target + ['shell', 'am', 'force-stop', package])
        output = command(target + ['shell', 'am', 'start', '-W',
                                   '-n', f'{package}/io.dcloud.PandoraEntry'], capture=True, timeout=30)
        if 'Status: ok' not in output:
            raise RuntimeError('Android 未确认启动成功。')
        startup_health(target, package, api)
        report = {'package': package, 'device': serial, 'api': api, 'pageSize': int(page_size),
                  'fingerprint': expected, 'apkSha256': apk_hash, 'resources': response['files'],
                  'resourceSha256': response['sha256'], 'started': True}
        path = project / 'unpackage/debug/last-run.json'
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(f'已同步 {response["files"]} 个资源文件并启动示例。记录：{path}', flush=True)
        return
    # This uses the documented installed-base path; it never falls back to the standard base.
    command([cli, 'launch', 'app-android', '--project', project, '--deviceId', serial,
             '--playground', 'custom', '--customType', 'device', '--packageName', package], timeout=None)


if __name__ == '__main__':
    try:
        main()
    except subprocess.TimeoutExpired:
        print('Android 调试超时：请检查当前步骤的 HBuilderX 状态和手机安装提示。', file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, ET.ParseError) as error:
        message = str(error)
        if 'INSTALL_FAILED_USER_RESTRICTED' in message:
            message = '手机拒绝安装。请开启 USB 安装，并允许本次 HelloFaceVerify 安装。'
        elif 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' in message:
            message = '签名与已安装 App 不同，请用原证书重建基座；卸载会丢失本机录入数据。'
        print(f'Android 调试停止：{message}', file=sys.stderr)
        raise SystemExit(1)
