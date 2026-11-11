import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('sdk_installer', Path(__file__).parents[1] / 'scripts/install_sdk.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class SDKIntegrityTests(unittest.TestCase):
    def test_rejects_same_length_tampering_and_lfs_pointer(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'sdk.bin'
            original = b'public SDK artifact'
            artifact = {'size': len(original), 'sha256': hashlib.sha256(original).hexdigest()}
            path.write_bytes(original)
            self.assertTrue(installer.matches(path, artifact))
            path.write_bytes(b'x' * len(original))
            self.assertFalse(installer.matches(path, artifact))
            path.write_text('version https://git-lfs.github.com/spec/v1\n')
            self.assertFalse(installer.matches(path, artifact))

    def test_check_never_creates_missing_artifact(self):
        with tempfile.TemporaryDirectory() as folder:
            previous = installer.PLUGIN
            installer.PLUGIN = Path(folder)
            try:
                artifact = {'destination': 'missing/sdk.har', 'size': 1, 'sha256': '0' * 64}
                with self.assertRaisesRegex(RuntimeError, 'Missing or mismatched'):
                    installer.install(artifact, {}, check=True)
                self.assertFalse((Path(folder) / 'missing').exists())
            finally:
                installer.PLUGIN = previous

    def test_failed_install_preserves_existing_file(self):
        with tempfile.TemporaryDirectory() as folder:
            previous = installer.PLUGIN
            installer.PLUGIN = Path(folder)
            path = Path(folder) / 'sdk.har'
            path.write_bytes(b'existing')
            try:
                artifact = {'destination': 'sdk.har', 'source': 'absent.har', 'size': 1, 'sha256': '0' * 64, 'lfs': True}
                with self.assertRaises(KeyError):
                    installer.install(artifact, {})
                self.assertEqual(path.read_bytes(), b'existing')
                self.assertEqual(list(Path(folder).glob('*.part')), [])
            finally:
                installer.PLUGIN = previous

    def test_sdk_upgrade_retires_only_versioned_sdk_libraries_and_retains_backup(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); libs = root / 'uni_modules/HelloFace-Verify/utssdk/app-android/libs'
            libs.mkdir(parents=True)
            old = libs / 'hiface-0.8.8.aar'; old.write_bytes(b'previous SDK')
            (libs / 'hiface-0.8.11.aar').write_bytes(b'new SDK')
            (libs / 'customer.aar').write_bytes(b'custom')
            (libs / 'license.json').write_text('keep')
            artifacts = [{'destination': 'app-android/libs/hiface-0.8.11.aar'}]
            with self.assertRaisesRegex(RuntimeError, 'Obsolete SDK'):
                installer.retire_obsolete(artifacts, root, check=True)
            self.assertTrue(old.exists())
            self.assertEqual(installer.retire_obsolete(artifacts, root), ['hiface-0.8.8.aar'])
            self.assertFalse(old.exists())
            backups = list((root / '.sdk-cache/retired-sdk').iterdir())
            self.assertEqual([p.read_bytes() for p in backups], [b'previous SDK'])
            self.assertTrue((libs / 'customer.aar').exists())
            self.assertEqual((libs / 'license.json').read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
