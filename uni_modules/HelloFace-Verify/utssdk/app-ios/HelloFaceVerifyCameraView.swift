import UIKit

private typealias UI = HelloFaceVerifyPresentation

/// Native presentation only. The mask does not change camera pixels or SDK coordinates.
final class HelloFaceVerifyCameraView: UIView {
    static let background = UI.colorBackground
    private let ink = UI.colorInk
    private let muted = UI.colorMuted
    private let blue = UI.colorBlue
    private let green = UI.colorGreen
    private let enrollment: Bool
    private let liveness: Bool
    private let cutoutMask = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let progressRing = CAShapeLayer()
    private let photo = UIImageView()
    private let confirmationOverlay = UIView()
    private let confirmationCard = UIView()
    private let confirmationBody = UIScrollView()
    private let confirmationContent = UIView()
    private let dialogTitle = UILabel()
    private let dialogDetail = UILabel()
    private let closeConfirmation = UIButton(type: .system)
    private let back = UIButton(type: .system)
    private let backArrow = CAShapeLayer()
    private let heading = UILabel()
    private let title = UILabel()
    private let detail = UILabel()
    private let phase = UILabel()
    private let tips = UIStackView()
    private let confirmation = UILabel()
    private let retake = UIButton(type: .system)
    private let confirm = UIButton(type: .system)
    private var captured = false
    private var captureProgress = HelloFaceVerifyCaptureProgress()
    var onCancel: (() -> Void)?
    var onRetake: (() -> Void)?
    var onConfirm: (() -> Void)?

    init(enrollment: Bool, liveness: Bool = false) {
        self.enrollment = enrollment; self.liveness = liveness
        super.init(frame: .zero)
        backgroundColor = Self.background
        photo.contentMode = .scaleAspectFit; photo.clipsToBounds = true
        photo.backgroundColor = Self.background
        photo.accessibilityLabel = UI.photoLabel; photo.isAccessibilityElement = true
        cutoutMask.fillColor = Self.background.cgColor; cutoutMask.fillRule = .evenOdd
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = blue.cgColor; ring.lineWidth = UI.ringWidth
        progressRing.fillColor = UIColor.clear.cgColor; progressRing.strokeColor = blue.cgColor
        progressRing.lineWidth = UI.ringWidth + 1; progressRing.lineCap = .round; progressRing.strokeEnd = 0
        [cutoutMask, ring, progressRing].forEach { layer.addSublayer($0) }
        backArrow.fillColor = UIColor.clear.cgColor; backArrow.strokeColor = ink.cgColor
        backArrow.lineWidth = UI.backIconStroke; backArrow.lineCap = .round; backArrow.lineJoin = .round
        back.layer.addSublayer(backArrow); back.accessibilityLabel = UI.backLabel
        back.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        style(heading, text: enrollment ? UI.enrollHeading : (liveness ? UI.livenessHeading : UI.verifyHeading), size: UI.fontHeading, color: ink, weight: .medium)
        heading.textAlignment = .left
        heading.numberOfLines = 1; heading.lineBreakMode = .byTruncatingTail
        style(title, text: UI.preparingTitle, size: UI.fontTitle, color: ink, weight: .medium)
        title.accessibilityTraits.insert(.updatesFrequently)
        style(detail, text: UI.liveDetail, size: UI.fontDetail, color: muted)
        style(phase, text: "", size: UI.fontPhase, color: blue)
        phase.backgroundColor = UI.colorPhaseFill
        phase.layer.cornerRadius = UI.pillRadius; phase.clipsToBounds = true
        tips.axis = .horizontal; tips.distribution = .fill
        tips.backgroundColor = .white; tips.layer.cornerRadius = UI.tipsRadius
        var previousTip: UILabel?
        for text in [UI.tipCenter, UI.tipLight, UI.tipClear] {
            if previousTip != nil {
                let separator = UIView(); separator.backgroundColor = UI.colorDivider
                let slot = UIView(); slot.addSubview(separator)
                separator.translatesAutoresizingMaskIntoConstraints = false
                slot.widthAnchor.constraint(equalToConstant: UI.borderWidth).isActive = true
                NSLayoutConstraint.activate([separator.centerYAnchor.constraint(equalTo: slot.centerYAnchor),
                    separator.widthAnchor.constraint(equalTo: slot.widthAnchor),
                    separator.heightAnchor.constraint(equalToConstant: UI.dividerHeight)])
                tips.addArrangedSubview(slot)
            }
            let label = UILabel(); style(label, text: text, size: UI.fontTip, color: ink)
            tips.addArrangedSubview(label)
            if let previous = previousTip { label.widthAnchor.constraint(equalTo: previous.widthAnchor).isActive = true }
            previousTip = label
        }
        style(confirmation, text: UI.confirmation, size: UI.fontConfirmation, color: muted)
        style(retake, text: UI.retake, fill: .white, color: ink)
        retake.layer.borderColor = UI.colorButtonBorder.cgColor
        retake.layer.borderWidth = UI.borderWidth
        retake.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        style(confirm, text: UI.confirm, fill: blue, color: .white)
        confirm.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        [back, heading, title, detail, phase, tips]
            .forEach { addSubview($0) }
        confirmationOverlay.backgroundColor = UIColor.black.withAlphaComponent(UI.dialogScrimAlpha)
        confirmationOverlay.accessibilityViewIsModal = true
        confirmationCard.backgroundColor = .white
        confirmationCard.layer.cornerRadius = UI.dialogRadius; confirmationCard.clipsToBounds = true
        style(dialogTitle, text: UI.confirmTitle, size: UI.fontDialogHeading, color: ink, weight: .medium)
        dialogTitle.textAlignment = .left
        style(dialogDetail, text: UI.confirmDetail, size: UI.fontDetail, color: muted)
        closeConfirmation.setTitle("×", for: .normal); closeConfirmation.setTitleColor(ink, for: .normal)
        closeConfirmation.titleLabel?.font = .systemFont(ofSize: UI.fontDialogClose)
        closeConfirmation.accessibilityLabel = UI.cancelCapture
        closeConfirmation.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        [photo, dialogDetail, confirmation].forEach { confirmationContent.addSubview($0) }
        confirmationBody.addSubview(confirmationContent)
        [dialogTitle, closeConfirmation, confirmationBody, retake, confirm].forEach { confirmationCard.addSubview($0) }
        confirmationOverlay.addSubview(confirmationCard)
        addSubview(confirmationOverlay)
        showLive()
    }
    required init?(coder: NSCoder) { fatalError("Use init(enrollment:)") }

