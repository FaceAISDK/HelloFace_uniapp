package uts.sdk.modules.HelloFaceVerify

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.os.Bundle
import android.os.Build
import android.util.Size
import android.view.WindowInsets
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
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

class HelloFaceVerifyCameraActivity : ComponentActivity() {
    @PublishedApi internal var jobID = ""
    private lateinit var current: CameraJob
    private lateinit var preview: PreviewView
    private lateinit var screen: HelloFaceVerifyCameraView
    private var sdk: HiFaceSdk? = null
    private var request: FaceRequest? = null
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var displayPreview: Preview? = null
    private val analyzer = Executors.newSingleThreadExecutor()
    private var aligned: Bitmap? = null
    private var capturedFeature: String? = null
    private var generation = 0
    private var stopping = false
    private var previousBrightness: Float? = null
    private var brightnessApplied = false
    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (active()) {
            if (granted) begin() else fail("PERMISSION_DENIED", "Camera permission denied")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        jobID = intent.getStringExtra("requestID") ?: ""
        val pending = HelloFaceVerifyNative.job
        if (pending == null || pending.id != jobID || savedInstanceState != null) { finish(); return }
        current = pending
        HelloFaceVerifyNative.camera = WeakReference(this)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (!current.committing) fail("CANCELLED", "Face operation cancelled")
            }
        })
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // AndroidX selects modern system-bar APIs and the API 23/25 fallback.
        // Transparent bars reveal the native screen's shared background color.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, HelloFaceVerifyPresentation.colorInk)
        )
        screen = HelloFaceVerifyCameraView(this, current.method == "enrollFace",
            { fail("CANCELLED", "Face operation cancelled") }, { retake() }, { confirm() })
        preview = screen.preview
        setContentView(screen)
        screen.setOnApplyWindowInsetsListener { _, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val safe = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                screen.setSafeInsets(safe.left, safe.top, safe.right, safe.bottom)
            } else applyLegacySafeInsets(insets)
            insets
        }
        screen.requestApplyInsets()
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) begin()
        else permission.launch(Manifest.permission.CAMERA)
    }

    // API 23..29 have no WindowInsets.getInsets(Type) API. Keep that fallback
    // isolated; some HBuilderX uni-app Core stubs also predate the compat API.
    @Suppress("DEPRECATION")
    private fun applyLegacySafeInsets(insets: WindowInsets) {
        val cutout = if (Build.VERSION.SDK_INT >= 28) insets.displayCutout else null
        screen.setSafeInsets(maxOf(insets.systemWindowInsetLeft, cutout?.safeInsetLeft ?: 0),
            maxOf(insets.systemWindowInsetTop, cutout?.safeInsetTop ?: 0),
            maxOf(insets.systemWindowInsetRight, cutout?.safeInsetRight ?: 0),
            maxOf(insets.systemWindowInsetBottom, cutout?.safeInsetBottom ?: 0))
    }

    private fun active() = HelloFaceVerifyNative.job?.id == jobID && !stopping && !isFinishing
    override fun onResume() {
        super.onResume()
        if (active()) {
            // 只覆盖相机窗口；保留 -1（跟随系统）及宿主原有的窗口亮度策略。
            if (previousBrightness == null) previousBrightness = window.attributes.screenBrightness
            window.attributes = window.attributes.apply { screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL }
            brightnessApplied = true
        }
    }
    override fun onPause() {
        restoreBrightness()
        super.onPause()
    }
    private fun restoreBrightness() {
        val previous = previousBrightness ?: return
        if (!brightnessApplied) return
        window.attributes = window.attributes.apply { screenBrightness = previous }
        brightnessApplied = false
    }
    private fun begin() {
        if (!active()) return
        val attempt = ++generation
        try {
            val instance = HiFaceSdk.builder(this).lifecycleOwner(this).build()
            sdk = instance
            if (current.method == "enrollFace") {
                request = instance.capture().startCameraCapture(object : FaceCaptureListener {
                    override fun onProgress(progress: FaceFlowProgress) { if (active() && generation == attempt) update(progress) }
                    override fun onError(error: HiFaceError) { if (active() && generation == attempt) fail(error.code.name, error.message) }
                    override fun onResult(result: FaceCaptureResult) { if (active() && generation == attempt) confirmCapture(result) }
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
                    override fun onProgress(progress: FaceFlowProgress) { if (active() && generation == attempt) update(progress) }
                    override fun onError(error: HiFaceError) { if (active() && generation == attempt) fail(error.code.name, error.message) }
                    override fun onResult(result: FaceFlowResult) {
                        if (!active() || generation != attempt) return
                        finishResult(JSONObject().put("passed", result.isPassed).put("outcome", result.outcome.name)
                            .put("similarity", result.similarity ?: JSONObject.NULL)
                            .put("livenessScore", result.livenessScore ?: JSONObject.NULL))
                    }
                })
            }
            val future = ProcessCameraProvider.getInstance(this)
            future.addListener({
                if (!active() || generation != attempt) return@addListener
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
                    frames.setAnalyzer(analyzer, object : ImageAnalysis.Analyzer {
                        // Explicit defaults also work when host/plugin desugaring is separate on API 23.
                        override fun getDefaultTargetResolution(): Size? = null
                        override fun getTargetCoordinateSystem() = ImageAnalysis.COORDINATE_SYSTEM_ORIGINAL
                        override fun updateTransform(matrix: Matrix?) {}
                        override fun analyze(image: ImageProxy) {
                            try {
                                val planes = image.planes
                                val frame = Yuv420Frame(planes[0].buffer, planes[1].buffer, planes[2].buffer,
                                    image.width, image.height, planes[0].rowStride, planes[1].rowStride,
                                    planes[2].rowStride, planes[1].pixelStride, YuvColorRange.VIDEO, YuvColorMatrix.BT601,
                                    image.imageInfo.rotationDegrees, front)
                                val result = instance.processFrame(frame)
                                if (result.isFailure) {
                                    val error = result.requireError()
                                    // Readiness and backpressure skip this frame without ending the request.
                                    if (error.code != HiFaceErrorCode.NOT_READY && error.code != HiFaceErrorCode.BUSY) {
                                        runOnUiThread { if (active() && generation == attempt) fail(error.code.name, error.message) }
                                    }
                                }
                            } catch (error: Exception) {
                                runOnUiThread { if (active() && generation == attempt) fail("CAMERA_ERROR", error.message ?: "Unable to process camera frame") }
                            } finally { image.close() }
                        }
                    })
                    cameraProvider.bindToLifecycle(this, selector, display, frames)
                } catch (error: Exception) { fail("CAMERA_ERROR", error.message ?: "Unable to open camera") }
            }, ContextCompat.getMainExecutor(this))
        } catch (error: Exception) { fail("SDK_ERROR", error.message ?: "Unable to start face flow") }
    }

    private fun update(progress: FaceFlowProgress) {
        if (!active() || capturedFeature != null) return
        val action = progress.action?.let { actionName(it) }
        val stage = progress.stage.name
        screen.showProgress(stage, action, progress.stepNumber, progress.stepCount)
        HelloFaceVerifyNative.progress(jobID, JSONObject().put("stage", stage).put("action", action ?: JSONObject.NULL)
            .put("stepNumber", progress.stepNumber).put("stepCount", progress.stepCount))
    }

    private fun confirmCapture(result: FaceCaptureResult) {
        if (!active() || capturedFeature != null) return
        stopAnalysis()
        aligned = result.alignedFace // The SDK creates a Bitmap; read it only once.
        capturedFeature = result.feature
        screen.showConfirmation(aligned, current.params.optString("camera", "front") == "front")
    }
    private fun retake() {
        if (!active() || current.committing || capturedFeature == null) return
        generation++ // Ignore cancellation and queued progress from the completed attempt.
        request?.cancel(); request = null
        stopAnalysis(); sdk?.close(); sdk = null
        screen.clearPhoto(); aligned = null; capturedFeature = null
        screen.showLive(); begin()
    }
    private fun confirm() {
        val feature = capturedFeature ?: return
        if (!active() || current.committing) return
        current.committing = true; screen.showSaving()
        HelloFaceVerifyNative.worker.execute {
            try {
                ReferenceStore(applicationContext).save(current.params.getString("faceID"), feature)
                HelloFaceVerifyNative.finish(jobID, HelloFaceVerifyNative.envelope(data = JSONObject()
                    .put("feature", feature).put("passed", true).put("outcome", "PASSED")))
            } catch (error: Exception) {
                HelloFaceVerifyNative.finish(jobID, HelloFaceVerifyNative.envelope("error", "STORAGE_ERROR", error.message ?: "Unable to save reference"))
            }
        }
    }
    private fun finishResult(data: JSONObject) {
        if (!active()) return
        stopping = true
        HelloFaceVerifyNative.finish(jobID, HelloFaceVerifyNative.envelope(data = data))
    }
    private fun fail(code: String, message: String) {
        if (!active()) return
        if (code == "CANCELLED" && current.committing) return
        stopping = true
        HelloFaceVerifyNative.finish(jobID, HelloFaceVerifyNative.envelope("error", code, message))
    }
    override fun onStop() {
        super.onStop()
        if (!isFinishing && ::current.isInitialized && !current.committing) fail("CANCELLED", "Camera moved to background")
    }
    override fun onDestroy() {
        restoreBrightness()
        shutdownCamera()
        if (::screen.isInitialized) screen.clearPhoto()
        aligned = null; capturedFeature = null
        if (::current.isInitialized && HelloFaceVerifyNative.job?.id == jobID && !current.committing) {
            HelloFaceVerifyNative.finish(jobID, HelloFaceVerifyNative.envelope("error", "CANCELLED", "Camera closed"))
        }
        super.onDestroy()
    }
    private fun stopAnalysis() {
        analysis?.clearAnalyzer()
        val owned = listOfNotNull<UseCase>(displayPreview, analysis)
        if (owned.isNotEmpty()) provider?.unbind(*owned.toTypedArray())
        displayPreview = null; analysis = null
    }
    @PublishedApi internal fun shutdownCamera() {
        stopping = true
        restoreBrightness()
        generation++
        request?.cancel(); request = null
        stopAnalysis()
        sdk?.close(); sdk = null
        analyzer.shutdown()
    }
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
