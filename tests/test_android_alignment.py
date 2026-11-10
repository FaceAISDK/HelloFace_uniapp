import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('android_alignment',
    Path(__file__).resolve().parents[1] / 'scripts/check_android_alignment.py')
alignment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(alignment)


def elf(load_alignment=16384, relro_end=16384, load_end=32768, virtual_address=0):
    data = bytearray(256)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, 2)
    struct.pack_into('<IIQQQQQQ', data, 64, 1, 6, 0, virtual_address, 0, 256, load_end, load_alignment)
    struct.pack_into('<IIQQQQQQ', data, 120, 0x6474e552, 4, 0, virtual_address, 0, 0, relro_end, 1)
    return bytes(data)


class AlignmentTests(unittest.TestCase):
    def test_aligned_load_and_relro(self):
        self.assertEqual(alignment.elf_issues(elf()), [])
        self.assertEqual(alignment.elf_issues(elf(load_alignment=65536)), [])

    def test_rejects_4kb_load(self):
        self.assertTrue(any('LOAD alignment' in item for item in alignment.elf_issues(elf(load_alignment=4096))))

    def test_rejects_incongruent_load_address(self):
        self.assertTrue(any('congruent' in item for item in alignment.elf_issues(elf(virtual_address=4096))))

    def test_relro_cannot_protect_writable_trailing_data(self):
        self.assertTrue(any('RELRO' in item for item in alignment.elf_issues(elf(relro_end=4096))))
        self.assertEqual(alignment.elf_issues(elf(relro_end=4096, load_end=4096)), [])

    def test_invalid_elf_does_not_pass(self):
        for data in [b'', b'not ELF', elf()[:100]]:
            with self.assertRaises(ValueError):
                alignment.elf_issues(data)

    def test_apk_requires_alignment_for_uncompressed_library(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.apk'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('lib/arm64-v8a/libtest.so', elf())
            report = alignment.inspect_archive(path)
            self.assertFalse(report['passed'])
            self.assertIn('ZIP', report['libraries'][0]['issues'][0])
            with self.assertRaises(ValueError):
                alignment.require_alignment(path)
            name = 'lib/arm64-v8a/libtest.so'
            entry = zipfile.ZipInfo(name)
            padding = alignment.PAGE - 30 - len(name)
            entry.extra = struct.pack('<HH', 0xffff, padding - 4) + bytes(padding - 4)
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr(entry, elf())
            self.assertTrue(alignment.require_alignment(path)['passed'])

    def test_compression_does_not_hide_elf_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.apk'
            for data, passed in [(elf(), True), (elf(relro_end=4096), False)]:
                with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr('lib/arm64-v8a/libtest.so', data)
                self.assertEqual(alignment.inspect_archive(path)['passed'], passed)

    def test_aar_does_not_need_zip_alignment_but_needs_64bit_libraries(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.aar'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('jni/arm64-v8a/libtest.so', elf())
            self.assertTrue(alignment.require_alignment(path)['passed'])
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('jni/armeabi-v7a/libtest.so', b'32-bit library')
            with self.assertRaises(ValueError):
                alignment.inspect_archive(path)


if __name__ == '__main__':
    unittest.main()
