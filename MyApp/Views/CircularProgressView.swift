import UIKit

// MARK: - Circular Progress Ring
final class CircularProgressView: UIView {
    let color: UIColor
    let lineWidth: CGFloat
    /// Called when the visible ring band (not its empty center) is tapped.
    var onTap: (() -> Void)?

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private(set) var progress: CGFloat = 0

    /// Extra tolerance around the stroke so thin rings stay easy to hit.
    private let hitSlop: CGFloat = 4

    init(color: UIColor, lineWidth: CGFloat = 16) {
        self.color = color
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = lineWidth

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        progressLayer.shadowOffset = .zero
        progressLayer.shadowOpacity = 0

        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
        updateColors()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CircularProgressView, _: UITraitCollection) in
            view.updateColors()
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var ringRadius: CGFloat { (min(bounds.width, bounds.height) - lineWidth) / 2 }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: max(ringRadius, 0),
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    /// Only the ring band receives touches, so inner concentric rings stay tappable.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let distance = hypot(point.x - bounds.midX, point.y - bounds.midY)
        return abs(distance - ringRadius) <= lineWidth / 2 + hitSlop
    }

    func setProgress(_ value: Double, animated: Bool) {
        let clamped = CGFloat(min(max(value, 0), 1))
        let fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
        progress = clamped

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = clamped
        progressLayer.shadowOpacity = Float(clamped > 0.1 ? clamped * 0.8 : 0)
        progressLayer.shadowRadius = clamped * 12
        CATransaction.commit()

        accessibilityValue = "\(Int(clamped * 100)) percent"

        guard animated, fromValue != clamped else {
            progressLayer.removeAnimation(forKey: "progress")
            return
        }
        let animation = CASpringAnimation(keyPath: "strokeEnd")
        animation.fromValue = fromValue
        animation.toValue = clamped
        animation.damping = 14
        animation.stiffness = 120
        animation.duration = animation.settlingDuration
        progressLayer.add(animation, forKey: "progress")
    }

    private func updateColors() {
        let resolved = color.resolvedColor(with: traitCollection)
        trackLayer.strokeColor = resolved.withAlphaComponent(0.3).cgColor
        progressLayer.strokeColor = resolved.cgColor
        progressLayer.shadowColor = resolved.cgColor
    }

    @objc private func handleTap() { onTap?() }

    override func accessibilityActivate() -> Bool {
        onTap?()
        return true
    }
}
