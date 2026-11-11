import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { HiFaceSdk, RgbaImage } from 'hiface';
import { BridgeError, unwrap } from './BridgeTypes';

export class FaceImageImporter {
  static async extract(context: common.UIAbilityContext, encoded: string): Promise<string> {
    const rgba = await FaceImageImporter.decode(encoded);
    const sdk = HiFaceSdk.create(context);
    try { return unwrap(await sdk.capture().extractFeature(rgba)); }
    finally { sdk.close(); }
  }

  private static async decode(encoded: string): Promise<RgbaImage> {
    let source: image.ImageSource | undefined = undefined;
    let pixels: image.PixelMap | undefined = undefined;
    try {
      if (encoded.length > 8388608) throw new Error('Image exceeds 6 MiB');
      const bytes = new util.Base64Helper().decodeSync(encoded);
      const png = bytes.length >= 8 && bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 &&
        bytes[3] === 71 && bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10;
      const jpeg = bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      if (!png && !jpeg) throw new Error('Only PNG/JPEG are supported');
      source = image.createImageSource(bytes.buffer as ArrayBuffer);
      const info = await source.getImageInfo(0);
      const w = info.size.width; const h = info.size.height;
      if (w < 2 || h < 2 || w > 4096 || h > 4096 || w * h > 4194304) {
        throw new Error('Image must be 2..4096 px per side and at most 4194304 pixels');
      }
      pixels = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888, editable: true });
      let orientation: string = '1';
      try { orientation = (await source.getImageProperty(image.PropertyKey.ORIENTATION)).trim().toLowerCase(); } catch (_) {}
      if (orientation === '2' || orientation === 'top-right') await pixels.flip(true, false);
      else if (orientation === '3' || orientation === 'bottom-right') await pixels.rotate(180);
      else if (orientation === '4' || orientation === 'bottom-left') await pixels.flip(false, true);
      else if (orientation === '5' || orientation === 'left-top') { await pixels.rotate(90); await pixels.flip(true, false); }
      else if (orientation === '6' || orientation === 'right-top') await pixels.rotate(90);
      else if (orientation === '7' || orientation === 'right-bottom') { await pixels.rotate(90); await pixels.flip(false, true); }
      else if (orientation === '8' || orientation === 'left-bottom') await pixels.rotate(270);
      let decoded = await pixels.getImageInfo();
      const width = Math.floor(decoded.size.width / 2) * 2;
      const height = Math.floor(decoded.size.height / 2) * 2;
      if (width !== decoded.size.width || height !== decoded.size.height) {
        await pixels.crop({ x: 0, y: 0, size: { width: width, height: height } });
        decoded = await pixels.getImageInfo();
      }
      const packed = new ArrayBuffer(width * height * 4);
      if (decoded.pixelFormat === image.PixelMapFormat.RGBA_8888 && decoded.stride === width * 4 &&
        pixels.getPixelBytesNumber() === packed.byteLength) {
        await pixels.readPixelsToBuffer(packed);
      } else {
        await pixels.readPixels({ pixels: packed, offset: 0, stride: width * 4,
          region: { x: 0, y: 0, size: { width: width, height: height } } });
        const rgba = new Uint8Array(packed);
        for (let i = 0; i < rgba.length; i += 4) {
          const blue = rgba[i]; rgba[i] = rgba[i + 2]; rgba[i + 2] = blue;
        }
      }
      return new RgbaImage(packed, width, height);
    } catch (error) {
      throw new BridgeError('INVALID_IMAGE', (error as Error).message);
    } finally {
      try { await pixels?.release(); } finally { await source?.release(); }
    }
  }
}
