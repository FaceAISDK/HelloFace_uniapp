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
    private let status = UILabel()
    private let confirmButton = UIButton(type: .system)
    private var captured: FaceFlowResult?
    private var ended = false
    private var backgroundObserver: NSObjectProtocol?
    private var isFront: Bool { (params["camera"] as? String ?? "front") == "front" }

    init(method: String, params: [String: Any], reference: String?,
         progress: @escaping ([String: Any]) -> Void, completion: @escaping (String) -> Void) {
        self.method = method; self.params = params; self.reference = reference
        self.onProgress = progress; self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use the designated initializer") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        status.text = "请正对镜头，保持人脸在画面中央"
        status.textColor = .white; status.textAlignment = .center; status.numberOfLines = 3
        status.translatesAutoresizingMaskIntoConstraints = false
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setTitle("确认录入", for: .normal)
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        confirmButton.isHidden = true; confirmButton.translatesAutoresizingMaskIntoConstraints = false
        [status, cancelButton, confirmButton].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            confirmButton.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor)
        ])
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !ended { cancel() }
    }

    private func begin() {
        guard !ended else { return }
        do {
            let callbacks = FaceFlowCallbacks(onProgress: { [weak self] progress in self?.progress(progress) },
                onResult: { [weak self] result in self?.result(result) },
                onError: { [weak self] error in self?.fail(Self.errorName(error.code), error.message) })
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
            let layer = AVCaptureVideoPreviewLayer(session: pipeline.session)
            layer.videoGravity = .resizeAspectFill; layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0); preview = layer
            pipeline.start()
        } catch { fail("INVALID_ARGUMENT", error.localizedDescription) }
    }

    private func progress(_ value: FaceFlowProgress) {
        guard !ended else { return }
        let action = value.action.map { Self.actionName($0) }
        let stage = Self.stageName(value.stage)
        status.text = Self.guidance(stage, action)
        onProgress(["stage": stage, "action": action as Any? ?? NSNull(),
                    "stepNumber": value.stepNumber, "stepCount": value.stepCount])
    }
    private func result(_ value: FaceFlowResult) {
        guard !ended else { return }
        if method == "enrollFace", value.passed, value.feature != nil {
            captured = value
            pipeline.pause()
            status.text = "采集完成，请确认录入"
            if let image = value.alignedFace?.makeCGImage() {
                let imageView = UIImageView(image: UIImage(cgImage: image))
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(imageView)
                NSLayoutConstraint.activate([imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
                    imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.55)])
            }
            confirmButton.isHidden = false
        } else {
            var data = Self.data(value)
            if method == "verifyFace" { data.removeValue(forKey: "feature") }
            finish(HelloFaceVerifyOperation.envelope("result", "OK", "", data))
        }
    }
    @objc private func confirm() {
        guard !ended, let value = captured, let feature = value.feature, let faceID = params["faceID"] as? String else { return }
        do { try ReferenceStore.save(faceID, feature); finish(HelloFaceVerifyOperation.envelope("result", "OK", "", Self.data(value))) }
        catch { fail("STORAGE_ERROR", error.localizedDescription) }
    }
    @objc func cancel() { fail("CANCELLED", "Face operation cancelled") }
    private func fail(_ code: String, _ message: String) { finish(HelloFaceVerifyOperation.envelope("error", code, message)) }
    private func finish(_ response: String) {
        guard !ended else { return }; ended = true
        captured = nil; request?.cancel(); request = nil
        if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
        pipeline.close { [self] in
            if presentingViewController != nil {
                dismiss(animated: true) { [completion] in completion(response) }
            } else { completion(response) }
        }
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
