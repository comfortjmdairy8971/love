import UIKit

// MARK: - Concentric Rings + Center Display
final class ConcentricRingsView: UIView {
    static let diameters: [CGFloat] = [260, 210, 160, 110]
    static let lineWidth: CGFloat = 16

    var onRingTapped: ((ActivityCategory) -> Void)?
    var onCenterTapped: (() -> Void)?

    private(set) var rings: [ActivityCategory: CircularProgressView] = [:]
    private let centerView = CircularHitView()
    private let heartView = UIImageView.symbol("heart.fill", style: .largeTitle, color: .brandAccent)
    private let percentLabel = UILabel.make(font: .rounded(ofSize: 22, weight: .bold), alignment: .center)
    private let titleLabel: UILabel = {
        let label = UILabel.make(font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabel, lines: 2, alignment: .center)
        label.applyFlexibleTitle()
        return label
    }()
    private lazy var centerStack = UIStackView.make(.vertical, spacing: 2, alignment: .center, [percentLabel, titleLabel])

    private var isCelebrating = false

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        for (index, category) in ActivityCategory.allCases.enumerated() {
            let ring = CircularProgressView(color: category.color, lineWidth: Self.lineWidth)
            ring.accessibilityLabel = "\(category.title) ring"
            ring.onTap = { [weak self] in self?.onRingTapped?(category) }
            addSubview(ring)
            let diameter = Self.diameters[index]
            NSLayoutConstraint.activate([
                ring.centerXAnchor.constraint(equalTo: centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: centerYAnchor),
                ring.widthAnchor.constraint(equalToConstant: diameter),
                ring.heightAnchor.constraint(equalToConstant: diameter),
            ])
            rings[category] = ring
        }

        setUpCenter()

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameters[0]),
            heightAnchor.constraint(equalToConstant: Self.diameters[0]),
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(restartPulse), name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpCenter() {
        centerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerView)

        heartView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        heartView.alpha = 0.9
        heartView.layer.shadowColor = UIColor.brandAccent.cgColor
        heartView.layer.shadowOpacity = 0.3
        heartView.layer.shadowRadius = 10
        heartView.layer.shadowOffset = .zero

        percentLabel.adjustsFontForContentSizeCategory = false
        titleLabel.adjustsFontForContentSizeCategory = false
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        centerStack.alpha = 0

        centerView.addSubview(heartView)
        centerView.addSubview(centerStack)

        // Innermost ring band starts at a radius of 39pt, so the center must stay smaller.
        let centerSide: CGFloat = 76
        NSLayoutConstraint.activate([
            centerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerView.widthAnchor.constraint(equalToConstant: centerSide),
            centerView.heightAnchor.constraint(equalToConstant: centerSide),
            heartView.centerXAnchor.constraint(equalTo: centerView.centerXAnchor),
            heartView.centerYAnchor.constraint(equalTo: centerView.centerYAnchor),
            centerStack.centerXAnchor.constraint(equalTo: centerView.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerView.centerYAnchor),
            centerStack.widthAnchor.constraint(lessThanOrEqualTo: centerView.widthAnchor),
        ])

        centerView.onTap = { [weak self] in self?.onCenterTapped?() }
        centerView.isAccessibilityElement = true
        centerView.accessibilityTraits = .button
        centerView.accessibilityLabel = "Weekly rings"
    }

    // MARK: Updates
    func update(progress: [ActivityCategory: Double], animated: Bool) {
        for (category, ring) in rings {
            ring.setProgress(progress[category] ?? 0, animated: animated)
        }
    }

    /// Scales the selected ring, dims the rest and swaps the center heart for the percentage.
    func setSelection(_ category: ActivityCategory?, percentage: Int, animated: Bool) {
        if let category {
            percentLabel.text = "\(percentage)%"
            percentLabel.textColor = category.color
            titleLabel.text = category.title
            centerView.accessibilityLabel = "\(category.title), \(percentage) percent. Show all rings"
        } else {
            centerView.accessibilityLabel = "Weekly rings"
        }

        let changes = {
            for (ringCategory, ring) in self.rings {
                let isSelected = ringCategory == category
                ring.transform = isSelected ? CGAffineTransform(scaleX: 1.08, y: 1.08) : .identity
                ring.alpha = category == nil || isSelected ? 1 : 0.3
            }
            let showsHeart = category == nil
            self.heartView.alpha = showsHeart ? 0.9 : 0
            self.heartView.transform = showsHeart ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.centerStack.alpha = showsHeart ? 0 : 1
            self.centerStack.transform = showsHeart ? CGAffineTransform(scaleX: 0.85, y: 0.85) : .identity
        }

        guard animated else { return changes() }
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    /// Pulses the center heart while every weekly goal is complete.
    func setCelebrating(_ celebrating: Bool) {
        guard celebrating != isCelebrating else { return }
        isCelebrating = celebrating
        restartPulse()
    }

    @objc private func restartPulse() {
        heartView.layer.removeAnimation(forKey: "pulse")
        guard isCelebrating else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.18
        pulse.duration = 0.75
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.isRemovedOnCompletion = false
        heartView.layer.add(pulse, forKey: "pulse")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { restartPulse() }
    }
}

/// A tappable view that only accepts touches inside its inscribed circle.
final class CircularHitView: TapView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        hypot(point.x - bounds.midX, point.y - bounds.midY) <= min(bounds.width, bounds.height) / 2
    }
}
