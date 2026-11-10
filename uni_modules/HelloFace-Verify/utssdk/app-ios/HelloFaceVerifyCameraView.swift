import UIKit

/// Native presentation only. The mask does not change camera pixels or SDK coordinates.
final class HelloFaceVerifyCameraView: UIView {
    static let background = UIColor(red: 247/255, green: 249/255, blue: 252/255, alpha: 1)
    private let ink = UIColor(red: 25/255, green: 50/255, blue: 79/255, alpha: 1)
    private let muted = UIColor(red: 96/255, green: 115/255, blue: 139/255, alpha: 1)
    private let blue = UIColor(red: 40/255, green: 120/255, blue: 239/255, alpha: 1)
    private let green = UIColor(red: 40/255, green: 134/255, blue: 108/255, alpha: 1)
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
        photo.contentMode = .scaleAspectFill; photo.clipsToBounds = true
        photo.accessibilityLabel = "已采集的人脸照片"; photo.isAccessibilityElement = true
        addSubview(photo)
        cutoutMask.fillColor = Self.background.cgColor; cutoutMask.fillRule = .evenOdd
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = blue.cgColor; ring.lineWidth = 3
        outerRing.fillColor = UIColor.clear.cgColor
        outerRing.strokeColor = UIColor(red: 220/255, green: 230/255, blue: 244/255, alpha: 1).cgColor
        outerRing.lineWidth = 1
        [cutoutMask, outerRing, ring].forEach { layer.addSublayer($0) }
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = ink; back.accessibilityLabel = "返回"
        back.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        style(heading, text: enrollment ? "人脸录入" : "身份验证", size: 17, color: ink, weight: .semibold)
        style(local, text: "● 本机处理", size: 11, color: green)
        local.backgroundColor = UIColor(red: 232/255, green: 244/255, blue: 239/255, alpha: 1)
        local.layer.cornerRadius = 13; local.clipsToBounds = true
        style(title, text: "正在准备相机", size: 25, color: ink, weight: .semibold)
        title.accessibilityTraits.insert(.updatesFrequently)
        style(detail, text: "请将面部置于圆框内，保持光线均匀", size: 13, color: muted)
        style(phase, text: "", size: 12, color: blue)
        phase.backgroundColor = UIColor(red: 234/255, green: 241/255, blue: 253/255, alpha: 1)
        phase.layer.cornerRadius = 13; phase.clipsToBounds = true
        tips.axis = .horizontal; tips.distribution = .fillEqually
        tips.backgroundColor = .white; tips.layer.cornerRadius = 18
        for text in ["人脸居中", "光线均匀", "面部无遮挡"] {
            let label = UILabel(); style(label, text: text, size: 12, color: ink); tips.addArrangedSubview(label)
        }
        style(confirmation, text: "确认后将加密保存人脸特征，不保存照片", size: 13, color: muted)
        style(retake, text: "重新采集", fill: .white, color: ink)
        retake.layer.borderColor = UIColor(red: 220/255, green: 229/255, blue: 241/255, alpha: 1).cgColor
        retake.layer.borderWidth = 1
        retake.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        style(confirm, text: "确认录入", fill: blue, color: .white)
        confirm.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        style(privacy, text: "人脸处理在本机完成", size: 12, color: muted)
        style(brand, text: "HelloFaceVerify", size: 11, color: UIColor(red: 120/255, green: 137/255, blue: 155/255, alpha: 1))
        [back, heading, local, title, detail, phase, tips, confirmation, retake, confirm, privacy, brand]
            .forEach { addSubview($0) }
        showLive()
    }
    required init?(coder: NSCoder) { fatalError("Use init(enrollment:)") }

    func showLive() {
        captured = false; photo.image = nil; photo.isHidden = true
        title.text = "请正对镜头"; detail.text = "请将面部置于圆框内，保持光线均匀"
        phase.text = enrollment ? "第一步 · 人脸采集" : "实时身份核验"
        tips.isHidden = false
        [confirmation, retake, confirm].forEach { $0.isHidden = true }
        [back, retake, confirm].forEach { $0.isEnabled = true; $0.alpha = 1 }
        confirm.setTitle("确认录入", for: .normal); ring.strokeColor = blue.cgColor; setNeedsLayout()
    }

    func showProgress(stage: String, action: String?, step: Int, count: Int, guidance: String) {
        guard !captured else { return }
        if title.text != guidance { title.text = guidance }
        let phaseText = stage == "PERFORM_ACTION" && count > 0 ? "动作验证 · \(step)/\(count)" :
            (enrollment ? "第一步 · 人脸采集" : "实时身份核验")
        if phase.text != phaseText { phase.text = phaseText }
        let color = (["MULTIPLE_FACES", "FACE_TOO_SMALL", "FACE_NOT_FRONTAL"].contains(stage)
            ? UIColor(red: 197/255, green: 138/255, blue: 39/255, alpha: 1) : blue).cgColor
        if ring.strokeColor != color {
            CATransaction.begin(); CATransaction.setDisableActions(true); ring.strokeColor = color; CATransaction.commit()
        }
    }

    func showConfirmation(image: UIImage?, mirrored: Bool) {
        captured = true; photo.image = image; photo.isHidden = image == nil
        photo.transform = CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1)
        title.text = image == nil ? "未能生成预览" : "请确认人脸照片"
        detail.text = image == nil ? "请重新采集后再确认" : "照片清晰且为本人，即可确认录入"
        confirm.isEnabled = image != nil
        phase.text = "第二步 · 确认保存"; ring.strokeColor = green.cgColor
        tips.isHidden = true
        [confirmation, retake, confirm].forEach { $0.isHidden = false }
        setNeedsLayout()
    }

    func showSaving() {
        title.text = "正在保存人脸基准"; detail.text = "即将完成，请稍候"
        confirm.setTitle("正在保存…", for: .normal)
        [back, retake, confirm].forEach { $0.isEnabled = false; $0.alpha = 0.55 }
    }
    func clearPhoto() { photo.image = nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets, w = bounds.width, h = bounds.height
        let left = safe.left + 24, right = w - safe.right - 24, width = right - left, center = (left + right) / 2
        let headerY = safe.top + 8
        back.frame = CGRect(x: safe.left + 12, y: headerY, width: 44, height: 44)
        heading.frame = CGRect(x: center - 48, y: headerY, width: 96, height: 44)
        local.frame = CGRect(x: right - 76, y: headerY + 10, width: 76, height: 25)
        let titleY = headerY + (h - safe.top - safe.bottom < 600 ? 55 : 70)
        title.frame = CGRect(x: left, y: titleY, width: width, height: 54)
        detail.frame = CGRect(x: left, y: titleY + 56, width: width, height: 34)
        let circleTop = titleY + 104
        let diameter = max(100, min(width, (w - safe.left - safe.right) * 0.8,
                                    h - safe.bottom - (captured ? 206 : 168) - circleTop))
        let circle = CGRect(x: center - diameter / 2, y: circleTop, width: diameter, height: diameter)
        photo.bounds = CGRect(origin: .zero, size: circle.size); photo.center = CGPoint(x: circle.midX, y: circle.midY)
        photo.layer.cornerRadius = diameter / 2
        let cutout = UIBezierPath(rect: bounds); cutout.append(UIBezierPath(ovalIn: circle))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        cutoutMask.frame = bounds; cutoutMask.path = cutout.cgPath
        ring.frame = bounds; ring.path = UIBezierPath(ovalIn: circle).cgPath
        outerRing.frame = bounds; outerRing.path = UIBezierPath(ovalIn: circle.insetBy(dx: -7, dy: -7)).cgPath
        CATransaction.commit()
        let phaseY = circle.maxY + 16, phaseWidth = min(width, 176)
        phase.frame = CGRect(x: center - phaseWidth / 2, y: phaseY, width: phaseWidth, height: 26)
        let privacyY = h - safe.bottom - 49
        privacy.frame = CGRect(x: left, y: privacyY, width: width, height: 20)
        brand.frame = CGRect(x: left, y: privacyY + 22, width: width, height: 16)
        if captured {
            let buttonY = privacyY - 64, buttonWidth = (width - 12) / 2
            confirmation.frame = CGRect(x: left, y: buttonY - 42, width: width, height: 36)
            retake.frame = CGRect(x: left, y: buttonY, width: buttonWidth, height: 50)
            confirm.frame = CGRect(x: left + buttonWidth + 12, y: buttonY, width: buttonWidth, height: 50)
        } else { tips.frame = CGRect(x: left, y: phaseY + 39, width: width, height: 48) }
    }

    private func style(_ label: UILabel, text: String, size: CGFloat, color: UIColor, weight: UIFont.Weight = .regular) {
        label.text = text; label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.adjustsFontForContentSizeCategory = true; label.textColor = color; label.textAlignment = .center
        label.numberOfLines = 2; label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.75
    }
    private func style(_ button: UIButton, text: String, fill: UIColor, color: UIColor) {
        button.setTitle(text, for: .normal); button.setTitleColor(color, for: .normal)
        button.backgroundColor = fill; button.layer.cornerRadius = 14
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    }
    @objc private func cancelTapped() { onCancel?() }
    @objc private func retakeTapped() { onRetake?() }
    @objc private func confirmTapped() { onConfirm?() }
}
