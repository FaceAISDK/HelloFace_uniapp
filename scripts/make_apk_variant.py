#!/usr/bin/env python3
"""从 Demo 通用 APK 生成额外的单 ABI 版本，保持签名身份和原包不变。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

from android_debug import ROOT
from build_android_base import signing_settings
from run_android import inspect_apk


def build_tool(name):
    roots = [os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'),
             Path.home() / 'Library/Android/sdk', Path.home() / 'Android/Sdk']
    for root in roots:
        if not root:
            continue
        versions = []
        for directory in (Path(root) / 'build-tools').glob('*'):
            match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:-.*)?', directory.name)
            if match and int(match[1]) >= 35:
                versions.append((tuple(map(int, match.groups())), directory))
        # 按数值选版本，避免字符串排序把 9.x 排在 36.x 前；16KB 对齐要求 35+。
        for _, directory in sorted(versions, reverse=True):
            candidate = directory / name
            if candidate.is_file():
                return str(candidate)
    raise RuntimeError('请安装 Android SDK Build-Tools 35+：' + name)


def run(command, **kwargs):
    result = subprocess.run([str(arg) for arg in command], capture_output=True, text=True, **kwargs)
    if result.returncode:
        raise RuntimeError('Android 构建工具执行失败：' + Path(command[0]).name)
    return result.stdout


def certificate(apksigner, apk):
    result = run([apksigner, 'verify', '--print-certs', apk])
    digest = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)', result)
    if not digest:
        raise RuntimeError('无法核对 APK 的签名证书')
    return digest.group(1).lower()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--abi', choices=['arm64-v8a', 'armeabi-v7a'], default='arm64-v8a')
    args = parser.parse_args()
    source = args.apk.resolve()
    output = source.with_name(source.stem + '-' + args.abi + '.apk')
    appid = json.loads((ROOT / 'manifest.json').read_text())['appid']
    if args.abi not in inspect_apk(source, appid):
        raise RuntimeError('原包不含所选 ABI')
    cert, alias, storepass, keypass = signing_settings()
    apksigner, zipalign = build_tool('apksigner'), build_tool('zipalign')
    original_signer = certificate(apksigner, source)
    with tempfile.TemporaryDirectory(prefix='.helloface-apk-', dir=source.parent) as work:
        unsigned, aligned, signed = [Path(work) / name for name in ('unsigned.apk', 'aligned.apk', 'signed.apk')]
        with zipfile.ZipFile(source) as old, zipfile.ZipFile(unsigned, 'w') as new:
            for item in old.infolist():
                name = item.filename
                if name.startswith('lib/') and name.split('/')[1] != args.abi:
                    continue
                # 只移除旧 JAR 签名，保留 META-INF 下的协议和其他运行资源。
                if name.upper().startswith('META-INF/') and (name.upper().endswith(('.SF', '.RSA', '.DSA', '.EC'))
                                                               or name.upper() == 'META-INF/MANIFEST.MF'):
                    continue
                new.writestr(item, old.read(item))
        run([zipalign, '-P', '16', '-f', '4', unsigned, aligned])
        env = dict(os.environ, HFV_VARIANT_STOREPASS=storepass, HFV_VARIANT_KEYPASS=keypass)
        run([apksigner, 'sign', '--ks', cert, '--ks-key-alias', alias,
             '--ks-pass', 'env:HFV_VARIANT_STOREPASS', '--key-pass', 'env:HFV_VARIANT_KEYPASS',
             '--out', signed, aligned], env=env)
        if certificate(apksigner, signed) != original_signer:
            raise RuntimeError('签名身份不一致，不得用此变体覆盖原 App')
        if inspect_apk(signed, appid) != {args.abi}:
            raise RuntimeError('APK 变体未保留预期 ABI')
        # 校验通过才发布产物；原包中仍被保留的资源、代码和模型必须逐项一致。
        with zipfile.ZipFile(source) as old, zipfile.ZipFile(signed) as new:
            for name in new.namelist():
                if not name.upper().startswith('META-INF/'):
                    if hashlib.sha256(old.read(name)).digest() != hashlib.sha256(new.read(name)).digest():
                        raise RuntimeError('变体改变了运行文件：' + name)
        signed.replace(output)
    print(f'{output}: {source.stat().st_size:,} → {output.stat().st_size:,} bytes; ABI={args.abi}; 签名和保留文件一致')


if __name__ == '__main__':
    main()
