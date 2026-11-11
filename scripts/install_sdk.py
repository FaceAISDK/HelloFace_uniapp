#!/usr/bin/env python3
"""Install exactly the public SDK files recorded in sdk-artifacts.json."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import subprocess
import re

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / 'uni_modules' / 'HelloFace-Verify' / 'utssdk'


def matches(path, artifact):
    if not path.is_file() or path.stat().st_size != artifact['size']:
        return False
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest() == artifact['sha256']


def install(artifact, lock, source=None, check=False):
    destination = PLUGIN / artifact['destination']
    if matches(destination, artifact):
        return 'OK ' + artifact['destination']
    if check:
        raise RuntimeError('Missing or mismatched SDK: ' + artifact['destination'])
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=destination.parent, suffix='.part')
    os.close(descriptor)
    staging = Path(temporary)
    try:
        local = source / artifact['source'] if source else None
        if local and matches(local, artifact):
            shutil.copyfile(local, staging)
        else:
            host = 'media.githubusercontent.com/media' if artifact['lfs'] else 'raw.githubusercontent.com'
            url = f"https://{host}/{lock['repository']}/{lock['commit']}/{artifact['source']}"
            for attempt in range(3):
                try:
                    # System curl uses the OS trust store, including on macOS Python installations.
                    subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                                    '--connect-timeout', '20', '--max-time', '180',
                                    '--output', str(staging), url], check=True)
                    if not matches(staging, artifact):
                        raise RuntimeError('SHA-256/size mismatch: ' + artifact['source'])
                    break
                except Exception:
                    if attempt == 2:
                        raise
                    time.sleep(attempt + 1)
        if not matches(staging, artifact):
            raise RuntimeError('SHA-256/size mismatch: ' + artifact['source'])
        staging.chmod(0o644)
        staging.replace(destination)
        return 'Installed ' + artifact['destination']
    finally:
        staging.unlink(missing_ok=True)


def retire_obsolete(artifacts, root=ROOT, check=False):
    """Keep obsolete versioned SDK libraries out of the compiler; retain a rollback copy."""
    plugin = Path(root) / 'uni_modules/HelloFace-Verify/utssdk'
    expected = {plugin / a['destination'] for a in artifacts}
    directories = {p.parent for p in expected if p.suffix in ('.aar', '.har')}
    retired = []
    for directory in directories:
        for path in directory.glob('hiface-*'):
            if path in expected or not path.is_file() or not re.fullmatch(r'hiface-\d+\.\d+\.\d+(?:[.-][A-Za-z0-9]+)*\.(aar|har)', path.name):
                continue
            if check:
                raise RuntimeError('Obsolete SDK library still included: ' + path.name + '. Run sdk:install to retire it.')
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            backup = Path(root) / '.sdk-cache/retired-sdk' / (digest + '-' + path.name)
            backup.parent.mkdir(parents=True, exist_ok=True)
            if backup.exists():
                if hashlib.sha256(backup.read_bytes()).hexdigest() != digest:
                    raise RuntimeError('Retired SDK backup mismatch: ' + backup.name)
                path.unlink()
            else:
                shutil.move(str(path), str(backup))
            retired.append(path.name)
    return retired


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['all', 'android', 'ios', 'harmony'], default='all')
    parser.add_argument('--source', type=Path, help='Optional local upstream checkout (LFS pointers are downloaded)')
    parser.add_argument('--check', action='store_true', help='Verify only, without changing files or downloading')
    args = parser.parse_args()
    lock = json.loads((ROOT / 'sdk-artifacts.json').read_text())
    selected = [a for a in lock['artifacts'] if args.platform in ('all', a['platform'])]
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(install, a, lock, args.source, args.check) for a in selected]
        for future in concurrent.futures.as_completed(futures):
            try:
                print(future.result(), flush=True)
            except Exception as error:
                failures.append(str(error))
                print('ERROR: ' + str(error), flush=True)
    if failures:
        raise SystemExit(1)
    for name in retire_obsolete(selected, check=args.check):
        print('Retired obsolete ' + name + ' to .sdk-cache/retired-sdk (backup retained).')
    print(f"Verified {len(selected)} files, HelloFace {lock['version']} ({lock['commit'][:12]}).")


if __name__ == '__main__':
    main()
