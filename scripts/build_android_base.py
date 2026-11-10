#!/usr/bin/env python3
"""Build a stamped custom base with local signing configuration and verify it."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from android_debug import ROOT, prepare, host_fingerprint, require_current_base, run
from run_android import executable, inspect_apk


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    args = parser.parse_args()
    project = args.project.resolve()
    manifest = json.loads((project / 'manifest.json').read_text())
    appid = manifest.get('appid', '')
    if not appid or appid == '__UNI__HELLOFACE':
        raise RuntimeError('请先在 HBuilderX 获取有效 AppID。')
    if (project / 'App.uvue').exists():
        raise RuntimeError('uvue 基座请先 android:prepare、demo:prepare，再在 HBuilderX 中制作。')
    android = manifest.get('app-plus', {}).get('distribute', {}).get('android', {})
    package = android.get('packagename')
    if not package:
        raise RuntimeError('请在 manifest.json 配置 Android 包名。')
    local = ROOT / '.sdk-cache/android-debug'
    config = local / 'signing.json'
    signing = json.loads(config.read_text()) if config.is_file() else {}
    cert = Path(os.environ.get('HELLOFACE_ANDROID_CERTFILE') or signing.get('file') or local / 'helloface-demo.jks')
    alias = os.environ.get('HELLOFACE_ANDROID_CERTALIAS') or signing.get('alias')
    storepass = os.environ.get('HELLOFACE_ANDROID_STOREPASS') or signing.get('password')
    keypass = os.environ.get('HELLOFACE_ANDROID_KEYPASS') or signing.get('keyPassword') or storepass
    if not cert.is_file() or not alias or not storepass:
        raise RuntimeError('缺少本机调试签名配置。设置 HELLOFACE_ANDROID_CERTFILE/CERTALIAS/STOREPASS，'
                           '或按 docs/ANDROID_DEBUG.md 配置被 Git 忽略的 signing.json。')
    run([sys.executable, ROOT / 'scripts/install_sdk.py', '--check', '--platform', 'android'])
    expected = prepare()
    expected_host = host_fingerprint(project)
    hbuilder = Path(os.environ.get('HBUILDERX_PATH', '/Applications/HBuilderX.app/Contents/HBuilderX'))
    cli = executable([hbuilder / 'cli', hbuilder / 'cli.exe', hbuilder.parent / 'MacOS/cli'], 'HBuilderX CLI')
    run([cli, 'open', '--path', project], timeout=30)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        info = run([cli, 'base', 'info', '--project', project, '--platform', 'android'], timeout=10)
        if '"succ":true' in info or '"succ": true' in info:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('HBuilderX 尚未就绪，请打开工程后重试。')
    output = project / 'unpackage/debug'
    output.mkdir(parents=True, exist_ok=True)
    apk = output / 'android_debug.apk'
    before = apk.stat().st_mtime_ns if apk.exists() else None
    arguments = [cli, 'pack', '--project', str(project), '--platform', 'android', '--iscustom', 'true',
                 '--safemode', 'false', '--isconfusion', 'false', '--android.packagename', package,
                 '--android.androidpacktype', '0', '--android.certfile', str(cert.resolve()),
                 '--android.certalias', alias, '--android.certpassword', keypass, '--android.storepassword', storepass]
    print('正在制作自定义基座；签名配置和完整构建日志仅保存在本机。', flush=True)
    process = subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        with (output / 'cloud-build.log').open('w') as log:
            (output / 'cloud-build.log').chmod(0o600)
            for line in process.stdout:
                log.write(line); log.flush()
                safe = line
                for secret in [storepass, keypass]:
                    safe = safe.replace(secret, '[redacted]')
                # DCloud output may include signed download/publishing URLs.
                if not any(value in safe.lower() for value in ['http://', 'https://', 'token=', 'password']):
                    print(safe, end='', flush=True)
        if process.wait():
            raise RuntimeError('HBuilderX 打包失败，请查看本机 cloud-build.log。')
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
    if not apk.is_file() or apk.stat().st_mtime_ns == before:
        raise RuntimeError('未收到新的基座 APK，请检查 HBuilderX 登录、打包状态和本机构建日志。')
    if prepare() != expected or host_fingerprint(project) != expected_host:
        raise RuntimeError('打包期间原生源码或宿主配置发生变化，请重新构建。')
    require_current_base(apk)
    inspect_apk(apk, appid)
    report = {'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'fingerprint': expected,
              'hostFingerprint': expected_host, 'package': package, 'appid': appid,
              'builtAt': int(time.time()), 'alignment': 'passed'}
    (output / 'base-build.json').write_text(json.dumps(report, indent=2) + '\n')
    print('基座构建及源码指纹、SDK、模型、16KB 对齐校验通过。执行 npm run android:run 即可运行。')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        raise SystemExit('已停止等待；云端任务状态可在 HBuilderX 中查看。')
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit('Android 基座构建停止：' + str(error))
