import AVFoundation
import HiFace

/** 相机配置与借用帧处理使用同一串行队列，关闭时等待在途帧处理结束。 */
final class HelloFaceVerifyCameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let sdk = HiFaceSDK()
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "HelloFaceVerify.camera")
    private let front: Bool
    private let onError: @MainActor @Sendable (String, String) -> Void
    // 下面的状态、观察者和输出只在 queue 上读写；close 后不再接收帧或重启会话。
    private var closed = false
    private var configured = false
    private var accepting = false
    private var failed = false
    private var output: AVCaptureVideoDataOutput?
    private var observers: [NSObjectProtocol] = []

    init(front: Bool, onError: @escaping @MainActor @Sendable (String, String) -> Void) {
        self.front = front; self.onError = onError
        super.init()
    }
    func start(_ ready: @escaping @MainActor @Sendable () -> Void) {
        queue.async { [self] in
            guard !closed, !failed, !configured else { return }
            observeSession()
            configure(ready)
        }
    }
    func pause(_ completion: (@MainActor @Sendable () -> Void)? = nil) {
        queue.async { [self] in
            if !closed { accepting = false; session.stopRunning() }
            // 与送帧共用串行队列：当前帧结束、会话停止后才允许重拍启动新请求。
            if let completion = completion { DispatchQueue.main.async { completion() } }
        }
    }
    func resume() {
        queue.async { [self] in
            guard !closed, !failed, configured else { return }
            session.startRunning(); accepting = session.isRunning
        }
    }
    func close(_ completion: @escaping @MainActor @Sendable () -> Void) {
        queue.async { [self] in
            if !closed {
                closed = true; accepting = false
                observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
                session.stopRunning()
                output?.setSampleBufferDelegate(nil, queue: nil)
                session.beginConfiguration()
                session.outputs.forEach { session.removeOutput($0) }
                session.inputs.forEach { session.removeInput($0) }
                session.commitConfiguration()
                output = nil; sdk.close()
            }
            DispatchQueue.main.async { completion() }
        }
    }

    private func observeSession() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { [weak self] note in
                let message = (note.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription ?? "Camera session failed"
                self?.reportSessionError("CAMERA_ERROR", message)
            },
            center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) { [weak self] note in
                let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
                let background = reason == AVCaptureSession.InterruptionReason.videoDeviceNotAvailableInBackground.rawValue
                self?.reportSessionError(background ? "CANCELLED" : "CAMERA_ERROR", "Camera session interrupted")
            }
        ]
    }
    private func reportSessionError(_ code: String, _ message: String) {
        queue.async { [weak self] in
            guard let self = self, !self.closed else { return }
            self.accepting = false
            self.emitError(code, message)
        }
    }
    private func configure(_ onReady: @escaping @MainActor @Sendable () -> Void) {
        do {
            session.beginConfiguration()
            var ready = false
            defer {
                session.commitConfiguration()
                // 在当前配置任务内启动，避免排队到已请求的关闭操作之后。
                if ready {
                    configured = true
                    session.startRunning(); accepting = session.isRunning
                    if accepting { DispatchQueue.main.async { onReady() } }
                    else { emitError("CAMERA_ERROR", "Camera session did not start") }
                }
            }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else {
                throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Requested camera is unavailable")
            }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Unable to add camera input") }
            session.addInput(input)
            guard let preset = [AVCaptureSession.Preset.vga640x480, .medium].first(where: { session.canSetSessionPreset($0) }) else {
                throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "No supported camera resolution")
            }
            session.sessionPreset = preset
            let output = AVCaptureVideoDataOutput()
            self.output = output
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Unable to add camera output") }
            session.addOutput(output)
            guard let connection = output.connection(with: .video),
                  HelloFaceVerifyCameraOrientation.configure(connection, mirrored: false) else {
                throw HelloFaceVerifyBridgeError.failure("CAMERA_ERROR", "Portrait camera frames are unavailable")
            }
            ready = true
        } catch { emitError("CAMERA_ERROR", error.localizedDescription) }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard accepting, !closed, !failed else { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard HelloFaceVerifyCameraFrameSize.isSupported(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
            maximumLongSide: HiFaceCameraFrame.maximumLongSidePixels, maximumShortSide: HiFaceCameraFrame.maximumShortSidePixels) else {
            emitError("CAMERA_ERROR", "Camera frame dimensions are unsupported")
            return
        }
        do {
            let frame = try HiFaceCameraFrame(pixelBuffer: buffer, rotation: .degrees0, isMirrored: front)
            if case .failure(let error) = sdk.processFrame(frame), error.code != .notReady && error.code != .busy {
                emitError(HelloFaceVerifySDKError.code(error.code), error.message)
            }
        } catch { emitError("CAMERA_ERROR", error.localizedDescription) }
    }
    private func emitError(_ code: String, _ message: String) {
        // 所有调用均在相机队列：首个错误立即停帧，避免主线程收尾前重复报错或恢复送帧。
        guard !closed, !failed else { return }
        accepting = false; failed = true
        DispatchQueue.main.async { [onError] in onError(code, message) }
    }
}

/// 预览与识别帧都使用竖屏方向；只对预览做前置镜像，SDK 接收原始帧及镜像标记。
enum HelloFaceVerifyCameraOrientation {
    static func configure(_ connection: AVCaptureConnection, mirrored: Bool) -> Bool {
        if #available(iOS 17.0, *) {
            guard connection.isVideoRotationAngleSupported(90) else { return false }
            connection.videoRotationAngle = 90
        } else {
            guard connection.isVideoOrientationSupported else { return false }
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        return true
    }
}
