import UIKit

// MARK: - Category Card
/// The whole card is a control that opens the detail screen; the "+15m" button handles its own taps.
final class CategoryCardView: UIControl {
    let category: ActivityCategory
    var onQuickAdd: (() -> Void)?

    private let tintOverlay = UIView()
    private let titleLabel: UILabel
    private let percentLabel = UILabel.make(font: .preferred(.title1, weight: .bold, design: .rounded))
    private let minutesLabel = UILabel.make(font: .preferred(.caption1, weight: .medium))
    private let contentStack = UIStackView.make(.vertical, spacing: 10)
    let quickAddButton: UIButton

    init(category: ActivityCategory) {
        self.category = category
        titleLabel = UILabel.make(category.title, font: .preferred(.subheadline, weight: .semibold), color: .secondaryLabel)
        quickAddButton = UIButton(configuration: .capsule(
            title: "+15m",
            color: category.color,
            font: .preferred(.subheadline, weight: .bold),
            verticalPadding: 6
        ))
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setUpViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpViews() {
        applyCardStyle()
        layer.borderColor = category.color.cgColor

        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.backgroundColor = category.color.withAlphaComponent(0.08)
        tintOverlay.layer.cornerRadius = 16
        tintOverlay.layer.cornerCurve = .continuous
        tintOverlay.alpha = 0
        tintOverlay.isUserInteractionEnabled = false
        addSubview(tintOverlay)
        tintOverlay.pinEdges(to: self)

        let icon = UIImageView.symbol(category.icon, style: .title3, color: category.color)
        let chevron = UIImageView.symbol("chevron.right", style: .caption1, weight: .semibold, color: .tertiaryLabel)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        let header = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [icon, titleLabel, .spacer(), chevron])

        let doneLabel = UILabel.make("done", font: .preferred(.caption1), color: .secondaryLabel)
        let percentRow = UIStackView.make(.horizontal, spacing: 4, alignment: .firstBaseline, [percentLabel, doneLabel, .spacer()])

        let infoLabel = UILabel.make(category.info, font: .preferred(.caption2), color: .secondaryLabel)

        minutesLabel.adjustsFontSizeToFitWidth = true
        minutesLabel.minimumScaleFactor = 0.8
        quickAddButton.setContentHuggingPriority(.required, for: .horizontal)
        quickAddButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        quickAddButton.addAction(UIAction { [weak self] _ in self?.onQuickAdd?() }, for: .touchUpInside)
        let bottomRow = UIStackView.make(.horizontal, spacing: 4, alignment: .center, [minutesLabel, .spacer(), quickAddButton])

        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(percentRow)
        contentStack.addArrangedSubview(infoLabel)
        contentStack.addArrangedSubview(bottomRow)
        addSubview(contentStack)
        contentStack.pinEdges(to: self, insets: .all(16))

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Opens details"
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Add 15 minutes") { [weak self] _ in
                self?.onQuickAdd?()
                return true
            },
        ]
    }

    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchUpInside)
        return true
    }

    /// Routes touches on "+15m" to the button and everything else to this control.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, self.point(inside: point, with: event) else { return nil }
        let buttonPoint = convert(point, to: quickAddButton)
        return quickAddButton.point(inside: buttonPoint, with: event) ? quickAddButton : self
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func configure(currentMinutes: Int, targetMinutes: Int) {
        let percentage = min(Int(Double(currentMinutes) / Double(max(targetMinutes, 1)) * 100), 100)
        percentLabel.text = "\(percentage)%"
        minutesLabel.text = "\(currentMinutes) / \(targetMinutes) mins"
        accessibilityLabel =
            "\(category.title), \(percentage) percent done, \(currentMinutes) of \(targetMinutes) minutes. \(category.info)"
    }

    func setSelected(_ isSelected: Bool, animated: Bool) {
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        let changes = {
            self.titleLabel.textColor = isSelected ? self.category.color : .secondaryLabel
            self.tintOverlay.alpha = isSelected ? 1 : 0
            self.layer.borderWidth = isSelected ? 2 : 0
            self.layer.shadowColor = (isSelected ? self.category.color : .black).cgColor
            self.layer.shadowOpacity = isSelected ? 0.22 : 0.04
            self.layer.shadowRadius = isSelected ? 10 : 5
        }
        guard animated else { return changes() }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
    }
}
