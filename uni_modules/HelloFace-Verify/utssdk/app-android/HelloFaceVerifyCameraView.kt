package uts.sdk.modules.HelloFaceVerify

import uts.sdk.modules.HelloFaceVerify.HelloFaceVerifyPresentation as UI
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
        contentDescription = UI.photoLabel
        clipToOutline = true
        outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) { outline.setOval(0, 0, view.width, view.height) }
        }
        visibility = GONE
    }
    private val back = button("‹", Color.TRANSPARENT, INK).apply {
        textSize = UI.fontBack; contentDescription = UI.backLabel; setOnClickListener { onCancel() }
    }
    private val heading = label(if (enrollment) UI.enrollHeading else UI.verifyHeading, UI.fontHeading, INK, true)
    private val local = label(UI.localLabel, UI.fontLocal, GREEN).apply { background = rounded(UI.colorLocalFill, UI.pillRadius.toFloat()) }
    private val title = label(UI.preparingTitle, UI.fontTitle, INK, true).apply {
        accessibilityLiveRegion = ACCESSIBILITY_LIVE_REGION_POLITE
    }
    private val detail = label(UI.liveDetail, UI.fontDetail, MUTED)
    private val phase = label(UI.phase(enrollment), UI.fontPhase, BLUE).apply {
        background = rounded(UI.colorPhaseFill, UI.pillRadius.toFloat())
    }
    private val tips = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER
        background = rounded(Color.WHITE, UI.tipsRadius.toFloat())
        listOf(UI.tipCenter, UI.tipLight, UI.tipClear).forEachIndexed { index, text ->
            if (index > 0) addView(View(context).apply { setBackgroundColor(UI.colorDivider) },
                LinearLayout.LayoutParams(dp(UI.borderWidth), dp(UI.dividerHeight)))
            addView(label(text, UI.fontTip, INK), LinearLayout.LayoutParams(0, -1, 1f))
        }
    }
    private val confirmation = label(UI.confirmation, UI.fontConfirmation, MUTED)
    private val retake = button(UI.retake, Color.WHITE, INK).apply {
        background = rounded(Color.WHITE, UI.buttonRadius.toFloat(), UI.colorButtonBorder); setOnClickListener { onRetake() }
    }
    private val confirm = button(UI.confirm, BLUE, Color.WHITE).apply { setOnClickListener { onConfirm() } }
    private val privacy = label(UI.privacy, UI.fontPrivacy, MUTED)
    private val brand = label(UI.brand, UI.fontBrand, UI.colorBrand)
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
        title.text = UI.liveTitle; detail.text = UI.liveDetail
        phase.text = UI.phase(enrollment)
        tips.visibility = VISIBLE
        listOf(confirmation, retake, confirm).forEach { it.visibility = GONE }
        back.isEnabled = true; retake.isEnabled = true; confirm.isEnabled = true
        back.alpha = 1f; retake.alpha = 1f; confirm.alpha = 1f
        confirm.text = UI.confirm; mask.tint = BLUE; requestLayout()
    }

    fun showProgress(stage: String, action: String?, step: Int, count: Int) {
        if (captured) return
        val instruction = UI.guidance(stage, action)
        if (title.text != instruction) title.text = instruction
        val phaseText = UI.phase(enrollment, stage, step, count)
        if (phase.text != phaseText) phase.text = phaseText
        mask.tint = if (UI.isWarning(stage)) AMBER else BLUE
    }

    fun showConfirmation(bitmap: Bitmap?, mirrored: Boolean) {
        captured = true; photo.setImageBitmap(bitmap); photo.scaleX = if (mirrored) -1f else 1f
        photo.visibility = if (bitmap == null) GONE else VISIBLE
        title.text = if (bitmap == null) UI.missingTitle else UI.confirmTitle
        detail.text = if (bitmap == null) UI.missingDetail else UI.confirmDetail
        confirm.isEnabled = bitmap != null
        confirm.alpha = if (bitmap != null) 1f else UI.disabledAlpha
        phase.text = UI.confirmPhase; mask.tint = GREEN
        tips.visibility = GONE
        listOf(confirmation, retake, confirm).forEach { it.visibility = VISIBLE }
        requestLayout()
    }

    fun showSaving() {
        title.text = UI.savingTitle; detail.text = UI.savingDetail
        confirm.text = UI.savingButton; confirm.isEnabled = false; retake.isEnabled = false; back.isEnabled = false
        listOf(back, retake, confirm).forEach { it.alpha = UI.disabledAlpha }
    }

    fun clearPhoto() { photo.setImageDrawable(null) }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val w = right - left; val h = bottom - top
        preview.layout(0, 0, w, h); mask.layout(0, 0, w, h)
        val contentLeft = safeLeft + dp(UI.sideInset); val contentRight = w - safeRight - dp(UI.sideInset)
        val width = contentRight - contentLeft; val center = (contentLeft + contentRight) / 2
        val headerY = safeTop + dp(UI.headerInset)
        place(back, safeLeft + dp(UI.backInset), headerY, dp(UI.backSize), dp(UI.backSize))
        place(heading, center - dp(UI.headingWidth) / 2, headerY, dp(UI.headingWidth), dp(UI.backSize))
        place(local, contentRight - dp(UI.localWidth), headerY + dp(UI.localOffset), dp(UI.localWidth), dp(UI.localHeight))
        val compact = h - safeTop - safeBottom < dp(UI.compactHeight)
        val titleY = headerY + dp(if (compact) UI.compactTitleOffset else UI.titleOffset)
        place(title, contentLeft, titleY, width, dp(UI.titleHeight))
        place(detail, contentLeft, titleY + dp(UI.detailOffset), width, dp(UI.detailHeight))
        val circleTop = titleY + dp(UI.circleOffset)
        val footerReserve = dp(if (captured) UI.captureReserve else UI.liveReserve)
        val diameter = min(min(width.toFloat(), (w - safeLeft - safeRight) * UI.circleRatio),
            (h - safeBottom - footerReserve - circleTop).toFloat()).coerceAtLeast(dp(UI.minCircle).toFloat()).toInt()
        val circleLeft = center - diameter / 2
        place(photo, circleLeft, circleTop, diameter, diameter)
        mask.setCircle(RectF(circleLeft.toFloat(), circleTop.toFloat(), (circleLeft + diameter).toFloat(),
            (circleTop + diameter).toFloat()))
        val phaseY = circleTop + diameter + dp(UI.phaseOffset)
        val phaseWidth = min(width, dp(UI.phaseWidth))
        place(phase, center - phaseWidth / 2, phaseY, phaseWidth, dp(UI.phaseHeight))
        val privacyY = h - safeBottom - dp(UI.footerInset)
        place(privacy, contentLeft, privacyY, width, dp(UI.privacyHeight)); place(brand, contentLeft, privacyY + dp(UI.brandOffset), width, dp(UI.brandHeight))
        if (captured) {
            val buttonY = privacyY - dp(UI.buttonOffset)
            place(confirmation, contentLeft, buttonY - dp(UI.confirmationOffset), width, dp(UI.confirmationHeight))
            val buttonWidth = (width - dp(UI.buttonGap)) / 2
            place(retake, contentLeft, buttonY, buttonWidth, dp(UI.buttonHeight))
            place(confirm, contentLeft + buttonWidth + dp(UI.buttonGap), buttonY, buttonWidth, dp(UI.buttonHeight))
        } else place(tips, contentLeft, phaseY + dp(UI.tipsOffset), width, dp(UI.tipsHeight))
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
        text = value; textSize = UI.fontButton; isAllCaps = false; setTextColor(color)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        background = rounded(fill, UI.buttonRadius.toFloat()); setPadding(0, 0, 0, 0); minimumWidth = 0; minimumHeight = 0
        stateListAnimator = null
    }
    private fun rounded(fill: Int, radius: Float, stroke: Int? = null) = GradientDrawable().apply {
        setColor(fill); cornerRadius = dp(radius).toFloat(); if (stroke != null) setStroke(dp(UI.borderWidth), stroke)
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
            paint.style = Paint.Style.STROKE; paint.strokeWidth = resources.displayMetrics.density * UI.ringWidth
            paint.color = tint; canvas.drawOval(hole, paint)
            val outer = RectF(hole); outer.inset(-resources.displayMetrics.density * UI.outerRingGap, -resources.displayMetrics.density * UI.outerRingGap)
            paint.strokeWidth = resources.displayMetrics.density; paint.color = UI.colorOuterRing; canvas.drawOval(outer, paint)
        }
    }

    companion object {
        const val BACKGROUND = UI.colorBackground
        private const val INK = UI.colorInk
        private const val MUTED = UI.colorMuted
        private const val BLUE = UI.colorBlue
        private const val GREEN = UI.colorGreen
        private const val AMBER = UI.colorAmber
    }
}
