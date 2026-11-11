import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from run_android import verify_sdk_libraries


class AndroidSdkLibrariesTests(unittest.TestCase):
    def fixture(self, root):
        aar = root / 'uni_modules/HelloFace-Verify/utssdk/app-android/libs/sdk.aar'
        aar.parent.mkdir(parents=True)
        with zipfile.ZipFile(aar, 'w') as archive:
            archive.writestr('jni/arm64-v8a/libhiface_core.so', b'new-core')
            archive.writestr('jni/arm64-v8a/libhiface_opencv.so', b'new-backend')
        (root / 'sdk-artifacts.json').write_text(json.dumps({'artifacts': [{'platform': 'android',
            'destination': 'app-android/libs/sdk.aar', 'size': aar.stat().st_size,
            'sha256': hashlib.sha256(aar.read_bytes()).hexdigest()}]}))

    def test_new_backend_is_derived_from_locked_aar(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.fixture(root)
            apk = root / 'base.apk'
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('lib/arm64-v8a/libhiface_core.so', b'new-core')
                archive.writestr('lib/arm64-v8a/libhiface_opencv.so', b'new-backend')
            with zipfile.ZipFile(apk) as archive:
                self.assertEqual(verify_sdk_libraries(archive, root), {'arm64-v8a'})

    def test_missing_backend_or_old_core_is_rejected(self):
        for core, backend, abi in [(b'new-core', False, 'arm64-v8a'), (b'old-core', True, 'arm64-v8a'), (b'new-core', True, 'x86')]:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory); self.fixture(root)
                apk = root / 'base.apk'
                with zipfile.ZipFile(apk, 'w') as archive:
                    archive.writestr(f'lib/{abi}/libhiface_core.so', core)
                    archive.writestr(f'lib/{abi}/libhiface_ncnn.so', b'old-backend')
                    if backend: archive.writestr(f'lib/{abi}/libhiface_opencv.so', b'new-backend')
                with zipfile.ZipFile(apk) as archive, self.assertRaisesRegex(RuntimeError, 'missing or stale'):
                    verify_sdk_libraries(archive, root)
