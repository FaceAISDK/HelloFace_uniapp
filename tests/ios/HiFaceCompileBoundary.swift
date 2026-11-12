// Compile-only boundary for checking real UIKit/AVFoundation integration with an older Xcode.
// Signatures follow the locked SDK 0.8.11 interface. Every callable member traps: never link this into an App.
import Foundation
import CoreGraphics
import CoreVideo

public enum HiFaceErrorCode: Sendable { case notReady, busy }
public struct HiFaceError: Error, Sendable {
    public var code: HiFaceErrorCode { fatalError("Compile only") }
    public var message: String { fatalError("Compile only") }
}
public enum FaceAction: Sendable { case shakeHead, nodHead, blink, openMouth }
public enum FaceFlowStage: Sendable {
    case waitingForFace, multipleFaces, faceTooSmall, performAction, faceNotFrontal, holdStill, faceForward, faceUnstable
}
public enum FaceFlowOutcome: Sendable {
    case passed, notMatched, spoofDetected, noFaceTimeout, faceLost, multipleFaces, actionTimeout, finalCaptureTimeout
}
public struct FaceFlowProgress: Sendable {
    public var stage: FaceFlowStage { fatalError("Compile only") }
    public var action: FaceAction? { fatalError("Compile only") }
    public var stepNumber: Int { fatalError("Compile only") }
    public var stepCount: Int { fatalError("Compile only") }
}
public struct HiFaceAlignedImage: Sendable {
    public func makeCGImage() -> CGImage? { fatalError("Compile only") }
}
public struct FaceFlowResult: Sendable {
    public var outcome: FaceFlowOutcome { fatalError("Compile only") }
    public var alignedFace: HiFaceAlignedImage? { fatalError("Compile only") }
    public var feature: String? { fatalError("Compile only") }
    public var livenessScore: Float? { fatalError("Compile only") }
    public var similarity: Float? { fatalError("Compile only") }
    public var passed: Bool { fatalError("Compile only") }
}
public struct FaceFlowCallbacks: Sendable {
    public init(onProgress: @escaping @MainActor @Sendable (FaceFlowProgress) -> Void,
                onResult: @escaping @MainActor @Sendable (FaceFlowResult) -> Void,
                onError: @escaping @MainActor @Sendable (HiFaceError) -> Void) { fatalError("Compile only") }
}
public final class FaceRequest: @unchecked Sendable {
    public func cancel() { fatalError("Compile only") }
}
public enum HiFaceImageRotation: Sendable { case degrees0 }
public struct HiFaceCameraFrame: Sendable {
    public init(pixelBuffer: CVPixelBuffer, rotation: HiFaceImageRotation, isMirrored: Bool) throws { fatalError("Compile only") }
}
public struct FaceLivenessConfiguration: Sendable {
    public init(actions: [FaceAction] = [], actionTimeoutMilliseconds: Int64? = nil,
                faceAcquisitionTimeoutMilliseconds: Int64? = nil, allowsMultipleFaces: Bool = false) throws { fatalError("Compile only") }
}
public struct FaceVerificationConfiguration: Sendable {
    public init(referenceFeature: String, threshold: Float? = nil, requiresSilentLiveness: Bool = false,
                actions: [FaceAction] = [], actionTimeoutMilliseconds: Int64? = nil,
                faceAcquisitionTimeoutMilliseconds: Int64? = nil, allowsMultipleFaces: Bool = false) throws { fatalError("Compile only") }
}
public final class HiFaceSDK: @unchecked Sendable {
    public init() { fatalError("Compile only") }
    public func close() { fatalError("Compile only") }
    public func processFrame(_ frame: HiFaceCameraFrame) -> Result<Void, HiFaceError> { fatalError("Compile only") }
    public func extractFeature(from image: CGImage) async -> Result<String, HiFaceError> { fatalError("Compile only") }
    public func startCameraCapture(callbacks: FaceFlowCallbacks) -> FaceRequest { fatalError("Compile only") }
    public func startCameraLiveness(configuration: FaceLivenessConfiguration, callbacks: FaceFlowCallbacks) -> FaceRequest { fatalError("Compile only") }
    public func startCameraVerification(configuration: FaceVerificationConfiguration, callbacks: FaceFlowCallbacks) -> FaceRequest { fatalError("Compile only") }
}
