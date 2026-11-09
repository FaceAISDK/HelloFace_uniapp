import AVFoundation
import HiFace

/** Camera configuration and borrowed pixel buffers stay on one serial queue. */
final class HelloFaceVerifyCameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let sdk = HiFaceSDK()
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "HelloFaceVerify.camera")
    private let front: Bool
    private let onError: @MainActor @Sendable (String, String) -> Void

    init(front: Bool, onError: @escaping @MainActor @Sendable (String, String) -> Void) {
        self.front = front; self.onError = onError
        super.init()
    }
    func start() { queue.async { [self] in configure() } }
    func pause() { queue.async { [self] in session.stopRunning() } }
    func close(_ completion: @escaping @MainActor @Sendable () -> Void) {
        queue.async { [self] in
            session.stopRunning(); sdk.close()
            DispatchQueue.main.async { completion() }
        }
    }

    private func configure() {
        do {
            session.beginConfiguration()
            var ready = false
            defer {
                session.commitConfiguration()
                // Never enqueue startup behind a teardown that was requested during configuration.
                if ready { session.startRunning() }
            }
            session.sessionPreset = .vga640x480
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else {
                throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Requested camera is unavailable")
            }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Unable to add camera input") }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Unable to add camera output") }
            session.addOutput(output)
            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                } else if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
                }
            }
            ready = true
        } catch { emitError("CAMERA_ERROR", error.localizedDescription) }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        do {
            let frame = try HiFaceCameraFrame(pixelBuffer: buffer, rotation: .degrees0, isMirrored: front)
            if case .failure(let error) = sdk.processFrame(frame), error.code != .notReady && error.code != .busy {
                let code = String(describing: error.code)
                    .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).uppercased()
                emitError(code, error.message)
            }
        } catch { emitError("CAMERA_ERROR", error.localizedDescription) }
    }
    private func emitError(_ code: String, _ message: String) {
        DispatchQueue.main.async { [onError] in onError(code, message) }
    }
}
