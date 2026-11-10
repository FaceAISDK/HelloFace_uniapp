package uts.sdk.modules.HelloFaceVerify

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.camera.view.PreviewView
import kotlin.math.min

/** Presentation only: the circular opening never crops frames submitted to the SDK. */
internal class HelloFaceVerifyCameraView(context: Context, private val enrollment: Boolean,
    onCancel: () -> Unit, onRetake: () -> Unit, onConfirm: () -> Unit) : FrameLayout(context) {
    val preview = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FIT_CENTER
        setBackgroundColor(BACKGROUND)
    }
    private val mask = CameraMask(context)
    private val photo = ImageView(context).apply {
        scaleType = ImageView.ScaleType.FIT_CENTER
        setBackgroundColor(BACKGROUND)
        contentDescription = "已采集的人脸照片"
        clipToOutline = true
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) { outline.setOval(0, 0, view.width, view.height) }
        }
        visibility = GONE
    }
    private val back = button("‹", Color.TRANSPARENT, INK).apply {
        textSize = 32f; contentDescription = "返回"; setOnClickListener { onCancel() }
    }
    private val heading = label(if (enrollment) "人脸录入" else "身份验证", 17f, INK, true)
    private val local = label("● 本机处理", 11f, GREEN).apply { background = rounded(0xffe8f4ef.toInt(), 14f) }
    private val title = label("正在准备相机", 25f, INK, true).apply {
        accessibilityLiveRegion = ACCESSIBILITY_LIVE_REGION_POLITE
    }
    private val detail = label("请将面部置于圆框内，保持光线均匀", 13f, MUTED)
    private val phase = label(if (enrollment) "第一步 · 人脸采集" else "实时身份核验", 12f, BLUE).apply {
        background = rounded(0xffeaf1fd.toInt(), 13f)
    }
    private val tips = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER
        background = rounded(Color.WHITE, 18f)
        listOf("人脸居中", "光线均匀", "面部无遮挡").forEachIndexed { index, text ->
            if (index > 0) addView(View(context).apply { setBackgroundColor(0xffe5ebf3.toInt()) },
                LinearLayout.LayoutParams(dp(1), dp(20)))
            addView(label(text, 12f, INK), LinearLayout.LayoutParams(0, -1, 1f))
        }
    }
    private val confirmation = label("确认后将加密保存人脸特征，不保存照片", 13f, MUTED)
    private val retake = button("重新采集", Color.WHITE, INK).apply {
        background = rounded(Color.WHITE, 14f, 0xffdce5f1.toInt()); setOnClickListener { onRetake() }
    }
    private val confirm = button("确认录入", BLUE, Color.WHITE).apply { setOnClickListener { onConfirm() } }
    private val privacy = label("人脸处理在本机完成", 12f, MUTED)
    private val brand = label("HelloFaceVerify", 11f, 0xffa0adbd.toInt())
    private var safeLeft = 0
    private var safeTop = 0
    private var safeRight = 0
    private var safeBottom = 0
    private var captured = false

    init {
        setBackgroundColor(BACKGROUND)
        addView(preview); addView(photo); addView(mask)
        listOf(back, heading, local, title, detail, phase, tips, confirmation, retake, confirm, privacy, brand)
            .forEach { addView(it) }
        showLive()
    }

    fun setSafeInsets(left: Int, top: Int, right: Int, bottom: Int) {
        if (safeLeft == left && safeTop == top && safeRight == right && safeBottom == bottom) return
        safeLeft = left; safeTop = top; safeRight = right; safeBottom = bottom; requestLayout()
    }

    fun showLive() {
        captured = false; photo.setImageDrawable(null); photo.visibility = GONE
        title.text = "请正对镜头"; detail.text = "请将面部置于圆框内，保持光线均匀"
        phase.text = if (enrollment) "第一步 · 人脸采集" else "实时身份核验"
        tips.visibility = VISIBLE
        listOf(confirmation, retake, confirm).forEach { it.visibility = GONE }
        back.isEnabled = true; retake.isEnabled = true; confirm.isEnabled = true
        back.alpha = 1f; retake.alpha = 1f; confirm.alpha = 1f
        confirm.text = "确认录入"; mask.tint = BLUE; requestLayout()
    }

    fun showProgress(stage: String, action: String?, step: Int, count: Int) {
        if (captured) return
        val instruction = if (stage == "PERFORM_ACTION") when (action) {
            "blink" -> "请眨眨眼"; "openMouth" -> "请张张嘴"
            "shakeHead" -> "请左右摇头"; "nodHead" -> "请缓慢点头"; else -> "请按提示完成动作"
        } else when (stage) {
            "MULTIPLE_FACES" -> "请保持画面中只有一人"
            "FACE_TOO_SMALL" -> "请靠近一些"
            "HOLD_STILL", "FACE_UNSTABLE" -> "请保持面部稳定"
            else -> "请正对镜头"
        }
        if (title.text != instruction) title.text = instruction
        val phaseText = if (stage == "PERFORM_ACTION" && count > 0) "动作验证 · $step/$count"
            else if (enrollment) "第一步 · 人脸采集" else "实时身份核验"
        if (phase.text != phaseText) phase.text = phaseText
        mask.tint = if (stage in listOf("MULTIPLE_FACES", "FACE_TOO_SMALL", "FACE_NOT_FRONTAL")) AMBER else BLUE
    }

    fun showConfirmation(bitmap: Bitmap?, mirrored: Boolean) {
        captured = true; photo.setImageBitmap(bitmap); photo.scaleX = if (mirrored) -1f else 1f
        photo.visibility = if (bitmap == null) GONE else VISIBLE
        title.text = if (bitmap == null) "未能生成预览" else "请确认人脸照片"
        detail.text = if (bitmap == null) "请重新采集后再确认" else "照片清晰且为本人，即可确认录入"
        confirm.isEnabled = bitmap != null
        phase.text = "第二步 · 确认保存"; mask.tint = GREEN
        tips.visibility = GONE
        listOf(confirmation, retake, confirm).forEach { it.visibility = VISIBLE }
        requestLayout()
    }

    fun showSaving() {
        title.text = "正在保存人脸基准"; detail.text = "即将完成，请稍候"
        confirm.text = "正在保存…"; confirm.isEnabled = false; retake.isEnabled = false; back.isEnabled = false
        confirm.alpha = .65f; retake.alpha = .5f; back.alpha = .5f
    }

    fun clearPhoto() { photo.setImageDrawable(null) }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val w = right - left; val h = bottom - top
        preview.layout(0, 0, w, h); mask.layout(0, 0, w, h)
        val contentLeft = safeLeft + dp(24); val contentRight = w - safeRight - dp(24)
        val width = contentRight - contentLeft; val center = (contentLeft + contentRight) / 2
        val headerY = safeTop + dp(8)
        place(back, safeLeft + dp(12), headerY, dp(44), dp(44))
        place(heading, center - dp(48), headerY, dp(96), dp(44))
        place(local, contentRight - dp(76), headerY + dp(10), dp(76), dp(25))
        val compact = h - safeTop - safeBottom < dp(600)
        val titleY = headerY + dp(if (compact) 55 else 70)
        place(title, contentLeft, titleY, width, dp(54))
        place(detail, contentLeft, titleY + dp(56), width, dp(34))
        val circleTop = titleY + dp(104)
        val footerReserve = dp(if (captured) 206 else 168)
        val diameter = min(min(width.toFloat(), (w - safeLeft - safeRight) * .80f),
            (h - safeBottom - footerReserve - circleTop).toFloat()).coerceAtLeast(dp(100).toFloat()).toInt()
        val circleLeft = center - diameter / 2
        place(photo, circleLeft, circleTop, diameter, diameter)
        mask.setCircle(RectF(circleLeft.toFloat(), circleTop.toFloat(), (circleLeft + diameter).toFloat(),
            (circleTop + diameter).toFloat()))
        val phaseY = circleTop + diameter + dp(16)
        val phaseWidth = min(width, dp(176))
        place(phase, center - phaseWidth / 2, phaseY, phaseWidth, dp(26))
        val privacyY = h - safeBottom - dp(49)
        place(privacy, contentLeft, privacyY, width, dp(20)); place(brand, contentLeft, privacyY + dp(22), width, dp(16))
        if (captured) {
            val buttonY = privacyY - dp(64)
            place(confirmation, contentLeft, buttonY - dp(42), width, dp(36))
            val buttonWidth = (width - dp(12)) / 2
            place(retake, contentLeft, buttonY, buttonWidth, dp(50))
            place(confirm, contentLeft + buttonWidth + dp(12), buttonY, buttonWidth, dp(50))
        } else place(tips, contentLeft, phaseY + dp(39), width, dp(48))
    }

    private fun place(view: View, x: Int, y: Int, w: Int, h: Int) {
        view.measure(MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY))
        view.layout(x, y, x + w, y + h)
    }
    private fun label(value: String, size: Float, color: Int, bold: Boolean = false) = TextView(context).apply {
        text = value; textSize = size; setTextColor(color); gravity = Gravity.CENTER; maxLines = 2
        if (bold) typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        includeFontPadding = false
    }
    private fun button(value: String, fill: Int, color: Int) = Button(context).apply {
        text = value; textSize = 15f; isAllCaps = false; setTextColor(color)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        background = rounded(fill, 14f); setPadding(0, 0, 0, 0); minimumWidth = 0; minimumHeight = 0
        stateListAnimator = null
    }
    private fun rounded(fill: Int, radius: Float, stroke: Int? = null) = GradientDrawable().apply {
        setColor(fill); cornerRadius = dp(radius).toFloat(); if (stroke != null) setStroke(dp(1), stroke)
    }
    private fun dp(value: Int) = dp(value.toFloat())
    private fun dp(value: Float) = (value * resources.displayMetrics.density + .5f).toInt()

    private class CameraMask(context: Context) : View(context) {
        private val hole = RectF()
        private val path = Path()
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        var tint = BLUE
            set(value) { if (field != value) { field = value; invalidate() } }
        fun setCircle(value: RectF) { if (hole != value) { hole.set(value); invalidate() } }
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            path.reset(); path.fillType = Path.FillType.EVEN_ODD
            path.addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW)
            path.addOval(hole, Path.Direction.CW)
            paint.style = Paint.Style.FILL; paint.color = BACKGROUND; canvas.drawPath(path, paint)
            paint.style = Paint.Style.STROKE; paint.strokeWidth = resources.displayMetrics.density * 3
            paint.color = tint; canvas.drawOval(hole, paint)
            val outer = RectF(hole); outer.inset(-resources.displayMetrics.density * 7, -resources.displayMetrics.density * 7)
            paint.strokeWidth = resources.displayMetrics.density; paint.color = 0xffdce6f4.toInt(); canvas.drawOval(outer, paint)
        }
    }

    companion object {
        const val BACKGROUND = -0x80604 // #F7F9FC
        private val INK = 0xff19324f.toInt()
        private val MUTED = 0xff60738b.toInt()
        private val BLUE = 0xff2878ef.toInt()
        private val GREEN = 0xff28866c.toInt()
        private val AMBER = 0xffc58a27.toInt()
    }
}
