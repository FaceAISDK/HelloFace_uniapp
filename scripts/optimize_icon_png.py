#!/usr/bin/env python3
"""无损重编码应用图标；仅开发者更新图标时需要 Pillow，正常打包无需安装。"""
from io import BytesIO
from pathlib import Path
import struct
import zlib

try:
    from PIL import Image
except ImportError:
    raise SystemExit('请先安装图标维护工具：python3 -m pip install Pillow')

ROOT = Path(__file__).resolve().parents[1]
SIGNATURE = b'\x89PNG\r\n\x1a\n'


def chunks(data):
    """保留原始块，重编码只替换 IDAT，不丢弃色彩配置、EXIF 等元数据。"""
    if not data.startswith(SIGNATURE):
        raise ValueError('不是 PNG 文件')
    offset = len(SIGNATURE)
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        end = offset + length + 12
        block = data[offset:end]
        if len(block) != length + 12:
            raise ValueError('PNG 数据块不完整')
        yield block[4:8], block
        offset = end


def optimize(path):
    before = path.read_bytes()
    original = list(chunks(before))
    with Image.open(BytesIO(before)) as image:
        image.load()
        output = BytesIO()
        image.save(output, format='PNG', optimize=True, compress_level=9)
        encoded = list(chunks(output.getvalue()))
        # 色深、通道和隔行方式都必须一致，才能只替换像素压缩数据。
        if original[0] != encoded[0]:
            raise ValueError(f'{path}: 重编码改变了 PNG 格式')
        payload = b''.join(block[8:-4] for kind, block in encoded if kind == b'IDAT')
        idat = (struct.pack('>I', len(payload)) + b'IDAT' + payload
                + struct.pack('>I', zlib.crc32(b'IDAT' + payload)))
        result = bytearray(SIGNATURE)
        inserted = False
        for kind, block in original:
            if kind == b'IDAT':
                if not inserted:
                    result.extend(idat)
                    inserted = True
            else:
                result.extend(block)
        with Image.open(BytesIO(result)) as check:
            if (check.mode, check.size, check.tobytes()) != (image.mode, image.size, image.tobytes()):
                raise ValueError(f'{path}: 像素校验失败，未写入')
    if len(result) < len(before):
        path.write_bytes(result)
        print(f'{path.relative_to(ROOT)}: {len(before):,} → {len(result):,} bytes')
        return len(before) - len(result)
    return 0


if __name__ == '__main__':
    icons = ROOT / 'app-icons'
    paths = [icons / 'HiFaceUni.png']
    for platform in ('android', 'ios', 'harmony'):
        paths.extend(sorted((icons / platform).glob('*.png')))
    saved = sum(optimize(path) for path in paths)
    print(f'Checked {len(paths)} icons; saved {saved:,} bytes; pixels and metadata unchanged.')
