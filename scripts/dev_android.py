#!/usr/bin/env python3
"""Watch the Vue example and reuse its checked native base on one pinned device."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

from android_debug import ROOT, PLUGIN, adb_path, devices, select_device


def snapshot(project, cache):
    roots = [project / name for name in ['App.vue', 'main.js', 'manifest.json', 'pages.json', 'pages', 'static', 'app-icons/android']]
    roots += [ROOT / PLUGIN / name for name in ['app-android', 'interface.uts', 'shared.uts', 'unierror.uts']]
    roots += [project / 'unpackage/debug/android_debug.apk']
    files = set()
    for path in roots:
        if path.is_dir():
            files.update(p for p in path.rglob('*') if p.is_file())
        elif path.is_file():
            files.add(path)
    result = {}
    for path in files:
        if not path.exists() or path.name.startswith('.') or path.name.endswith(('.tmp', '.swp', '~')):
            continue
        key = str(path)
        try:
            stat = path.stat()
            version = (stat.st_mtime_ns, stat.st_size)
            if key not in cache or cache[key][0] != version:
                data = path.read_bytes()
                if path.name == 'manifest.json':
                    try:
                        data = json.dumps(json.loads(data), sort_keys=True).encode()
                    except ValueError:
                        pass
                cache[key] = (version, hashlib.sha256(data).hexdigest())
        except FileNotFoundError:
            continue  # Editors often replace a saved file using rename.
        result[key] = cache[key][1]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--device')
    args = parser.parse_args()
    project = args.project.resolve()
    if (project / 'App.uvue').exists():
        raise RuntimeError('uvue 请使用 android:run -- --project examples/uni-app-x，交给 HBuilderX 原生监听。')
    adb = adb_path()
    device = select_device(adb, args.device)
    serial = device['serial']
    print(f'固定调试设备：{device["model"]} ({serial})；Ctrl+C 结束。', flush=True)
    previous = None
    cache = {}
    was_online = False
    while True:
        online = any(d['serial'] == serial and d['state'] == 'device' for d in devices(adb))
        current = snapshot(project, cache)
        if online and (current != previous or not was_online):
            # Require a stable snapshot so multi-file saves do not trigger competing builds.
            while True:
                time.sleep(.5)
                stable = snapshot(project, cache)
                if stable == current:
                    break
                current = stable
            subprocess.run([sys.executable, ROOT / 'scripts/run_android.py', '--project', project, '--device', serial])
            previous = current  # Changes during compilation are handled by the next iteration.
            print('等待修改；原生代码变更后请另行执行 android:base。', flush=True)
        elif not online and was_online:
            print('设备离线，等待同一设备重新连接。', flush=True)
        was_online = online
        time.sleep(1)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        raise SystemExit(0)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit('Android 监听停止：' + str(error))
