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
    private let cutoutMask = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let outerRing = CAShapeLayer()
    private let photo = UIImageView()
    private let back = UIButton(type: .system)
    private let heading = UILabel()
    private let local = UILabel()
    private let title = UILabel()
    private let detail = UILabel()
    private let phase = UILabel()
    private let tips = UIStackView()
    private let confirmation = UILabel()
    private let retake = UIButton(type: .system)
    private let confirm = UIButton(type: .system)
    private let privacy = UILabel()
    private let brand = UILabel()
    private var captured = false
    var onCancel: (() -> Void)?
    var onRetake: (() -> Void)?
    var onConfirm: (() -> Void)?

    init(enrollment: Bool) {
        self.enrollment = enrollment
        super.init(frame: .zero)
        backgroundColor = Self.background
        photo.contentMode = .scaleAspectFit; photo.clipsToBounds = true
        photo.backgroundColor = Self.background
        photo.accessibilityLabel = UI.photoLabel; photo.isAccessibilityElement = true
        addSubview(photo)
        cutoutMask.fillColor = Self.background.cgColor; cutoutMask.fillRule = .evenOdd
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = blue.cgColor; ring.lineWidth = UI.ringWidth
        outerRing.fillColor = UIColor.clear.cgColor
        outerRing.strokeColor = UI.colorOuterRing.cgColor
        outerRing.lineWidth = UI.borderWidth
        [cutoutMask, outerRing, ring].forEach { layer.addSublayer($0) }
        back.setTitle("‹", for: .normal)
        back.titleLabel?.font = .systemFont(ofSize: UI.fontBack)
        back.setTitleColor(ink, for: .normal); back.accessibilityLabel = UI.backLabel
        back.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        style(heading, text: enrollment ? UI.enrollHeading : UI.verifyHeading, size: UI.fontHeading, color: ink, weight: .medium)
        style(local, text: UI.localLabel, size: UI.fontLocal, color: green)
        local.backgroundColor = UI.colorLocalFill
        local.layer.cornerRadius = UI.pillRadius; local.clipsToBounds = true
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
        style(privacy, text: UI.privacy, size: UI.fontPrivacy, color: muted)
        style(brand, text: UI.brand, size: UI.fontBrand, color: UI.colorBrand)
        [back, heading, local, title, detail, phase, tips, confirmation, retake, confirm, privacy, brand]
            .forEach { addSubview($0) }
        showLive()
    }
    required init?(coder: NSCoder) { fatalError("Use init(enrollment:)") }

    func showLive() {
        captured = false; photo.image = nil; photo.isHidden = true
        title.text = UI.liveTitle; detail.text = UI.liveDetail
        phase.text = UI.phase(enrollment: enrollment)
        tips.isHidden = false
        [confirmation, retake, confirm].forEach { $0.isHidden = true }
        [back, retake, confirm].forEach { $0.isEnabled = true; $0.alpha = 1 }
        confirm.setTitle(UI.confirm, for: .normal); ring.strokeColor = blue.cgColor; setNeedsLayout()
    }

    func showProgress(stage: String, action: String?, step: Int, count: Int) {
        guard !captured else { return }
        let guidance = UI.guidance(stage: stage, action: action)
        if title.text != guidance { title.text = guidance }
        let phaseText = UI.phase(enrollment: enrollment, stage: stage, step: step, count: count)
        if phase.text != phaseText { phase.text = phaseText }
        let color = (UI.isWarning(stage: stage) ? UI.colorAmber : blue).cgColor
        if ring.strokeColor != color {
            CATransaction.begin(); CATransaction.setDisableActions(true); ring.strokeColor = color; CATransaction.commit()
        }
    }

    func showConfirmation(image: UIImage?, mirrored: Bool) {
        captured = true; photo.image = image; photo.isHidden = image == nil
        photo.transform = CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1)
        title.text = image == nil ? UI.missingTitle : UI.confirmTitle
        detail.text = image == nil ? UI.missingDetail : UI.confirmDetail
        confirm.isEnabled = image != nil
        confirm.alpha = image != nil ? 1 : UI.disabledAlpha
        phase.text = UI.confirmPhase; ring.strokeColor = green.cgColor
        tips.isHidden = true
        [confirmation, retake, confirm].forEach { $0.isHidden = false }
        setNeedsLayout()
    }

    func showSaving() {
        title.text = UI.savingTitle; detail.text = UI.savingDetail
        confirm.setTitle(UI.savingButton, for: .normal)
        [back, retake, confirm].forEach { $0.isEnabled = false; $0.alpha = UI.disabledAlpha }
    }
    func clearPhoto() { photo.image = nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets, w = bounds.width, h = bounds.height
        let left = safe.left + UI.sideInset, right = w - safe.right - UI.sideInset, width = right - left, center = (left + right) / 2
        let headerY = safe.top + UI.headerInset
        back.frame = CGRect(x: safe.left + UI.backInset, y: headerY, width: UI.backSize, height: UI.backSize)
        heading.frame = CGRect(x: center - UI.headingWidth / 2, y: headerY, width: UI.headingWidth, height: UI.backSize)
        local.frame = CGRect(x: right - UI.localWidth, y: headerY + UI.localOffset, width: UI.localWidth, height: UI.localHeight)
        let titleY = headerY + (h - safe.top - safe.bottom < UI.compactHeight ? UI.compactTitleOffset : UI.titleOffset)
        title.frame = CGRect(x: left, y: titleY, width: width, height: UI.titleHeight)
        detail.frame = CGRect(x: left, y: titleY + UI.detailOffset, width: width, height: UI.detailHeight)
        let circleTop = titleY + UI.circleOffset
        let diameter = max(UI.minCircle, min(width, (w - safe.left - safe.right) * UI.circleRatio,
                                    h - safe.bottom - (captured ? UI.captureReserve : UI.liveReserve) - circleTop))
        let circle = CGRect(x: center - diameter / 2, y: circleTop, width: diameter, height: diameter)
        photo.bounds = CGRect(origin: .zero, size: circle.size); photo.center = CGPoint(x: circle.midX, y: circle.midY)
        photo.layer.cornerRadius = diameter / 2
        let cutout = UIBezierPath(rect: bounds); cutout.append(UIBezierPath(ovalIn: circle))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        cutoutMask.frame = bounds; cutoutMask.path = cutout.cgPath
        ring.frame = bounds; ring.path = UIBezierPath(ovalIn: circle).cgPath
        outerRing.frame = bounds; outerRing.path = UIBezierPath(ovalIn: circle.insetBy(dx: -UI.outerRingGap, dy: -UI.outerRingGap)).cgPath
        CATransaction.commit()
        let phaseY = circle.maxY + UI.phaseOffset, phaseWidth = min(width, UI.phaseWidth)
        phase.frame = CGRect(x: center - phaseWidth / 2, y: phaseY, width: phaseWidth, height: UI.phaseHeight)
        let privacyY = h - safe.bottom - UI.footerInset
        privacy.frame = CGRect(x: left, y: privacyY, width: width, height: UI.privacyHeight)
        brand.frame = CGRect(x: left, y: privacyY + UI.brandOffset, width: width, height: UI.brandHeight)
        if captured {
            let buttonY = privacyY - UI.buttonOffset, buttonWidth = (width - UI.buttonGap) / 2
            confirmation.frame = CGRect(x: left, y: buttonY - UI.confirmationOffset, width: width, height: UI.confirmationHeight)
            retake.frame = CGRect(x: left, y: buttonY, width: buttonWidth, height: UI.buttonHeight)
            confirm.frame = CGRect(x: left + buttonWidth + UI.buttonGap, y: buttonY, width: buttonWidth, height: UI.buttonHeight)
        } else { tips.frame = CGRect(x: left, y: phaseY + UI.tipsOffset, width: width, height: UI.tipsHeight) }
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
