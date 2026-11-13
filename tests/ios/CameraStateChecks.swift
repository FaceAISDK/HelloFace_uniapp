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

        var action = HelloFaceVerifyActionCountdown()
        action.update(enrollment: false, stage: "PERFORM_ACTION", action: "blink", count: 2, timeoutMs: 3000, now: 10)
        check(action.deadline == 16 && action.duration == 6, "One total duration across actions")
        check(action.progress(at: 11.5) == 0.75, "Monotonic countdown fraction")
        action.update(enrollment: false, stage: "PERFORM_ACTION", action: "nodHead", count: 2, timeoutMs: 3000, now: 12)
        check(action.deadline == 16, "Next or repeated action must not restart deadline")
        action.update(enrollment: false, stage: "WAITING_FOR_FACE", action: "nodHead", count: 2, timeoutMs: 3000, now: 13)
        check(action.deadline == 16, "Short face loss retains deadline")
        check(action.remaining(at: 20) == 0 && action.progress(at: 20) == 0, "Countdown clamps at zero without SDK outcome")
        action.update(enrollment: false, stage: "PERFORM_ACTION", action: "nodHead", count: 2, timeoutMs: 3000, now: 21)
        check(action.deadline == 16, "Expired visual timer cannot restart")
        for stage in ["WAITING_FOR_FACE", "FACE_FORWARD", "FACE_NOT_FRONTAL", "HOLD_STILL", "FACE_UNSTABLE"] {
            action.update(enrollment: false, stage: stage, action: nil, count: 2, timeoutMs: 3000, now: 22)
            check(action.deadline == nil, "Inactive action or frontal hold resets")
            action.update(enrollment: false, stage: "PERFORM_ACTION", action: "blink", count: 4, timeoutMs: 5000, now: 23)
            check(action.duration == 20, "Explicit timeout times action count")
        }
        action.reset()
        check(action.deadline == nil && action.duration == 0, "Leaving or retake releases countdown")
        action.update(enrollment: true, stage: "PERFORM_ACTION", action: "blink", count: 2, timeoutMs: 3000, now: 0)
        check(action.deadline == nil, "Enrollment has no action countdown")
        action.update(enrollment: false, stage: "PERFORM_ACTION", action: "blink", count: 0, timeoutMs: 3000, now: 0)
        check(action.deadline == nil, "Empty actions do not start countdown")

        func supported(_ width: Int, _ height: Int) -> Bool {
            HelloFaceVerifyCameraFrameSize.isSupported(width: width, height: height, maximumLongSide: 1920, maximumShortSide: 1080)
        }
        for (width, height) in [(640, 480), (480, 640), (1920, 1080), (1080, 1920)] {
            check(supported(width, height), "Support valid landscape and portrait SDK dimensions")
        }
        for (width, height) in [(0, 480), (-2, 480), (641, 480), (640, 481), (1922, 1080), (1920, 1082), (1082, 1920)] {
            check(!supported(width, height), "Reject nonpositive, odd or oversized frames before SDK")
        }
        var attempts = HelloFaceVerifyCameraLifecycle()
        check(!attempts.accepts(0), "No callback is accepted before the first attempt")
        let first = attempts.beginAttempt()!
        check(attempts.accepts(first), "Accept current SDK progress")
        let pausedRetake = attempts.beginAttempt()!
        check(!attempts.accepts(first), "Retake rejects queued events from the previous SDK request")
        check(attempts.accepts(pausedRetake), "Restart only after pause completes for the current attempt")
        let next = attempts.beginAttempt()!
        check(!attempts.accepts(pausedRetake) && attempts.accepts(next), "Restart invalidates the old pause callback")
        check(attempts.finish("cancelled"), "Cancel while pause or request callbacks are pending")
        check(!attempts.accepts(next), "Closing rejects queued callbacks before resource release")
        check(attempts.beginAttempt() == nil, "A late pause callback cannot reopen a closed camera")

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
