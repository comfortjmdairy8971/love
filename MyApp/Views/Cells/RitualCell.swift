import UIKit

// MARK: - Ritual Cell
final class RitualCell: UITableViewCell {
    static let reuseID = "RitualCell"

    var onToggle: (() -> Void)?

    private let iconTile = IconTileView(symbol: Ritual.defaultIcon, color: .systemPink, side: 34, cornerRadius: 9, pointSize: 15)
    private let titleLabel = UILabel.make(font: .preferred(.headline), lines: 2)
    private let streakBadge = PaddingLabel.badge()
    private let checkButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 28, weight: .regular), forImageIn: .normal)
        checkButton.setContentHuggingPriority(.required, for: .horizontal)
        checkButton.accessibilityIdentifier = AccessibilityID.Rituals.checkButton
        checkButton.addAction(UIAction { [weak self] _ in self?.onToggle?() }, for: .touchUpInside)

        let texts = UIStackView.make(.vertical, spacing: 4, alignment: .leading, [titleLabel, streakBadge])
        let content = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [iconTile, texts, .spacer(), checkButton])
        contentView.addSubview(content)
        content.pinEdges(to: contentView.layoutMarginsGuide)

        NSLayoutConstraint.activate([
            checkButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            checkButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with ritual: Ritual) {
        let isDone = ritual.isCompleted()
        let streak = ritual.activeStreak()
        let frequency = ritual.ritualFrequency

        iconTile.configure(symbol: ritual.icon, color: .systemPink)
        titleLabel.text = ritual.title

        let badgeColor: UIColor = streak > 0 ? .systemOrange : .secondaryLabel
        streakBadge.text = streak > 0 ? "🔥 \(streak) \(frequency.unit) streak" : "\(frequency.title) · start a streak"
        streakBadge.textColor = badgeColor
        streakBadge.backgroundColor = badgeColor.withAlphaComponent(0.12)

        checkButton.setImage(UIImage(systemName: isDone ? "checkmark.circle.fill" : "circle"), for: .normal)
        checkButton.tintColor = isDone ? .systemGreen : .tertiaryLabel
        checkButton.accessibilityLabel = isDone ? "Mark \(ritual.title) not done" : "Mark \(ritual.title) done"
    }

    func playCompletionBounce() {
        checkButton.imageView?.addSymbolEffect(.bounce)
    }
}
