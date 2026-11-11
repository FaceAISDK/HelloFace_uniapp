import Foundation
import UIKit

public final class HelloFaceVerifyNative {
    public static func invoke(_ method: String, _ raw: String, _ callback: @escaping (String) -> Void) {
        let reply = HelloFaceVerifyReply(callback)
        Task { @MainActor in HelloFaceVerifyOperation.shared.invoke(method, raw) { reply.send($0) } }
    }
}

/// UTS 回调只在主 actor 执行；包装跨 Task 的传递，保持既有公开 Swift 回调签名。
private final class HelloFaceVerifyReply: @unchecked Sendable {
    private let callback: (String) -> Void
    init(_ callback: @escaping (String) -> Void) { self.callback = callback }
    @MainActor func send(_ value: String) { callback(value) }
}

@MainActor
final class HelloFaceVerifyOperation {
    // 所有操作在主 actor 上竞争同一槽位；activeID 阻止旧异步任务收尾新任务。
    static let shared = HelloFaceVerifyOperation()
    private var activeID: UUID?
    private weak var camera: HelloFaceVerifyCameraController?
    private var cancelCallbacks: [(String) -> Void] = []

    nonisolated static func envelope(_ event: String = "result", _ code: String = "OK", _ message: String = "",
                         _ data: [String: Any] = [:]) -> String {
        let object: [String: Any] = ["event": event, "code": code, "message": message, "data": data]
        guard let encoded = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: encoded, encoding: .utf8) else {
            return "{\"event\":\"error\",\"code\":\"BRIDGE_ERROR\",\"message\":\"Invalid native result\"}"
        }
        return string
    }

    func invoke(_ method: String, _ raw: String, _ callback: @escaping (String) -> Void) {
        if method == "cancel" {
            guard let camera = camera else { callback(Self.envelope()); return }
            guard !camera.committing else {
                callback(Self.envelope("error", "BUSY", "Enrollment is being saved")); return
            }
            // 相机关闭并释放槽位后才确认 cancel，允许业务在其 success 中立即发起下一次调用。
            cancelCallbacks.append(callback)
            camera.cancel()
            return
        }
        guard activeID == nil else { callback(Self.envelope("error", "BUSY", "A face operation is active")); return }
        guard let bytes = raw.data(using: .utf8), let params = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              let faceID = params["faceID"] as? String else {
            callback(Self.envelope("error", "INVALID_ARGUMENT", "Invalid parameters")); return
        }
        let id = UUID()
        activeID = id
        let finish: (String) -> Void = { [weak self] value in
            guard let self = self, self.activeID == id else { return }
            self.activeID = nil
            self.camera = nil
            let cancellations = self.cancelCallbacks
            self.cancelCallbacks = []
            callback(value)
            cancellations.forEach { $0(Self.envelope()) }
        }
        do {
            let feature: String?
            if method == "verifyFace", let incoming = params["referenceFeature"] as? String { feature = incoming }
            else if method == "deleteFace" { feature = nil }
            else { feature = try ReferenceStore.get(faceID) }
            switch method {
            case "getFaceFeature":
                guard let feature = feature else { throw HelloFaceVerifyBridgeError.failure("NOT_FOUND", "No enrolled face for faceID") }
                finish(Self.envelope("result", "OK", "", ["feature": feature]))
            case "deleteFace":
                try ReferenceStore.delete(faceID)
                finish(Self.envelope())
            case "setFaceFeature", "syncFaceFeature":
                if feature != nil && !(params["overwrite"] as? Bool ?? false) { throw HelloFaceVerifyBridgeError.failure("ALREADY_EXISTS", "Face already enrolled") }
                guard let incoming = params["feature"] as? String else { throw HelloFaceVerifyBridgeError.failure("INVALID_ARGUMENT", "Missing feature") }
                try ReferenceStore.save(faceID, incoming)
                finish(Self.envelope("result", "OK", "", ["feature": incoming]))
            case "syncFaceImage":
                if feature != nil && !(params["overwrite"] as? Bool ?? false) {
                    throw HelloFaceVerifyBridgeError.failure("ALREADY_EXISTS", "Face already enrolled")
                }
                guard let image = params["imageBase64"] as? String else {
                    throw HelloFaceVerifyBridgeError.failure("INVALID_ARGUMENT", "Missing imageBase64")
                }
                Task { @MainActor in
                    do {
                        let incoming = try await FaceImageImporter.extract(image)
                        try ReferenceStore.save(faceID, incoming)
                        finish(Self.envelope("result", "OK", "", ["feature": incoming]))
                    } catch HelloFaceVerifyBridgeError.failure(let code, let message) {
                        finish(Self.envelope("error", code, message))
                    } catch { finish(Self.envelope("error", "STORAGE_ERROR", error.localizedDescription)) }
                }
            case "enrollFace", "verifyFace":
                if method == "enrollFace" && feature != nil && !(params["overwrite"] as? Bool ?? false) {
                    throw HelloFaceVerifyBridgeError.failure("ALREADY_EXISTS", "Face already enrolled")
                }
                if method == "verifyFace" && feature == nil { throw HelloFaceVerifyBridgeError.failure("NOT_FOUND", "Enroll this faceID first") }
                guard let presenter = Self.presenter(), presenter.viewIfLoaded?.window != nil,
                      !presenter.isBeingPresented, !presenter.isBeingDismissed else {
                    throw HelloFaceVerifyBridgeError.failure("NO_CONTEXT", "No foreground view controller")
                }
                let controller = HelloFaceVerifyCameraController(method: method, params: params,
                    reference: feature, progress: { data in
                        guard self.activeID == id else { return }
                        callback(Self.envelope("progress", "OK", "", data))
                    }, completion: finish)
                controller.modalPresentationStyle = .fullScreen
                camera = controller
                presenter.present(controller, animated: true) { controller.presentationDidFinish() }
            default: throw HelloFaceVerifyBridgeError.failure("INVALID_ARGUMENT", "Unknown operation")
            }
        } catch HelloFaceVerifyBridgeError.failure(let code, let message) {
            finish(Self.envelope("error", code, message))
        } catch {
            finish(Self.envelope("error", "STORAGE_ERROR", error.localizedDescription))
        }
    }

    private static func presenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var controller = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while true {
            if let presented = controller?.presentedViewController { controller = presented }
            else if let navigation = controller as? UINavigationController { controller = navigation.visibleViewController }
            else if let tab = controller as? UITabBarController { controller = tab.selectedViewController }
            else { return controller }
        }
    }
}
