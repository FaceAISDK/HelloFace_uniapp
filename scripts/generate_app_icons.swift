// Platform resource conversion only; the artwork and text are in HiFaceUni.png.
import Foundation
import CoreGraphics
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent("app-icons")
let input = directory.appendingPathComponent("HiFaceUni.png")
guard let decoder = CGImageSourceCreateWithURL(input as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(decoder, 0, nil), artwork.width == 1024, artwork.height == 1024,
      [.none, .noneSkipFirst, .noneSkipLast].contains(artwork.alphaInfo) else {
    fatalError("Expected an opaque 1024x1024 PNG master without alpha: \(input.path)")
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
var pixel = [UInt8](repeating: 0, count: 4)
let background: CGColor = pixel.withUnsafeMutableBytes { bytes in
    let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    context.draw(artwork.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1))!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return CGColor(colorSpace: space, components: [CGFloat(bytes[0]) / 255, CGFloat(bytes[1]) / 255, CGFloat(bytes[2]) / 255, 1])!
}
func write(_ relative: String, size: Int, scale: CGFloat = 1, transparent: Bool = false, solid: Bool = false) throws {
    let destination = directory.appendingPathComponent(relative)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let alpha = transparent ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: space, bitmapInfo: alpha.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { fatalError("Cannot create icon bitmap") }
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    if transparent { context.clear(bounds) }
    else { context.setFillColor(background); context.fill(bounds) }
    if !solid {
        let edge = CGFloat(size) * scale
        context.interpolationQuality = .high
        context.draw(artwork, in: CGRect(x: (CGFloat(size) - edge) / 2, y: (CGFloat(size) - edge) / 2, width: edge, height: edge))
    }
    let image = context.makeImage()!
    guard let writer = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Cannot write \(destination.path)")
    }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { fatalError("PNG encoding failed") }
    print("Wrote \(relative) (\(size)x\(size))")
}
for (density, size) in [("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try write("android/\(density).png", size: size, scale: 0.9)
}
for size in [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180] {
    try write("ios/\(size).png", size: size)
}
// Leave a small safe inset for launcher masks and layered-icon motion.
try write("harmony/foreground.png", size: 1024, scale: 0.9, transparent: true)
try write("harmony/background.png", size: 1024, solid: true)
