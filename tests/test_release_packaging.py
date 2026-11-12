import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from build_android_base import download_release
from make_apk_variant import build_tool


class ApkBuildToolTests(unittest.TestCase):
    def test_selects_latest_numeric_version_and_ignores_unsupported_tools(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for version in ('9.0.0', '34.0.0', '35.0.0', '36.0.0'):
                tool = root / 'sdk/build-tools' / version / 'zipalign'
                tool.parent.mkdir(parents=True)
                tool.touch()
            with patch.dict(os.environ, {'ANDROID_HOME': str(root / 'sdk')}, clear=True), \
                    patch('make_apk_variant.Path.home', return_value=root / 'home'):
                self.assertEqual(build_tool('zipalign'), str(root / 'sdk/build-tools/36.0.0/zipalign'))

    def test_rejects_tools_older_than_required_version(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tool = root / 'sdk/build-tools/34.0.0/zipalign'
            tool.parent.mkdir(parents=True)
            tool.touch()
            with patch.dict(os.environ, {'ANDROID_HOME': str(root / 'sdk')}, clear=True), \
                    patch('make_apk_variant.Path.home', return_value=root / 'home'):
                with self.assertRaisesRegex(RuntimeError, 'Build-Tools 35'):
                    build_tool('zipalign')


class ReleaseDownloadTests(unittest.TestCase):
    def test_receives_cli_download_link_through_stdin_without_exposing_it_in_arguments(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            url = 'https://downloads.example.test/get?token=private-example'
            (root / 'cloud-build.log').write_text('\x1b[32m下载地址: ' + url + '\x1b[39m （临时地址）\n')

            def curl(command, **kwargs):
                self.assertNotIn(url, ' '.join(command))
                self.assertEqual(kwargs['input'], 'url = "' + url + '"\n')
                path = Path(command[command.index('--output') + 1])
                with zipfile.ZipFile(path, 'w') as archive:
                    archive.writestr('manifest.json', '{}')
                return subprocess.CompletedProcess(command, 0, '', '')

            with patch('build_android_base.subprocess.run', side_effect=curl):
                artifact = download_release(root, '0.1.5')
            self.assertTrue(zipfile.is_zipfile(artifact))
            self.assertFalse(artifact.with_suffix('.download').exists())

    def test_does_not_mistake_promotional_links_for_a_build_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'cloud-build.log').write_text('打包中 https://example.test/promotion.apk\n')
            with patch('build_android_base.subprocess.run') as curl:
                with self.assertRaisesRegex(RuntimeError, '下载地址'):
                    download_release(root, '0.1.5')
                curl.assert_not_called()

    def test_rejects_an_html_response_and_keeps_an_existing_apk(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'cloud-build.log').write_text('下载地址: https://example.test/get\n')
            existing = root / 'HelloFace-Demo-0.1.5-release.apk'
            existing.write_bytes(b'previous-artifact')

            def curl(command, **kwargs):
                Path(command[command.index('--output') + 1]).write_text('<html>expired</html>')
                return subprocess.CompletedProcess(command, 0, '', '')

            with patch('build_android_base.subprocess.run', side_effect=curl):
                with self.assertRaisesRegex(RuntimeError, '下载失败'):
                    download_release(root, '0.1.5')
            self.assertEqual(existing.read_bytes(), b'previous-artifact')
            self.assertFalse(existing.with_suffix('.download').exists())
