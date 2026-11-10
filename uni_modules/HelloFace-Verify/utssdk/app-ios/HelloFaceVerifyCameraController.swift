import UIKit
import AVFoundation
import HiFace

final class HelloFaceVerifyCameraController: UIViewController {
    private let method: String
    private let params: [String: Any]
    private let reference: String?
    private let onProgress: ([String: Any]) -> Void
    private let completion: (String) -> Void
    private lazy var pipeline = HelloFaceVerifyCameraPipeline(front: isFront) { [weak self] code, message in
        self?.fail(code, message)
    }
    private var preview: AVCaptureVideoPreviewLayer?
    private var request: FaceRequest?
    private lazy var screen = HelloFaceVerifyCameraView(enrollment: method == "enrollFace")
    private var captured: FaceFlowResult?
    private var ended = false
    private var saving = false
    var committing: Bool { saving }
    private var generation = 0
    private var previousIdleTimer: Bool?
    private var backgroundObserver: NSObjectProtocol?
    private var isFront: Bool { (params["camera"] as? String ?? "front") == "front" }

    init(method: String, params: [String: Any], reference: String?,
         progress: @escaping ([String: Any]) -> Void, completion: @escaping (String) -> Void) {
        self.method = method; self.params = params; self.reference = reference
        self.onProgress = progress; self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use the designated initializer") }

    override func loadView() { view = screen }
    override func viewDidLoad() {
        super.viewDidLoad()
        screen.onCancel = { [weak self] in self?.cancel() }
        screen.onRetake = { [weak self] in self?.retake() }
        screen.onConfirm = { [weak self] in self?.confirm() }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in self?.cancel() }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, !self.ended else { return }
                    if granted { self.begin() } else { self.fail("PERMISSION_DENIED", "Camera permission denied") }
                }
            }
        default: fail("PERMISSION_DENIED", "Camera permission denied")
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !ended && previousIdleTimer == nil {
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        restoreIdleTimer()
        if !ended { cancel() }
    }

    private func begin() {
        guard !ended else { return }
        do {
            try startRequest()
            let layer = AVCaptureVideoPreviewLayer(session: pipeline.session)
            layer.videoGravity = .resizeAspectFill; layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0); preview = layer
            pipeline.start()
        } catch { fail("INVALID_ARGUMENT", error.localizedDescription) }
    }

    private func startRequest() throws {
        generation += 1
        let attempt = generation
        let callbacks = FaceFlowCallbacks(onProgress: { [weak self] progress in
            guard let self = self, self.generation == attempt else { return }; self.progress(progress)
        }, onResult: { [weak self] result in
            guard let self = self, self.generation == attempt else { return }; self.result(result)
        }, onError: { [weak self] error in
            guard let self = self, self.generation == attempt else { return }
            self.fail(Self.errorName(error.code), error.message)
        })
        if method == "enrollFace" {
            request = pipeline.sdk.startCameraCapture(callbacks: callbacks)
        } else {
            let actions = try (params["actions"] as? [String] ?? []).map { action -> FaceAction in
                switch action {
                case "blink": return .blink
                case "openMouth": return .openMouth
                case "shakeHead": return .shakeHead
                case "nodHead": return .nodHead
                default: throw HelloFaceVerifyBridgeError.failure("INVALID_ARGUMENT", "Unknown action")
                }
            }
            let configuration = try FaceVerificationConfiguration(referenceFeature: reference ?? "",
                threshold: (params["threshold"] as? NSNumber)?.floatValue ?? 0.80,
                requiresSilentLiveness: params["silentLiveness"] as? Bool ?? true, actions: actions,
                actionTimeoutMilliseconds: (params["actionTimeoutMs"] as? NSNumber)?.int64Value ?? 10000,
                faceAcquisitionTimeoutMilliseconds: (params["faceTimeoutMs"] as? NSNumber)?.int64Value ?? 15000)
            request = pipeline.sdk.startCameraVerification(configuration: configuration, callbacks: callbacks)
        }
    }

    private func progress(_ value: FaceFlowProgress) {
        guard !ended, captured == nil else { return }
        let action = value.action.map { Self.actionName($0) }
        let stage = Self.stageName(value.stage)
        screen.showProgress(stage: stage, action: action, step: Int(value.stepNumber), count: Int(value.stepCount),
                            guidance: Self.guidance(stage, action))
        onProgress(["stage": stage, "action": action as Any? ?? NSNull(),
                    "stepNumber": value.stepNumber, "stepCount": value.stepCount])
    }
    private func result(_ value: FaceFlowResult) {
        guard !ended else { return }
        if method == "enrollFace", value.passed, value.feature != nil {
            captured = value
            pipeline.pause()
            var photo: UIImage?
            if let image = value.alignedFace?.makeCGImage() {
                photo = UIImage(cgImage: image)
            }
            screen.showConfirmation(image: photo, mirrored: isFront)
        } else {
            var data = Self.data(value)
            if method == "verifyFace" { data.removeValue(forKey: "feature") }
            finish(HelloFaceVerifyOperation.envelope("result", "OK", "", data))
        }
    }
    private func retake() {
        guard !ended, !saving, captured != nil else { return }
        generation += 1
        request?.cancel(); request = nil; captured = nil
        screen.showLive()
        do { try startRequest(); pipeline.resume() }
        catch { fail("INVALID_ARGUMENT", error.localizedDescription) }
    }
    @objc private func confirm() {
        guard !ended, !saving, let value = captured, let feature = value.feature, let faceID = params["faceID"] as? String else { return }
        saving = true; screen.showSaving()
        do { try ReferenceStore.save(faceID, feature); finish(HelloFaceVerifyOperation.envelope("result", "OK", "", Self.data(value))) }
        catch { fail("STORAGE_ERROR", error.localizedDescription) }
    }
    @objc func cancel() { if !saving { fail("CANCELLED", "Face operation cancelled") } }
    private func fail(_ code: String, _ message: String) { finish(HelloFaceVerifyOperation.envelope("error", code, message)) }
    private func finish(_ response: String) {
        guard !ended else { return }; ended = true
        generation += 1; restoreIdleTimer(); screen.clearPhoto()
        captured = nil; request?.cancel(); request = nil
        if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
        pipeline.close { [self] in
            if presentingViewController != nil {
                dismiss(animated: true) { [completion] in completion(response) }
            } else { completion(response) }
        }
    }
    private func restoreIdleTimer() {
        if let previous = previousIdleTimer { UIApplication.shared.isIdleTimerDisabled = previous; previousIdleTimer = nil }
    }
    private static func data(_ value: FaceFlowResult) -> [String: Any] {
        ["passed": value.passed, "outcome": outcomeName(value.outcome),
         "feature": value.feature as Any? ?? NSNull(),
         "similarity": value.similarity as Any? ?? NSNull(),
         "livenessScore": value.livenessScore as Any? ?? NSNull()]
    }
    private static func outcomeName(_ outcome: FaceFlowOutcome) -> String {
        switch outcome {
        case .passed: return "PASSED"
        case .notMatched: return "NOT_MATCHED"
        case .spoofDetected: return "SPOOF_DETECTED"
        case .noFaceTimeout: return "NO_FACE_TIMEOUT"
        case .faceLost: return "FACE_LOST"
        case .multipleFaces: return "MULTIPLE_FACES"
        case .actionTimeout: return "ACTION_TIMEOUT"
        case .finalCaptureTimeout: return "FINAL_CAPTURE_TIMEOUT"
        @unknown default: return "UNKNOWN"
        }
    }
    private static func actionName(_ action: FaceAction) -> String {
        switch action {
        case .blink: return "blink"
        case .openMouth: return "openMouth"
        case .shakeHead: return "shakeHead"
        case .nodHead: return "nodHead"
        @unknown default: return "unknown"
        }
    }
    private static func stageName(_ stage: FaceFlowStage) -> String {
        switch stage {
        case .waitingForFace: return "WAITING_FOR_FACE"
        case .multipleFaces: return "MULTIPLE_FACES"
        case .faceTooSmall: return "FACE_TOO_SMALL"
        case .performAction: return "PERFORM_ACTION"
        case .faceNotFrontal: return "FACE_NOT_FRONTAL"
        case .holdStill: return "HOLD_STILL"
        case .faceForward: return "FACE_FORWARD"
        case .faceUnstable: return "FACE_UNSTABLE"
        @unknown default: return "UNKNOWN"
        }
    }
    private static func guidance(_ stage: String, _ action: String?) -> String {
        if stage == "PERFORM_ACTION" {
            return ["blink": "请眨眨眼", "openMouth": "请张张嘴", "shakeHead": "请摇摇头", "nodHead": "请点点头"][action ?? ""] ?? "请按提示完成动作"
        }
        return ["WAITING_FOR_FACE": "请正对镜头", "MULTIPLE_FACES": "请保持画面中只有一人",
            "FACE_TOO_SMALL": "请靠近一些", "HOLD_STILL": "请保持不动", "FACE_FORWARD": "请正对镜头",
            "FACE_NOT_FRONTAL": "请正对镜头", "FACE_UNSTABLE": "请保持稳定"][stage] ?? "正在处理"
    }
    private static func errorName(_ code: HiFaceErrorCode) -> String {
        // Preserve every documented SDK code; convert Swift camelCase to the shared uppercase form.
        let name = String(describing: code)
        return name.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).uppercased()
    }
}
