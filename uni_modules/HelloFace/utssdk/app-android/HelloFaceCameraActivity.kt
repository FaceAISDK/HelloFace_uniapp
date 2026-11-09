package uts.sdk.modules.helloFace

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Size
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.hiface.sdk.HiFaceSdk
import com.hiface.sdk.capture.FaceCaptureListener
import com.hiface.sdk.capture.FaceCaptureResult
import com.hiface.sdk.common.FaceRequest
import com.hiface.sdk.common.HiFaceError
import com.hiface.sdk.common.HiFaceErrorCode
import com.hiface.sdk.flow.FaceAction
import com.hiface.sdk.flow.FaceFlowListener
import com.hiface.sdk.flow.FaceFlowProgress
import com.hiface.sdk.flow.FaceFlowResult
import com.hiface.sdk.frame.Yuv420Frame
import com.hiface.sdk.frame.YuvColorMatrix
import com.hiface.sdk.frame.YuvColorRange
import com.hiface.sdk.verification.FaceVerificationConfig
import org.json.JSONObject
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

class HelloFaceCameraActivity : ComponentActivity() {
    internal var jobID = ""
    private lateinit var current: CameraJob
    private lateinit var preview: PreviewView
    private lateinit var status: TextView
    private lateinit var root: FrameLayout
    private var sdk: HiFaceSdk? = null
    private var request: FaceRequest? = null
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var displayPreview: Preview? = null
    private val analyzer = Executors.newSingleThreadExecutor()
    private var aligned: Bitmap? = null
    private var stopping = false
    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (active()) {
            if (granted) begin() else fail("PERMISSION_DENIED", "Camera permission denied")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        jobID = intent.getStringExtra("requestID") ?: ""
        val pending = HelloFaceNative.job
        if (pending == null || pending.id != jobID || savedInstanceState != null) { finish(); return }
        current = pending
        HelloFaceNative.camera = WeakReference(this)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (!current.committing) fail("CANCELLED", "Face operation cancelled")
            }
        })
        root = FrameLayout(this).apply { setBackgroundColor(0xff000000.toInt()) }
        preview = PreviewView(this).apply { implementationMode = PreviewView.ImplementationMode.COMPATIBLE }
        root.addView(preview, FrameLayout.LayoutParams(-1, -1))
        status = TextView(this).apply {
            text = "请正对镜头，保持人脸在画面中央"
            setTextColor(0xffffffff.toInt()); textSize = 18f; gravity = Gravity.CENTER
            setBackgroundColor(0x88000000.toInt()); setPadding(dp(20), dp(24), dp(20), dp(24))
        }
        root.addView(status, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))
        val cancel = Button(this).apply { text = "取消"; setOnClickListener { fail("CANCELLED", "Face operation cancelled") } }
        root.addView(cancel, FrameLayout.LayoutParams(dp(120), dp(56), Gravity.BOTTOM or Gravity.START).apply {
            leftMargin = dp(20); bottomMargin = dp(32)
        })
        setContentView(root)
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) begin()
        else permission.launch(Manifest.permission.CAMERA)
    }

    private fun active() = HelloFaceNative.job?.id == jobID && !stopping && !isFinishing
    private fun begin() {
        if (!active()) return
        try {
            val instance = HiFaceSdk.builder(this).lifecycleOwner(this).build()
            sdk = instance
            if (current.method == "enrollFace") {
                request = instance.capture().startCameraCapture(object : FaceCaptureListener {
                    override fun onProgress(progress: FaceFlowProgress) = update(progress)
                    override fun onError(error: HiFaceError) = fail(error.code.name, error.message)
                    override fun onResult(result: FaceCaptureResult) = confirmCapture(result)
                })
            } else {
                val p = current.params
                val array = p.getJSONArray("actions")
                val actions = (0 until array.length()).map { action(array.getString(it)) }
                val config = FaceVerificationConfig.builder().referenceFeature(current.reference ?: "")
                    .threshold(p.getDouble("threshold").toFloat())
                    .enableSilentLiveness(p.getBoolean("silentLiveness"))
                    .actions(actions).actionTimeoutMillis(p.getLong("actionTimeoutMs"))
                    .faceAcquisitionTimeoutMillis(p.getLong("faceTimeoutMs")).allowMultipleFaces(false).build()
                request = instance.verification().startCameraVerification(config, object : FaceFlowListener {
                    override fun onProgress(progress: FaceFlowProgress) = update(progress)
                    override fun onError(error: HiFaceError) = fail(error.code.name, error.message)
                    override fun onResult(result: FaceFlowResult) {
                        if (!active()) return
                        finishResult(JSONObject().put("passed", result.isPassed).put("outcome", result.outcome.name)
                            .put("similarity", result.similarity ?: JSONObject.NULL)
                            .put("livenessScore", result.livenessScore ?: JSONObject.NULL))
                    }
                })
            }
            val future = ProcessCameraProvider.getInstance(this)
            future.addListener({
                if (!active()) return@addListener
                try {
                    val cameraProvider = future.get(); provider = cameraProvider
                    val front = current.params.optString("camera", "front") == "front"
                    val selector = if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                    require(cameraProvider.hasCamera(selector)) { "Requested camera is unavailable" }
                    val display = Preview.Builder().build().apply { setSurfaceProvider(preview.surfaceProvider) }
                    displayPreview = display
                    val resolution = ResolutionSelector.Builder().setResolutionStrategy(
                        ResolutionStrategy(Size(640, 480), ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER)).build()
                    val frames = ImageAnalysis.Builder().setResolutionSelector(resolution)
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                    analysis = frames
                    frames.setAnalyzer(analyzer) { image ->
                        try {
                            val planes = image.planes
                            val frame = Yuv420Frame(planes[0].buffer, planes[1].buffer, planes[2].buffer,
                                image.width, image.height, planes[0].rowStride, planes[1].rowStride,
                                planes[2].rowStride, planes[1].pixelStride, YuvColorRange.VIDEO, YuvColorMatrix.BT601,
                                image.imageInfo.rotationDegrees, front)
                            val result = instance.processFrame(frame)
                            if (result.isFailure && result.requireError().code != HiFaceErrorCode.NOT_READY) {
                                val error = result.requireError()
                                runOnUiThread { fail(error.code.name, error.message) }
                            }
                        } catch (error: Exception) {
                            runOnUiThread { fail("CAMERA_ERROR", error.message ?: "Unable to process camera frame") }
                        } finally { image.close() }
                    }
                    cameraProvider.bindToLifecycle(this, selector, display, frames)
                } catch (error: Exception) { fail("CAMERA_ERROR", error.message ?: "Unable to open camera") }
            }, ContextCompat.getMainExecutor(this))
        } catch (error: Exception) { fail("SDK_ERROR", error.message ?: "Unable to start face flow") }
    }

    private fun update(progress: FaceFlowProgress) {
        if (!active()) return
        val action = progress.action?.let { actionName(it) }
        val stage = progress.stage.name
        status.text = if (stage == "PERFORM_ACTION") when (action) {
            "blink" -> "请眨眨眼"; "openMouth" -> "请张张嘴"; "shakeHead" -> "请摇摇头"; "nodHead" -> "请点点头"
            else -> "请完成提示动作"
        } else when (stage) {
            "MULTIPLE_FACES" -> "请保持画面中只有一人"; "FACE_TOO_SMALL" -> "请靠近一些"
            "HOLD_STILL", "FACE_UNSTABLE" -> "请保持不动"; else -> "请正对镜头"
        }
        HelloFaceNative.progress(jobID, JSONObject().put("stage", stage).put("action", action ?: JSONObject.NULL)
            .put("stepNumber", progress.stepNumber).put("stepCount", progress.stepCount))
    }

    private fun confirmCapture(result: FaceCaptureResult) {
        if (!active()) return
        stopAnalysis()
        aligned = result.alignedFace // The SDK creates a Bitmap; read it only once.
        val image = ImageView(this).apply { setImageBitmap(aligned); scaleType = ImageView.ScaleType.FIT_CENTER }
        root.addView(image, FrameLayout.LayoutParams(-1, -1).apply { topMargin = dp(100); bottomMargin = dp(120) })
        status.text = "采集完成，请确认录入"
        val confirm = Button(this).apply {
            text = "确认录入"
            setOnClickListener {
                if (!active() || current.committing) return@setOnClickListener
                current.committing = true; isEnabled = false
                HelloFaceNative.worker.execute {
                    try {
                        ReferenceStore(applicationContext).save(current.params.getString("faceID"), result.feature)
                        HelloFaceNative.finish(jobID, HelloFaceNative.envelope(data = JSONObject()
                            .put("feature", result.feature).put("passed", true).put("outcome", "PASSED")))
                    } catch (error: Exception) {
                        HelloFaceNative.finish(jobID, HelloFaceNative.envelope("error", "STORAGE_ERROR", error.message ?: "Unable to save reference"))
                    }
                }
            }
        }
        root.addView(confirm, FrameLayout.LayoutParams(dp(140), dp(56), Gravity.BOTTOM or Gravity.END).apply {
            rightMargin = dp(20); bottomMargin = dp(32)
        })
    }
    private fun finishResult(data: JSONObject) {
        if (!active()) return
        stopping = true
        HelloFaceNative.finish(jobID, HelloFaceNative.envelope(data = data))
    }
    private fun fail(code: String, message: String) {
        if (!active()) return
        if (code == "CANCELLED" && current.committing) return
        stopping = true
        HelloFaceNative.finish(jobID, HelloFaceNative.envelope("error", code, message))
    }
    override fun onStop() {
        super.onStop()
        if (!isFinishing && ::current.isInitialized && !current.committing) fail("CANCELLED", "Camera moved to background")
    }
    override fun onDestroy() {
        shutdownCamera()
        aligned?.recycle(); aligned = null
        if (::current.isInitialized && HelloFaceNative.job?.id == jobID && !current.committing) {
            HelloFaceNative.finish(jobID, HelloFaceNative.envelope("error", "CANCELLED", "Camera closed"))
        }
        super.onDestroy()
    }
    private fun stopAnalysis() {
        analysis?.clearAnalyzer()
        val owned = listOfNotNull<UseCase>(displayPreview, analysis)
        if (owned.isNotEmpty()) provider?.unbind(*owned.toTypedArray())
    }
    internal fun shutdownCamera() {
        stopping = true
        request?.cancel(); request = null
        stopAnalysis()
        sdk?.close(); sdk = null
        analyzer.shutdown()
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun action(value: String): FaceAction = when (value) {
        "blink" -> FaceAction.BLINK; "openMouth" -> FaceAction.MOUTH_OPEN
        "shakeHead" -> FaceAction.SHAKE_HEAD; "nodHead" -> FaceAction.NOD_HEAD
        else -> throw IllegalArgumentException("Unsupported action")
    }
    private fun actionName(value: FaceAction): String = when (value) {
        FaceAction.BLINK -> "blink"; FaceAction.MOUTH_OPEN -> "openMouth"
        FaceAction.SHAKE_HEAD -> "shakeHead"; FaceAction.NOD_HEAD -> "nodHead"
    }
}
