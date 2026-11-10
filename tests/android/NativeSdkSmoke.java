package dev.helloface.smoke;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.WindowManager;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

public final class NativeSdkSmoke extends Instrumentation {
    private Context target;
    private Class<?> functionType;
    private Method nativeInvoke;
    private Object unit;
    private int checks;
    private boolean created;
    private String faceID;
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    private static final class Pending {
        final LinkedBlockingQueue<String> events = new LinkedBlockingQueue<>();
        JSONObject terminal() throws Exception {
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(25);
            while (System.nanoTime() < deadline) {
                String raw = events.poll(1, TimeUnit.SECONDS);
                if (raw == null) continue;
                JSONObject result = new JSONObject(raw);
                if (!result.optString("event").equals("progress")) return result;
            }
            throw new IllegalStateException("Native operation did not complete within 25 seconds");
        }
    }
    private Pending call(String method, JSONObject params) throws Exception {
        final Pending pending = new Pending();
        Object callback = Proxy.newProxyInstance(functionType.getClassLoader(), new Class<?>[]{functionType},
            new InvocationHandler() {
                @Override public Object invoke(Object proxy, Method method, Object[] args) {
                    if (method.getName().equals("invoke")) { pending.events.offer((String) args[0]); return unit; }
                    if (method.getName().equals("toString")) return "HelloFace native smoke callback";
                    if (method.getName().equals("hashCode")) return System.identityHashCode(proxy);
                    if (method.getName().equals("equals")) return proxy == args[0];
                    return null;
                }
            });
        nativeInvoke.invoke(null, target, method, params.toString(), callback);
        return pending;
    }
    private void expect(JSONObject result, String expected, String name) throws Exception {
        if (!result.optString("code").equals(expected)) {
            throw new IllegalStateException(name + ": " + result.optString("code") + " / " + result.optString("message"));
        }
        checks++; report("PASS " + name);
    }
    private void report(String text) {
        Bundle data = new Bundle(); data.putString("stream", text + "\n"); sendStatus(0, data);
    }
    private void cleanInterruptedChecks() throws Exception {
        String prefix = "jdx-feature-v1:";
        int removed = 0;
        for (String account : target.getSharedPreferences("helloface.references.v1", Context.MODE_PRIVATE).getAll().keySet()) {
            if (!account.matches("jdx-feature-v1:__helloface_smoke_[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}")) continue;
            JSONObject response = call("deleteFace", new JSONObject().put("faceID", account.substring(prefix.length()))).terminal();
            if (!response.optString("code").equals("OK")) throw new IllegalStateException("Unable to remove interrupted test reference");
            removed++;
        }
        if (removed > 0) report("Removed interrupted test references: " + removed);
    }
    @Override public void onStart() {
        Bundle result = new Bundle();
        int status = Activity.RESULT_CANCELED;
        try {
            target = getTargetContext().getApplicationContext();
            // Ask the ADB runner to foreground the host with its shell identity.
            // This avoids background-launch restrictions and UiAutomation races.
            Intent launcher = target.getPackageManager().getLaunchIntentForPackage(target.getPackageName());
            if (launcher != null && launcher.getComponent() != null) {
                ActivityMonitor host = addMonitor(launcher.getComponent().getClassName(), null, false);
                report("READY: launch target host " + launcher.getComponent().flattenToString());
                Activity launched = waitForMonitorWithTimeout(host, 15000);
                removeMonitor(host);
                if (launched == null) throw new IllegalStateException("Target host did not open");
            }
            ClassLoader loader = getTargetContext().getClassLoader();
            functionType = Class.forName("kotlin.jvm.functions.Function1", true, loader);
            nativeInvoke = Class.forName("uts.sdk.modules.HelloFaceVerify.HelloFaceVerifyNative", true, loader)
                .getMethod("invoke", Context.class, String.class, String.class, functionType);
            unit = Class.forName("kotlin.Unit", true, loader).getField("INSTANCE").get(null);
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            try (InputStream input = getContext().getAssets().open("fixture.json")) {
                byte[] buffer = new byte[4096]; int count;
                while ((count = input.read(buffer)) >= 0) bytes.write(buffer, 0, count);
            }
            JSONObject fixture = new JSONObject(bytes.toString("UTF-8"));
            cleanInterruptedChecks();
            faceID = "__helloface_smoke_" + java.util.UUID.randomUUID().toString();
            JSONObject identity = new JSONObject().put("faceID", faceID);
            expect(call("getFaceFeature", identity).terminal(), "NOT_FOUND", "missing reference");
            JSONObject incoming = new JSONObject().put("faceID", faceID).put("feature", fixture.getString("feature"))
                .put("overwrite", false).put("featureSpaceID", "jdx-feature-v1");
            expect(call("setFaceFeature", incoming).terminal(), "OK", "Android Keystore encrypted write");
            created = true;
            JSONObject read = call("getFaceFeature", identity).terminal();
            expect(read, "OK", "Android Keystore decrypted read");
            if (!read.getJSONObject("data").getString("feature").equals(fixture.getString("feature")))
                throw new IllegalStateException("Feature round trip changed data");
            checks++; report("PASS feature round trip preserved data");
            expect(call("setFaceFeature", incoming).terminal(), "ALREADY_EXISTS", "overwrite protection");
            JSONObject verification = new JSONObject().put("faceID", faceID).put("threshold", 0.8)
                .put("silentLiveness", false).put("actions", new org.json.JSONArray())
                .put("actionTimeoutMs", 2000).put("faceTimeoutMs", 1000).put("camera", "front");
            JSONObject verdict = call("verifyFace", verification).terminal();
            expect(verdict, "OK", "real SDK verification completed");
            JSONObject data = verdict.getJSONObject("data");
            if (!data.has("passed") || data.isNull("outcome")) throw new IllegalStateException("Missing SDK verdict");
            if (data.getBoolean("passed") || !data.getString("outcome").equals("NO_FACE_TIMEOUT"))
                throw new IllegalStateException("Expected NO_FACE_TIMEOUT with an empty camera view");
            report("SDK verification outcome=" + data.getString("outcome") + ", passed=" + data.getBoolean("passed"));
            verification.put("faceTimeoutMs", 10000);
            Pending active = call("verifyFace", verification);
            expect(call("getFaceFeature", identity).terminal(), "BUSY", "concurrent API request rejected");
            expect(call("cancel", new JSONObject()).terminal(), "OK", "cancel request acknowledged");
            expect(active.terminal(), "CANCELLED", "active request cancelled");
            expect(call("getFaceFeature", identity).terminal(), "OK", "operation slot released after cancel");
            ActivityMonitor monitor = addMonitor("uts.sdk.modules.HelloFaceVerify.HelloFaceVerifyCameraActivity", null, false);
            Pending enrollment = call("enrollFace", new JSONObject().put("faceID", faceID).put("overwrite", true).put("camera", "front"));
            final Activity captureActivity = waitForMonitorWithTimeout(monitor, 10000);
            removeMonitor(monitor);
            if (captureActivity == null) throw new IllegalStateException("Enrollment Activity did not open");
            if ((captureActivity.getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) == 0)
                throw new IllegalStateException("Camera page must keep its own window awake");
            checks++; report("PASS camera window stays awake without changing system settings");
            final String unchangedFeature = fixture.getString("feature");
            final Throwable[] retakeError = new Throwable[1];
            runOnMainSync(new Runnable() {
                @Override public void run() {
                    try {
                        // Inject only the confirmation state. No image is recognized or saved by this UI test.
                        java.lang.reflect.Field field = captureActivity.getClass().getDeclaredField("capturedFeature");
                        field.setAccessible(true); field.set(captureActivity, unchangedFeature);
                        Method retake = captureActivity.getClass().getDeclaredMethod("retake");
                        retake.setAccessible(true); retake.invoke(captureActivity);
                    } catch (Throwable error) { retakeError[0] = error; }
                }
            });
            if (retakeError[0] != null) throw new IllegalStateException("Retake failed", retakeError[0]);
            waitForIdleSync();
            expect(call("getFaceFeature", identity).terminal(), "BUSY", "retake keeps the enrollment operation active");
            expect(call("cancel", new JSONObject()).terminal(), "OK", "retaken capture can be cancelled");
            expect(enrollment.terminal(), "CANCELLED", "old capture callbacks do not finish the new attempt");
            JSONObject afterRetake = call("getFaceFeature", identity).terminal();
            if (!afterRetake.optString("code").equals("OK") ||
                !afterRetake.getJSONObject("data").getString("feature").equals(unchangedFeature))
                throw new IllegalStateException("Retake changed the saved reference without confirmation");
            checks++; report("PASS retake preserves the saved reference until confirmation");
            expect(call("deleteFace", identity).terminal(), "OK", "reference deletion");
            created = false;
            expect(call("getFaceFeature", identity).terminal(), "NOT_FOUND", "deleted reference absent");
            // No local enrollment exists: use the supplied reference for this operation only.
            created = true; // Cleanup also covers an unintended persistence regression.
            verification.put("referenceFeature", fixture.getString("feature"))
                .put("featureSpaceID", "jdx-feature-v1").put("faceTimeoutMs", 1000);
            JSONObject transientResult = call("verifyFace", verification).terminal();
            expect(transientResult, "OK", "transient reference reaches the real SDK without local enrollment");
            JSONObject transientData = transientResult.getJSONObject("data");
            if (transientData.getBoolean("passed") || !transientData.getString("outcome").equals("NO_FACE_TIMEOUT") ||
                (transientData.has("feature") && !transientData.isNull("feature")))
                throw new IllegalStateException("Transient verification returned an invalid or sensitive result");
            checks++; report("PASS transient verification preserves the real SDK verdict without exposing features");
            expect(call("getFaceFeature", identity).terminal(), "NOT_FOUND", "transient reference is not persisted");
            created = false;
            status = Activity.RESULT_OK;
            result.putString("stream", "PASS: " + checks + " native integration checks. No face match accuracy claim.\n");
        } catch (Throwable error) {
            Throwable cause = error;
            while (cause.getCause() != null) cause = cause.getCause();
            result.putString("stream", "FAIL: " + cause.getClass().getName() + ": " + cause.getMessage() + "\n");
        } finally {
            if (created && nativeInvoke != null) {
                try {
                    call("cancel", new JSONObject()).terminal();
                    call("deleteFace", new JSONObject().put("faceID", faceID)).terminal();
                } catch (Exception ignored) { result.putString("cleanup", "Temporary smoke reference requires cleanup"); }
            }
        }
        finish(status, result);
    }
}
