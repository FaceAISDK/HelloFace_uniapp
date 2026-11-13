import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('android_debug', Path(__file__).resolve().parents[1] / 'scripts/android_debug.py')
debug = importlib.util.module_from_spec(spec)
spec.loader.exec_module(debug)


watch_spec = importlib.util.spec_from_file_location('dev_android', Path(__file__).resolve().parents[1] / 'scripts/dev_android.py')
watch = importlib.util.module_from_spec(watch_spec)
with patch.dict(sys.modules, {'android_debug': debug}):
    watch_spec.loader.exec_module(watch)


class AndroidDebugTests(unittest.TestCase):
    def project(self, root):
        uts = root / debug.PLUGIN
        (uts / 'app-android/libs').mkdir(parents=True)
        for name in ['interface.uts', 'shared.uts', 'unierror.uts', 'app-android/Bridge.kt', 'app-android/libs/sdk.aar']:
            (uts / name).write_bytes(name.encode())
        (root / 'pages').mkdir()
        (root / 'pages/index.vue').write_text('page one')
        (root / 'manifest.json').write_text(json.dumps({'appid': '__UNI__TEST', 'versionName': '1',
            'app-plus': {'distribute': {'android': {'packagename': 'dev.example.demo', 'minSdkVersion': 23}}}}))
        return uts

    def test_watch_detects_changes_and_removal_of_new_shared_helpers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); uts = self.project(root)
            with patch.object(watch, 'ROOT', root):
                cache = {}
                first = watch.snapshot(root, cache)
                helper = uts / 'status.uts'
                helper.write_text('first status')
                added = watch.snapshot(root, cache)
                self.assertNotEqual(first, added)
                helper.write_text('updated status')
                self.assertNotEqual(added, watch.snapshot(root, cache))
                helper.unlink()
                self.assertEqual(first, watch.snapshot(root, cache))

    def test_native_stamp_ignores_page_edits_and_generated_stamp(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.project(root)
            first = debug.prepare(root)
            self.assertEqual(first, debug.prepare(root))
            (root / 'pages/index.vue').write_text('page two')
            (root / debug.PLUGIN / 'app-android/.DS_Store').write_text('editor metadata')
            (root / debug.PLUGIN / 'app-android/Bridge.kt.swp').write_text('temporary editor data')
            self.assertEqual(first, debug.fingerprint(root))

    def test_native_or_sdk_change_invalidates_old_base(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); uts = self.project(root)
            first = debug.prepare(root)
            apk = root / 'base.apk'
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('classes.dex', b'dex\0' + first.encode())
            self.assertEqual(first, debug.require_current_base(apk, root))
            (uts / 'app-android/libs/sdk.aar').write_bytes(b'new SDK')
            with self.assertRaisesRegex(RuntimeError, '原生代码'):
                debug.require_current_base(apk, root)
            second = debug.fingerprint(root)
            (uts / 'app-android/Bridge.kt').write_text('new bridge')
            self.assertNotEqual(second, debug.fingerprint(root))

    def test_unstamped_base_is_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.project(root)
            apk = root / 'base.apk'
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('classes.dex', b'old plugin')
            with self.assertRaises(RuntimeError):
                debug.require_current_base(apk, root)

    def test_new_shared_uts_helpers_participate_in_native_fingerprint(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); uts = self.project(root)
            first = debug.fingerprint(root)
            helper = uts / 'status.uts'
            helper.write_text('export const code = 0')
            second = debug.fingerprint(root)
            self.assertNotEqual(first, second)
            helper.write_text('export const code = 203')
            self.assertNotEqual(second, debug.fingerprint(root))

    def test_host_native_settings_change_requires_rebuild(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.project(root)
            first = debug.host_fingerprint(root)
            path = root / 'manifest.json'; manifest = json.loads(path.read_text())
            manifest['vueVersion'] = '2'
            manifest['app-plus']['distribute']['android']['certpassword'] = 'local secret'
            path.write_text(json.dumps(manifest, indent=4))
            self.assertEqual(first, debug.host_fingerprint(root))
            manifest['app-plus']['distribute']['android']['minSdkVersion'] = 26
            path.write_text(json.dumps(manifest))
            self.assertNotEqual(first, debug.host_fingerprint(root))

    def test_icon_content_changes_require_a_new_base_in_both_examples(self):
        for uvue in [False, True]:
            with self.subTest(uvue=uvue), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); self.project(root)
                path = root / 'manifest.json'; manifest = json.loads(path.read_text())
                icon = root / 'app-icons/android/hdpi.png'; icon.parent.mkdir(parents=True)
                icon.write_bytes(b'first icon')
                if uvue:
                    manifest['app-android'] = {'distribute': manifest.pop('app-plus')['distribute']['android']}
                    manifest['app-android']['distribute']['icons'] = {'hdpi': 'app-icons/android/hdpi.png'}
                    (root / 'App.uvue').write_text('')
                else:
                    manifest['app-plus']['distribute']['icons'] = {'android': {'hdpi': 'app-icons/android/hdpi.png'}}
                path.write_text(json.dumps(manifest))
                first = debug.host_fingerprint(root)
                icon.write_bytes(b'changed icon')
                self.assertNotEqual(first, debug.host_fingerprint(root))
                icon.unlink()
                with self.assertRaisesRegex(RuntimeError, '图标文件'):
                    debug.host_fingerprint(root)

    def test_single_online_device_is_selected_without_using_offline_phone(self):
        output = 'List of devices attached\nphone-a offline model:Samsung\nphone-b device model:Xiaomi_17\n'
        with patch.object(debug, 'run', return_value=output):
            self.assertEqual(debug.select_device('adb')['serial'], 'phone-b')
            with self.assertRaisesRegex(RuntimeError, 'offline'):
                debug.select_device('adb', 'phone-a')

    def test_multiple_online_devices_require_selection(self):
        with patch.object(debug, 'run', return_value='a device\nb device\n'):
            with self.assertRaisesRegex(RuntimeError, '多台'):
                debug.select_device('adb')
            self.assertEqual(debug.select_device('adb', 'b')['serial'], 'b')

    def test_sync_protocol_rejects_release_base_and_unknown_protocol(self):
        for value, message in [({'protocol': 1, 'code': 'NOT_DEBUGGABLE'}, '正式包'),
                               ({'protocol': 2, 'code': 'OK'}, '协议')]:
            with patch.object(debug, 'run', return_value='Broadcast completed: result=0, data="' + json.dumps(value) + '"'):
                with self.assertRaisesRegex(RuntimeError, message):
                    debug.broadcast(['adb'], 'dev.example.demo', 'INFO')

    def test_sync_protocol_reads_exact_json_receipt(self):
        value = {'protocol': 1, 'code': 'OK', 'fingerprint': 'hfv1:' + 'a' * 64}
        with patch.object(debug, 'run', return_value='Broadcast completed: result=-1, data="' + json.dumps(value) + '"'):
            self.assertEqual(debug.broadcast(['adb'], 'dev.example.demo', 'INFO'), value)

    def test_broadcast_works_when_api23_am_has_no_receiver_foreground_option(self):
        value = {'protocol': 1, 'code': 'OK', 'fingerprint': 'hfv1:' + 'a' * 64}
        def legacy_am(command, **kwargs):
            if '--receiver-foreground' in command:
                return 'Error: Unknown option: --receiver-foreground\nBroadcasting: null'
            self.assertIn('-f', command)
            self.assertEqual(command[command.index('-f') + 1], '0x10000000')
            return 'Broadcast completed: result=-1, data="' + json.dumps(value) + '"'
        with patch.object(debug, 'run', side_effect=legacy_am):
            self.assertEqual(debug.broadcast(['adb'], 'dev.example.demo', 'INFO'), value)

    def test_pidof_ignoring_package_falls_back_to_exact_process_name(self):
        result = type('Result', (), {'returncode': 0, 'stdout': '1 22 33 44\n'})()
        rows = 'USER PID NAME\nroot 1 init\nu0_a1 33 dev.example.demo\nu0_a1 44 dev.example.demo:jse\n'
        for unsupported in ['Error: Unknown option -A', 'USER PID NAME\n']:
            with patch.object(debug.subprocess, 'run', return_value=result), \
                 patch.object(debug, 'run', side_effect=[unsupported, rows]):
                self.assertEqual(debug.app_pids(['adb'], 'dev.example.demo'), ['33'])

    def test_pidof_single_result_remains_a_fast_path(self):
        result = type('Result', (), {'returncode': 0, 'stdout': '33\n'})()
        with patch.object(debug.subprocess, 'run', return_value=result), patch.object(debug, 'run') as ps:
            self.assertEqual(debug.app_pids(['adb'], 'dev.example.demo'), ['33'])
            ps.assert_not_called()

    def test_resource_archive_preserves_content_and_rejects_links_and_oversize(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / 'manifest.json').write_text('plain content')
            data = debug.resource_zip(root)
            import io
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                self.assertEqual(archive.read('manifest.json'), b'plain content')
            with patch.object(debug, 'MAX_BYTES', 2):
                with self.assertRaisesRegex(RuntimeError, '32 MB'):
                    debug.resource_zip(root)
            (root / 'link').symlink_to(root / 'manifest.json')
            with self.assertRaisesRegex(RuntimeError, '符号链接'):
                debug.resource_zip(root)

    def test_logs_are_scoped_to_target_pid_and_features_are_redacted(self):
        log = ('11-10 12:00:00.100 123 200 I HelloFaceVerify: op=abc event=END HF1:private\n'
               '11-10 12:00:00.200 456 200 I HelloFaceVerify: other process private data\n')
        import subprocess
        with patch.object(debug.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '123\n', '')), \
             patch.object(debug, 'run', return_value=log):
            result = debug.log_snapshot(['adb'], 'dev.example.demo')
        self.assertIn('op=abc', result)
        self.assertNotIn('private', result)
        self.assertNotIn('other process', result)

    def test_legacy_migration_does_not_move_business_directories(self):
        scripts = str(Path(__file__).resolve().parents[1] / 'scripts')
        sys.path.insert(0, scripts)
        try:
            import run_android
        finally:
            sys.path.pop(0)
        import subprocess
        calls = []
        def command(args, **kwargs):
            calls.append(args)
            if args[-2:] == ['id', '-u']:
                return '10123'
            if args[-1].endswith('/apps'):
                return '__UNI__TEST'
            return 'www business-documents'
        stat = subprocess.CompletedProcess([], 0, '2000\n', '')
        with patch.object(run_android, 'command', side_effect=command), \
             patch.object(run_android.subprocess, 'run', return_value=stat):
            with self.assertRaisesRegex(RuntimeError, '非页面数据'):
                run_android.migrate_legacy_resources(['adb'], 'dev.example.demo', '__UNI__TEST')
        self.assertFalse(any('mv' in args for args in calls))

    def test_missing_sha256sum_uses_apk_bytes_even_when_old_shell_reports_success(self):
        scripts = str(Path(__file__).resolve().parents[1] / 'scripts')
        sys.path.insert(0, scripts)
        try:
            import run_android
        finally:
            sys.path.pop(0)
        import subprocess
        import hashlib
        for data in [b'PK\x03\x04synthetic-apk', b'/system/bin/sh: cat: file not found']:
            responses = [subprocess.CompletedProcess([], 0, 'package:/data/app/demo/base.apk\n', ''),
                         subprocess.CompletedProcess([], 0, '/system/bin/sh: sha256sum: not found\n', ''),
                         subprocess.CompletedProcess([], 0, data, b'')]
            with patch.object(run_android.subprocess, 'run', side_effect=responses) as calls:
                self.assertEqual(run_android.installed_hash(['adb'], 'dev.example.demo'),
                                 hashlib.sha256(data).hexdigest() if data.startswith(b'PK\x03\x04') else None)
                self.assertIn('exec-out', calls.call_args_list[-1].args[0])

    def test_valid_device_hash_does_not_download_apk(self):
        scripts = str(Path(__file__).resolve().parents[1] / 'scripts')
        sys.path.insert(0, scripts)
        try:
            import run_android
        finally:
            sys.path.pop(0)
        import subprocess
        responses = [subprocess.CompletedProcess([], 0, 'package:/data/app/demo/base.apk\n', ''),
                     subprocess.CompletedProcess([], 0, 'AB' * 32 + '  /data/app/demo/base.apk\n', '')]
        with patch.object(run_android.subprocess, 'run', side_effect=responses) as calls:
            self.assertEqual(run_android.installed_hash(['adb'], 'dev.example.demo'), 'ab' * 32)
            self.assertEqual(calls.call_count, 2)

    def test_page_size_uses_smaps_on_old_shell_and_never_guesses(self):
        scripts = str(Path(__file__).resolve().parents[1] / 'scripts')
        sys.path.insert(0, scripts)
        try:
            import run_android
        finally:
            sys.path.pop(0)
        for responses, expected in [(['16384'], 16384),
                                    (['/system/bin/sh: getconf: not found', 'KernelPageSize:        4 kB\n'], 4096),
                                    (['not found', 'permission denied'], None),
                                    ([RuntimeError('no getconf'), RuntimeError('no smaps')], None)]:
            with patch.object(run_android, 'command', side_effect=responses):
                self.assertEqual(run_android.device_page_size(['adb']), expected)

    def test_legacy_migration_preserves_mixed_owner_backup_without_moving_active_pages(self):
        scripts = str(Path(__file__).resolve().parents[1] / 'scripts')
        sys.path.insert(0, scripts)
        try:
            import run_android
        finally:
            sys.path.pop(0)
        import subprocess
        calls = []
        def command(args, **kwargs):
            calls.append(args)
            if args[-2:] == ['id', '-u']:
                return '10123'
            if 'find' in args:
                return '10123\n2000\n'
            return ''
        stat = subprocess.CompletedProcess([], 0, '10123\n', '')
        with patch.object(run_android, 'command', side_effect=command), \
             patch.object(run_android.subprocess, 'run', return_value=stat):
            run_android.migrate_legacy_resources(['adb'], 'dev.example.demo', '__UNI__TEST')
        moves = [args for args in calls if 'mv' in args]
        self.assertEqual(len(moves), 1)
        self.assertTrue(moves[0][-2].endswith('/www.debug-backup'))
        self.assertIn('.shell-backup-', moves[0][-1])


if __name__ == '__main__':
    unittest.main()
