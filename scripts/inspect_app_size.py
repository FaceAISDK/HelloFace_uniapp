#!/usr/bin/env python3
"""只读分析 APK/HAP/IPA 的下载体积、主要组成和调试残留，不修改或重新签名安装包。"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import zipfile


def inspect(path):
    with zipfile.ZipFile(path) as archive:
        files = [item for item in archive.infolist() if not item.is_dir()]
        groups = defaultdict(lambda: {'compressedBytes': 0, 'uncompressedBytes': 0})
        debug_files = []
        abis = set()
        for item in files:
            name = item.filename
            if name.endswith('.bphfm'):
                group = 'models'
            elif name.startswith(('lib/', 'libs/')):
                group = '/'.join(name.split('/')[:2])
                abis.add(name.split('/')[1])
            elif '.framework/' in name:
                group = name.split('.framework/')[0].split('/')[-1] + '.framework'
            elif name.endswith(('.dex', '.abc')):
                group = 'compiled-code'
            else:
                group = name.split('/')[0]
            groups[group]['compressedBytes'] += item.compress_size
            groups[group]['uncompressedBytes'] += item.file_size
            if name.endswith(('.map', '.dSYM', '.pdb')) or '.dSYM/' in name:
                debug_files.append({'path': name, 'bytes': item.compress_size})
        return {
            'path': str(path.resolve()), 'bytes': path.stat().st_size,
            'files': len(files), 'abis': sorted(abis),
            'groups': dict(sorted(groups.items(), key=lambda pair: -pair[1]['compressedBytes'])),
            'debugFiles': debug_files,
            'largestFiles': [{'path': item.filename, 'compressedBytes': item.compress_size,
                              'uncompressedBytes': item.file_size}
                             for item in sorted(files, key=lambda item: -item.compress_size)[:12]],
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', nargs='+', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.report and args.report.resolve() in {path.resolve() for path in args.packages}:
        parser.error('报告路径不能与安装包相同')
    reports = [inspect(path) for path in args.packages]
    for report in reports:
        print(f"{report['path']}: {report['bytes'] / 1_000_000:.2f} MB, {report['files']} files")
        for name, size in list(report['groups'].items())[:6]:
            print(f"  {name}: {size['compressedBytes'] / 1_000_000:.2f} MB")
        if report['debugFiles']:
            print(f"  Debug maps/symbols: {sum(item['bytes'] for item in report['debugFiles']) / 1_000_000:.2f} MB")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