    func showLive() {
        resetCaptureProgress()
        captured = false; photo.image = nil; photo.isHidden = true
        confirmationOverlay.isHidden = true
        title.text = UI.liveTitle; detail.text = UI.liveDetail
        phase.text = liveness ? UI.livenessPhase : UI.phase(enrollment: enrollment)
        tips.isHidden = false
        [confirmation, retake, confirm].forEach { $0.isHidden = true }
        [back, retake, confirm, closeConfirmation].forEach { $0.isEnabled = true; $0.alpha = 1 }
        confirm.setTitle(UI.confirm, for: .normal)
        ring.strokeColor = (enrollment ? UI.colorOuterRing : blue).cgColor; setNeedsLayout()
    }

    func showProgress(stage: String, action: String?, step: Int, count: Int) {
        guard !captured else { return }
        let guidance = UI.guidance(stage: stage, action: action)
        if title.text != guidance { title.text = guidance }
        let phaseText = liveness && stage != "PERFORM_ACTION" ? UI.livenessPhase : UI.phase(enrollment: enrollment, stage: stage, step: step, count: count)
        if phase.text != phaseText { phase.text = phaseText }
        updateCaptureProgress(stage: stage)
        let color = (UI.isWarning(stage: stage) ? UI.colorAmber : (enrollment ? UI.colorOuterRing : blue)).cgColor
        if ring.strokeColor != color {
            CATransaction.begin(); CATransaction.setDisableActions(true); ring.strokeColor = color; CATransaction.commit()
        }
    }

