import Foundation

@main
struct CameraStateChecks {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        var progress = HelloFaceVerifyCaptureProgress()
        check(HelloFaceVerifyCaptureProgress.duration == 0.7, "Match SDK hold duration")
        check(progress.update(enrollment: true, stage: "HOLD_STILL"), "Start the first hold")
        check(!progress.update(enrollment: true, stage: "HOLD_STILL"), "Repeated progress must not restart")
        for stage in ["WAITING_FOR_FACE", "MULTIPLE_FACES", "FACE_TOO_SMALL", "FACE_NOT_FRONTAL", "FACE_FORWARD", "FACE_UNSTABLE"] {
            _ = progress.update(enrollment: true, stage: "HOLD_STILL")
            check(!progress.update(enrollment: true, stage: stage) && !progress.holding, "Invalid face resets hold")
        }
        check(!progress.update(enrollment: false, stage: "HOLD_STILL"), "Verification cannot start enrollment ring")
        _ = progress.update(enrollment: true, stage: "HOLD_STILL")
        progress.reset()
        check(!progress.holding, "Retake, confirmation and leaving stop animation")

        var earlyCancel = HelloFaceVerifyCameraLifecycle()
        check(earlyCancel.finish("cancelled"), "Accept early cancel once")
        earlyCancel.didClose()
        check(earlyCancel.takeResponse() == nil, "Do not finish while presentation animation is pending")
        earlyCancel.didPresent()
        check(earlyCancel.takeResponse() == "cancelled", "Finish after presentation and camera close")
        check(earlyCancel.takeResponse() == nil, "Complete only once")

        var ordinary = HelloFaceVerifyCameraLifecycle()
        ordinary.didPresent()
        check(ordinary.finish("sdk-result"), "Accept actual SDK terminal result")
        check(!ordinary.finish("late-error"), "Late callback cannot replace result")
        check(ordinary.takeResponse() == nil, "Wait for resource release")
        ordinary.didClose()
        check(ordinary.takeResponse() == "sdk-result", "Keep original SDK result")
        ordinary.didPresent(); ordinary.didClose()
        check(ordinary.takeResponse() == nil, "Repeated lifecycle events cannot repeat completion")
        print("PASS \(checks) iOS camera state checks (no camera or recognition simulated)")
    }
}
