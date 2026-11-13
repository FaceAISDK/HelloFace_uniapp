import Foundation
import ImageIO
import HiFace

enum FaceImageImporter {
    // 非隔离 async 入口在 UI actor 之外解码与提取；这里只返回特征，不写入基准。
    static func extract(_ encoded: String) async throws -> String {
        let image = try decode(encoded)
        let sdk = HiFaceSDK()
        defer { sdk.close() }
        switch await sdk.extractFeature(from: image) {
        case .success(let feature): return feature
        case .failure(let error):
            throw HelloFaceVerifyBridgeError.failure(HelloFaceVerifySDKError.code(error.code), error.message)
        }
    }

    private static func decode(_ encoded: String) throws -> CGImage {
        func invalid(_ message: String) -> HelloFaceVerifyBridgeError { .failure("INVALID_IMAGE", message) }
        guard encoded.utf8.count <= 8388608, let data = Data(base64Encoded: encoded), data.count <= 6291456 else {
            throw invalid("Invalid Base64 or image exceeds 6 MiB")
        }
        let bytes = [UInt8](data.prefix(8))
        let png = bytes == [137, 80, 78, 71, 13, 10, 26, 10]
        let jpeg = bytes.count >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255
        guard png || jpeg, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (2...4096).contains(width), (2...4096).contains(height), width * height <= 4194304 else {
            throw invalid("PNG/JPEG must be 2..4096 px per side and at most 4194304 pixels")
        }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(width, height)]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw invalid("Unable to decode image")
        }
        return image
    }
}
