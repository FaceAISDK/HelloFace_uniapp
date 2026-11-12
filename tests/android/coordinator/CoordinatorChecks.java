package uts.sdk.modules.HelloFaceVerify;

import android.content.Context;
import android.os.Looper;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;
import kotlin.Unit;
import kotlin.jvm.functions.Function0;
import kotlin.jvm.functions.Function1;
import org.json.JSONObject;

/** Loads the actual compiled Native coordinator. Only Android main-loop, Activity teardown
 * and debug logging are boundaries. No frame, identity or liveness result is generated.
 */
public final class CoordinatorChecks {
    private static final HelloFaceVerifyNative NATIVE = HelloFaceVerifyNative.INSTANCE;
    private static final List<String> replies = new ArrayList<>();
    private static Context context;
    private static void require(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
    private static Function1<String, Unit> reply(String name) {
        return value -> { replies.add(name + ":" + value); return Unit.INSTANCE; };
    }
    private static CameraJob start(String id) {
        CameraJob job = new CameraJob(id, "detectLiveness", new JSONObject(), reply("result"), null, false);
        NATIVE.setJob(job);
        NATIVE.setCamera(new WeakReference<>(new HelloFaceVerifyCameraActivity(id)));
        replies.clear();
        return job;
    }
    private static void cancel(String name) { HelloFaceVerifyNative.invoke(context, "cancel", "{}", reply(name)); }
    public static void main(String[] args) throws Exception {
        context = new Context();
        try {
            CameraJob first = start("first");
            HelloFaceVerifyCameraActivity activity = NATIVE.getCamera().get();
            NATIVE.finish("first", "sdk-result");
            NATIVE.finish("first", "late-result");
            Looper.idle();
            require(NATIVE.getJob() == first && replies.isEmpty(), "Released before camera drain");
            require(activity.shutdowns == 1 && activity.finishes == 0, "Duplicate or premature teardown");
            cancel("cancel-1"); cancel("cancel-2");
            HelloFaceVerifyNative.invoke(context, "getFaceStatue", "{}", reply("busy"));
            NATIVE.progress("first", new JSONObject().put("stage", "WAITING_FOR_FACE"));
            Looper.idle();
            require(replies.size() == 1 && replies.get(0).contains("BUSY"), "Slot/progress leaked during drain");
            activity.closed.invoke();
            require(NATIVE.getJob() == null && activity.finishes == 1, "Drain did not release camera");
            require(replies.size() == 4 && replies.get(1).equals("result:sdk-result") &&
                replies.get(2).startsWith("cancel-1:") && replies.get(3).startsWith("cancel-2:"), "Lost first result or cancel acknowledgement");
            System.out.println("PASS compiled coordinator: hold slot until drain, first result wins, repeated cancel");

            CameraJob second = start("second"); activity = NATIVE.getCamera().get();
            cancel("cancel"); Looper.idle();
            require(NATIVE.getJob() == second && replies.isEmpty(), "Cancel acknowledged before drain");
            activity.closed.invoke();
            require(replies.size() == 2 && replies.get(0).contains("CANCELLED") && replies.get(1).startsWith("cancel:"), "Cancel result order");
            System.out.println("PASS compiled coordinator: cancel acknowledgement follows original cancellation");

            CameraJob third = start("third"); activity = NATIVE.getCamera().get();
            CameraJob reentrant = new CameraJob("reentrant", "detectLiveness", new JSONObject(), reply("next"), null, false);
            third.getCancellations().add(value -> { NATIVE.setJob(reentrant); return Unit.INSTANCE; });
            NATIVE.finish("third", "done"); Looper.idle(); activity.closed.invoke();
            NATIVE.finish("third", "stale"); Looper.idle();
            require(NATIVE.getJob() == reentrant && replies.size() == 1, "Old cleanup finished reentrant operation");
            System.out.println("PASS compiled coordinator: reentrant operation survives late old results");

            CameraJob saving = start("saving"); saving.setCommitting(true);
            cancel("cancel"); Looper.idle();
            require(NATIVE.getJob() == saving && replies.size() == 1 && replies.get(0).contains("BUSY"), "Cancelled committed save");
            System.out.println("PASS compiled coordinator: enrollment commit cannot be cancelled");
        } finally { NATIVE.setJob(null); NATIVE.getWorker().shutdownNow(); }
    }
}

final class HelloFaceVerifyCameraActivity {
    private final String id;
    int shutdowns, finishes;
    Function0<Unit> closed;
    HelloFaceVerifyCameraActivity(String id) { this.id = id; }
    public String getJobID() { return id; }
    public void shutdownCamera(Function0<Unit> completion) { shutdowns++; closed = completion; }
    public void finish() { finishes++; }
}

final class HelloFaceVerifyDebug {
    public static final HelloFaceVerifyDebug INSTANCE = new HelloFaceVerifyDebug();
    public Function1<String, Unit> trace(Context context, String method, Function1<String, Unit> reply) { return reply; }
}
