#!/usr/bin/env python3
"""Check 64-bit ELF LOAD/RELRO and APK ZIP alignment without modifying binaries."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PAGE = 16384
ABIS = {'arm64-v8a', 'x86_64'}


def elf_issues(data):
    """Apply Android's 16 KB LOAD and shared-writable-page RELRO rules."""
    if data[:5] != b'\x7fELF\x02' or len(data) < 64 or data[5] not in (1, 2):
        raise ValueError('Expected a 64-bit ELF library')
    endian = '<' if data[5] == 1 else '>'
    offset = struct.unpack_from(endian + 'Q', data, 32)[0]
    size, count = struct.unpack_from(endian + 'HH', data, 54)
    if size < 56 or not count or offset + size * count > len(data):
        raise ValueError('Invalid ELF program header table')
    loads, relros = [], []
    for index in range(count):
        kind, flags, file_offset, address, _, file_size, memory_size, alignment = struct.unpack_from(
            endian + 'IIQQQQQQ', data, offset + size * index)
        if kind == 1:
            loads.append((file_offset, address, file_size, memory_size, alignment, flags))
        elif kind == 0x6474e552:
            relros.append((address, memory_size))
    issues = []
    if not loads:
        issues.append('ELF has no LOAD segments')
    for file_offset, address, _, _, alignment, _ in loads:
        if alignment < PAGE or alignment & (alignment - 1):
            issues.append(f'LOAD alignment {alignment} must be a power of two >= {PAGE}')
        if (address - file_offset) % PAGE:
            issues.append('LOAD virtual address and file offset are not congruent modulo 16384')
    for address, memory_size in relros:
        end = address + memory_size
        if end % PAGE and any(start <= address < start + length and end < start + length and flags & 2
                              for _, start, _, length, _, flags in loads):
            issues.append('RELRO ends within a 16 KB page shared with writable LOAD data')
    return issues


def inspect_archive(path):
    path = Path(path)
    if path.suffix.lower() not in ('.apk', '.aar'):
        raise ValueError('Provide an APK or AAR')
    libraries, failures = [], []
    with zipfile.ZipFile(path) as archive, path.open('rb') as raw:
        for entry in archive.infolist():
            parts = entry.filename.split('/')
            if len(parts) != 3 or parts[0] not in ('lib', 'jni') or parts[1] not in ABIS or not parts[2].endswith('.so'):
                continue
            issues = elf_issues(archive.read(entry))
            zip_status = 'not applicable to AAR'
            if path.suffix.lower() == '.apk':
                zip_status = 'compressed; extracted by Android'
                if entry.compress_type == zipfile.ZIP_STORED:
                    raw.seek(entry.header_offset)
                    header = raw.read(30)
                    if len(header) != 30 or header[:4] != b'PK\x03\x04':
                        raise ValueError('Invalid ZIP local header')
                    name_length, extra_length = struct.unpack_from('<HH', header, 26)
                    data_offset = entry.header_offset + 30 + name_length + extra_length
                    zip_status = f'uncompressed; offset {data_offset}'
                    if data_offset % PAGE:
                        issues.append(f'Uncompressed ZIP data offset {data_offset} is not 16 KB aligned')
            libraries.append({'name': entry.filename, 'zip': zip_status, 'issues': issues})
            if issues:
                failures.append(entry.filename)
    if not libraries:
        raise ValueError('No arm64-v8a or x86_64 libraries found; cannot verify 16 KB alignment')
    return {'archive': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'pageSize': PAGE, 'libraries': libraries, 'passed': not failures}


def require_alignment(path):
    report = inspect_archive(path)
    if not report['passed']:
        details = '; '.join(f"{item['name']}: {', '.join(item['issues'])}"
                            for item in report['libraries'] if item['issues'])
        raise ValueError('16 KB alignment failed: ' + details)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives', nargs='*', type=Path, help='SDK AAR and/or final APK')
    parser.add_argument('--report', type=Path, help='Write a JSON report, including artifact hashes')
    args = parser.parse_args()
    archives = args.archives
    if not archives:
        sdk = json.loads((ROOT / 'sdk-artifacts.json').read_text())
        archives = [ROOT / 'uni_modules/HelloFace-Verify/utssdk' / item['destination']
                    for item in sdk['artifacts'] if item['platform'] == 'android' and item['destination'].endswith('.aar')]
        if not archives:
            raise ValueError('The SDK lock does not contain an Android AAR')
        archives.append(ROOT / 'unpackage/debug/android_debug.apk')
    reports = []
    for path in archives:
        report = inspect_archive(path)
        reports.append(report)
        print(f"{'PASS' if report['passed'] else 'FAIL'} {path.name}: {len(report['libraries'])} 64-bit libraries")
        for item in report['libraries']:
            for issue in item['issues']:
                print(f"  {item['name']}: {issue}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + '\n')
    return 0 if all(report['passed'] for report in reports) else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, struct.error, zipfile.BadZipFile) as error:
        print(f'Android alignment check stopped: {error}', file=sys.stderr)
        raise SystemExit(1)
