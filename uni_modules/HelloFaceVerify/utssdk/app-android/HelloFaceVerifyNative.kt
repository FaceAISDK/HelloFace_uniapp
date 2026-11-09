package uts.sdk.modules.HelloFaceVerify

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.lang.ref.WeakReference
import java.util.UUID
import java.util.concurrent.Executors

internal class CameraJob(val id: String, val method: String, val params: JSONObject,
    val callback: (String) -> Unit, var reference: String? = null, var committing: Boolean = false)

object HelloFaceVerifyNative {
    internal val main = Handler(Looper.getMainLooper())
    internal val worker = Executors.newSingleThreadExecutor()
    @Volatile internal var job: CameraJob? = null
    internal var camera = WeakReference<HelloFaceVerifyCameraActivity>(null)

    internal fun envelope(event: String = "result", code: String = "OK", message: String = "",
        data: JSONObject = JSONObject()): String = JSONObject().put("event", event).put("code", code)
        .put("message", message).put("data", data).toString()

    internal fun finish(id: String, response: String) {
        main.post {
            val current = job
            if (current?.id != id) return@post
            job = null
            camera.get()?.takeIf { it.jobID == id }?.let { it.shutdownCamera(); it.finish() }
            camera.clear()
            current.callback(response)
        }
    }

    internal fun progress(id: String, data: JSONObject) {
        main.post { job?.takeIf { it.id == id }?.callback?.invoke(envelope("progress", data = data)) }
    }

    @JvmStatic fun invoke(context: Context, method: String, raw: String, callback: (String) -> Unit) {
        main.post {
            if (method == "cancel") {
                val current = job
                if (current == null || current.method !in listOf("enrollFace", "verifyFace")) callback(envelope())
                else if (current.committing) callback(envelope("error", "BUSY", "Enrollment is being saved"))
                else {
                    // Clear the task before callbacks to make reentrant calls safe.
                    job = null
                    camera.get()?.let { it.shutdownCamera(); it.finish() }
                    camera.clear()
                    current.callback(envelope("error", "CANCELLED", "Face operation cancelled"))
                    callback(envelope())
                }
                return@post
            }
            if (job != null) { callback(envelope("error", "BUSY", "A face operation is active")); return@post }
            val params = try { JSONObject(raw) } catch (error: Exception) {
                callback(envelope("error", "INVALID_ARGUMENT", "Invalid parameters")); return@post
            }
            val current = CameraJob(UUID.randomUUID().toString(), method, params, callback)
            // All operations share the same slot, including storage mutations.
            job = current
            worker.execute {
                try {
                    val faceID = params.getString("faceID")
                    val store = ReferenceStore(context.applicationContext)
                    val feature = if (method == "deleteFace") null else store.get(faceID)
                    when (method) {
                        "getFaceFeature" -> {
                            if (feature == null) finish(current.id, envelope("error", "NOT_FOUND", "No enrolled face for faceID"))
                            else finish(current.id, envelope(data = JSONObject().put("feature", feature)))
                        }
                        "deleteFace" -> { store.delete(faceID); finish(current.id, envelope()) }
                        "setFaceFeature" -> {
                            if (feature != null && !params.optBoolean("overwrite")) {
                                finish(current.id, envelope("error", "ALREADY_EXISTS", "Face already enrolled"))
                            } else {
                                // UTS validates both HF1 syntax and its declared feature space.
                                store.save(faceID, params.getString("feature"))
                                finish(current.id, envelope(data = JSONObject().put("feature", params.getString("feature"))))
                            }
                        }
                        "enrollFace", "verifyFace" -> {
                            if (method == "enrollFace" && feature != null && !params.optBoolean("overwrite")) {
                                finish(current.id, envelope("error", "ALREADY_EXISTS", "Face already enrolled"))
                            } else if (method == "verifyFace" && feature == null) {
                                finish(current.id, envelope("error", "NOT_FOUND", "Enroll this faceID first"))
                            } else {
                                current.reference = feature
                                main.post {
                                    if (job?.id == current.id) {
                                        try {
                                            context.startActivity(Intent(context, HelloFaceVerifyCameraActivity::class.java)
                                                .putExtra("requestID", current.id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                        } catch (error: Exception) {
                                            finish(current.id, envelope("error", "CAMERA_ERROR", error.message ?: "Unable to launch camera"))
                                        }
                                    }
                                }
                            }
                        }
                        else -> finish(current.id, envelope("error", "INVALID_ARGUMENT", "Unknown operation"))
                    }
                } catch (error: Exception) {
                    finish(current.id, envelope("error", "STORAGE_ERROR", error.message ?: "Reference storage failed"))
                }
            }
        }
    }
}
