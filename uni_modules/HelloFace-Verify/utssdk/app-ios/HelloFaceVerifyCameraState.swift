import Foundation

/// 仅管理录入圆环的视觉阶段，不触发采集、保存或识别成功。
struct HelloFaceVerifyCaptureProgress {
    static let duration: TimeInterval = 0.7 // SDK 0.8.11 的引导录入稳定窗口。
    private(set) var holding = false

    mutating func update(enrollment: Bool, stage: String) -> Bool {
        guard enrollment && stage == "HOLD_STILL" else { reset(); return false }
        guard !holding else { return false }
        holding = true
        return true
    }
    mutating func reset() { holding = false }
}

/// 原生 Demo 的动作总倒计时：换步骤及短暂丢脸保持原截止时刻；不产生业务结果。
struct HelloFaceVerifyActionCountdown {
    private(set) var deadline: TimeInterval?
    private(set) var duration: TimeInterval = 0
    mutating func update(enrollment: Bool, stage: String, action: String?, count: Int,
                         timeoutMs: Int64, now: TimeInterval) {
        guard !enrollment, count > 0, timeoutMs > 0,
              stage == "PERFORM_ACTION" || action != nil,
              !["FACE_FORWARD", "FACE_NOT_FRONTAL", "HOLD_STILL", "FACE_UNSTABLE"].contains(stage) else { reset(); return }
        guard deadline == nil, stage == "PERFORM_ACTION" else { return }
        duration = Double(timeoutMs) / 1000 * Double(count)
        deadline = now + duration
    }
    func remaining(at now: TimeInterval) -> TimeInterval { max(0, (deadline ?? now) - now) }
    func progress(at now: TimeInterval) -> Double { duration > 0 ? min(1, remaining(at: now) / duration) : 0 }
    mutating func reset() { deadline = nil; duration = 0 }
}

/// 权限拒绝或快速取消可能先于弹出动画完成；必须等页面弹出和资源释放后再结束调用。
struct HelloFaceVerifyCameraLifecycle {
    private(set) var ended = false
    private var presented = false
    private var closed = false
    private var response: String?

    mutating func finish(_ response: String) -> Bool {
        guard !ended else { return false }
        ended = true
        self.response = response
        return true
    }
    mutating func didPresent() { presented = true }
    mutating func didClose() { closed = true }
    mutating func takeResponse() -> String? {
        guard presented && closed, let value = response else { return nil }
        response = nil
        return value
    }
}