    func showConfirmation(image: UIImage?, mirrored: Bool) {
        resetCaptureProgress()
        captured = true; photo.image = image; photo.isHidden = image == nil
        ring.strokeColor = green.cgColor
        photo.transform = CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1)
        dialogTitle.text = image == nil ? UI.missingTitle : UI.confirmTitle
        dialogDetail.text = image == nil ? UI.missingDetail : UI.confirmDetail
        title.text = dialogTitle.text; detail.text = dialogDetail.text; phase.text = UI.confirmPhase
        tips.isHidden = true
        [back, retake, closeConfirmation].forEach { $0.isEnabled = true; $0.alpha = 1 }
        confirm.setTitle(UI.confirm, for: .normal)
        confirm.isEnabled = image != nil
        confirm.alpha = image != nil ? 1 : UI.disabledAlpha
        confirmationOverlay.isHidden = false
        confirmationBody.setContentOffset(.zero, animated: false)
        [confirmation, retake, confirm].forEach { $0.isHidden = false }
        setNeedsLayout()
        UIAccessibility.post(notification: .screenChanged, argument: dialogTitle)
    }

    func showSaving() {
        dialogTitle.text = UI.savingTitle; dialogDetail.text = UI.savingDetail
        title.text = UI.savingTitle; detail.text = UI.savingDetail
        confirm.setTitle(UI.savingButton, for: .normal)
        [back, retake, confirm, closeConfirmation].forEach { $0.isEnabled = false; $0.alpha = UI.disabledAlpha }
        setNeedsLayout()
    }
    func clearPhoto() { resetCaptureProgress(); photo.image = nil; confirmationOverlay.isHidden = true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { resetCaptureProgress() }
    }
    private func updateCaptureProgress(stage: String) {
        let start = captureProgress.update(enrollment: enrollment, stage: stage)
        guard captureProgress.holding else { resetCaptureProgress(); return }
        guard start else { return }
        // 同一 HOLD_STILL 阶段只启动一次；动画走满仍等待 SDK 的真实结果。
        CATransaction.begin(); CATransaction.setDisableActions(true)
        progressRing.strokeEnd = 1
        CATransaction.commit()
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0; animation.toValue = 1
        animation.duration = HelloFaceVerifyCaptureProgress.duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        progressRing.add(animation, forKey: "captureHold")
    }
    private func resetCaptureProgress() {
        captureProgress.reset()
        progressRing.removeAnimation(forKey: "captureHold")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        progressRing.strokeEnd = 0
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets, w = bounds.width, h = bounds.height
        let left = safe.left + UI.sideInset, right = w - safe.right - UI.sideInset, width = right - left, center = (left + right) / 2
        let headerY = safe.top + UI.headerInset
        back.frame = CGRect(x: safe.left + UI.backInset, y: headerY, width: UI.backSize, height: UI.backSize)
        // 用图形的中心代替字体基线，保持返回箭头与标题的视觉中心一致。
        let arrow = UIBezierPath(), x = back.bounds.midX, y = back.bounds.midY
        arrow.move(to: CGPoint(x: x + UI.backIconWidth / 2, y: y - UI.backIconHeight / 2))
        arrow.addLine(to: CGPoint(x: x - UI.backIconWidth / 2, y: y))
        arrow.addLine(to: CGPoint(x: x + UI.backIconWidth / 2, y: y + UI.backIconHeight / 2))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        backArrow.frame = back.bounds; backArrow.path = arrow.cgPath
        CATransaction.commit()
        let headingLeft = safe.left + UI.backInset + UI.backSize + UI.headingGap
        heading.frame = CGRect(x: headingLeft, y: headerY, width: max(0, right - headingLeft), height: UI.backSize)
        let titleY = headerY + (h - safe.top - safe.bottom < UI.compactHeight ? UI.compactTitleOffset : UI.titleOffset)
        title.frame = CGRect(x: left, y: titleY, width: width, height: UI.titleHeight)
        detail.frame = CGRect(x: left, y: titleY + UI.detailOffset, width: width, height: UI.detailHeight)
        let circleTop = titleY + UI.circleOffset
        let diameter = max(UI.minCircle, min(width, (w - safe.left - safe.right) * UI.circleRatio,
                                    h - safe.bottom - UI.liveReserve - circleTop))
        // 与原灰色外圈重合；开孔、状态圈及进度弧共享扩大后的路径。
        let circle = CGRect(x: center - diameter / 2, y: circleTop, width: diameter, height: diameter)
            .insetBy(dx: -UI.circleExpansion, dy: -UI.circleExpansion)
        let cutout = UIBezierPath(rect: bounds); cutout.append(UIBezierPath(ovalIn: circle))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        cutoutMask.frame = bounds; cutoutMask.path = cutout.cgPath
        ring.frame = bounds; ring.path = UIBezierPath(ovalIn: circle).cgPath
        progressRing.frame = bounds
        progressRing.path = UIBezierPath(arcCenter: CGPoint(x: circle.midX, y: circle.midY), radius: circle.width / 2,
            startAngle: -.pi / 2, endAngle: .pi * 3 / 2, clockwise: true).cgPath
        CATransaction.commit()
        let phaseY = circle.maxY + UI.phaseOffset, phaseWidth = min(width, UI.phaseWidth)
        phase.frame = CGRect(x: center - phaseWidth / 2, y: phaseY, width: phaseWidth, height: UI.phaseHeight)
        tips.frame = CGRect(x: left, y: phaseY + UI.tipsOffset, width: width, height: UI.tipsHeight)
        layoutConfirmation()
    }

    private func layoutConfirmation() {
        confirmationOverlay.frame = bounds
        let safe = safeAreaInsets, padding = UI.dialogPadding
        let width = max(0, min(UI.dialogMaxWidth, bounds.width - safe.left - safe.right - UI.dialogInset * 2))
        let contentWidth = max(1, width - padding * 2)
        let side = photo.image == nil ? 0 : min(UI.dialogPhotoSide, contentWidth)
        dialogTitle.frame = CGRect(x: padding, y: padding, width: contentWidth - UI.dialogCloseSize, height: UI.dialogHeadingHeight)
        closeConfirmation.frame = CGRect(x: width - padding - UI.dialogCloseSize, y: padding, width: UI.dialogCloseSize, height: UI.dialogHeadingHeight)
        var y: CGFloat = 0
        if side > 0 {
            photo.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            photo.center = CGPoint(x: contentWidth / 2, y: y + side / 2)
            photo.layer.cornerRadius = UI.dialogPhotoRadius
            y += side + UI.dialogGap
        }
        for label in [dialogDetail, confirmation] {
            if label === confirmation { y += UI.dialogTextGap }
            let height = max(label === dialogDetail ? UI.detailHeight : UI.confirmationHeight,
                ceil(label.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude)).height))
            label.frame = CGRect(x: 0, y: y, width: contentWidth, height: height)
            y += height
        }
        let contentHeight = y
        let availableHeight = max(1, bounds.height - safe.top - safe.bottom - UI.dialogInset * 2)
        let fixedHeight = padding * 2 + UI.dialogHeadingHeight + UI.dialogGap * 2 + UI.buttonHeight
        let bodyHeight = min(contentHeight, max(1, availableHeight - fixedHeight))
        let height = fixedHeight + bodyHeight
        confirmationCard.frame = CGRect(x: safe.left + (bounds.width - safe.left - safe.right - width) / 2,
            y: safe.top + (bounds.height - safe.top - safe.bottom - height) / 2, width: width, height: height)
        // 固定标题和操作栏，仅滚动图片与说明，避免小屏上操作按钮被挤走。
        confirmationBody.frame = CGRect(x: padding, y: padding + UI.dialogHeadingHeight + UI.dialogGap,
            width: contentWidth, height: bodyHeight)
        confirmationContent.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        confirmationBody.contentSize = CGSize(width: contentWidth, height: contentHeight)
        let buttonWidth = (contentWidth - UI.buttonGap) / 2, buttonY = height - padding - UI.buttonHeight
        retake.frame = CGRect(x: padding, y: buttonY, width: buttonWidth, height: UI.buttonHeight)
        confirm.frame = CGRect(x: padding + buttonWidth + UI.buttonGap, y: buttonY, width: buttonWidth, height: UI.buttonHeight)
    }

    private func style(_ label: UILabel, text: String, size: CGFloat, color: UIColor, weight: UIFont.Weight = .regular) {
        label.text = text; label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.adjustsFontForContentSizeCategory = true; label.textColor = color; label.textAlignment = .center
        label.numberOfLines = 2; label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.75
    }
    private func style(_ button: UIButton, text: String, fill: UIColor, color: UIColor) {
        button.setTitle(text, for: .normal); button.setTitleColor(color, for: .normal)
        button.backgroundColor = fill; button.layer.cornerRadius = UI.buttonRadius
        button.titleLabel?.font = .systemFont(ofSize: UI.fontButton, weight: .medium)
    }
    @objc private func cancelTapped() { onCancel?() }
    @objc private func retakeTapped() { onRetake?() }
    @objc private func confirmTapped() { onConfirm?() }
}
