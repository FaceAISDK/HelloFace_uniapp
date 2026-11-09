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


if __name__ == '__main__':
    unittest.main()
