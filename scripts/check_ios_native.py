#!/usr/bin/env python3
"""Check iOS Swift syntax, real camera state transitions and UIKit presentation types."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'uni_modules/HelloFace-Verify/utssdk/app-ios'


def run(args):
    subprocess.run([str(x) for x in args], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full', action='store_true', help='Also typecheck all sources with the real SDK; requires a compatible Xcode')
    args = parser.parse_args()
    sources = sorted(IOS.glob('*.swift'))
    run(['xcrun', 'swiftc', '-frontend', '-parse', *sources])
    print(f'PASS {len(sources)} Swift files parsed', flush=True)
    with tempfile.TemporaryDirectory(prefix='helloface-ios-check-') as directory:
        executable = Path(directory) / 'camera-state-checks'
        run(['xcrun', 'swiftc', IOS / 'HelloFaceVerifyCameraState.swift', ROOT / 'tests/ios/CameraStateChecks.swift', '-o', executable])
        run([executable])
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
        common = ['xcrun', 'swiftc', '-typecheck', '-sdk', sdk, '-target', 'arm64-apple-ios15.0',
                  '-strict-concurrency=complete', '-warn-concurrency',
                  '-module-cache-path', Path(directory) / 'module-cache']
        run([*common, IOS / 'HelloFaceVerifyPresentation.swift', IOS / 'HelloFaceVerifyCameraState.swift', IOS / 'HelloFaceVerifyCameraView.swift'])
        print('PASS real UIKit view + animation/state types (no SDK substitution)', flush=True)
        # Compile-only SDK boundary lets old Xcode still check every platform API call.
        # The stand-in has no runnable algorithms and is never copied to the plugin.
        boundary = Path(directory) / 'boundary'
        boundary.mkdir()
        run(['xcrun', 'swiftc', '-emit-module', '-module-name', 'HiFace', '-sdk', sdk,
             '-target', 'arm64-apple-ios15.0', '-module-cache-path', Path(directory) / 'module-cache',
             ROOT / 'tests/ios/HiFaceCompileBoundary.swift', '-emit-module-path', boundary / 'HiFace.swiftmodule'])
        run([*common, '-I', boundary, *sources])
        print('PASS all UIKit/AVFoundation plumbing types (compile-only SDK boundary; no SDK validation)', flush=True)
        if args.full:
            framework = IOS / 'Frameworks'
            run([*common, '-F', framework / 'HiFace.xcframework/ios-arm64',
                 '-F', framework / 'HiFaceNative.xcframework/ios-arm64', *sources])
            print('PASS all Swift sources typechecked against the real SDK', flush=True)
        else:
            print('NOT RUN: real SDK full typecheck (--full), complete App linking, device validation', flush=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
