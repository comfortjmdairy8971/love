import UIKit

// MARK: - Insight Card Container
/// Card with a title, subtitle and arbitrary body content.
final class InsightCardView: UIView {
    let bodyStack = UIStackView.make(.vertical, spacing: 12)

    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle()
        let titleLabel = UILabel.make(title, font: .preferred(.headline), lines: 0)
        titleLabel.accessibilityTraits = .header
        let subtitleLabel = UILabel.make(subtitle, font: .preferred(.caption1), color: .secondaryLabel, lines: 0)
        let header = UIStackView.make(.vertical, spacing: 2, [titleLabel, subtitleLabel])
        let content = UIStackView.make(.vertical, spacing: 12, [header, bodyStack])
        addSubview(content)
        content.pinEdges(to: self, insets: .all(16))
        self.subtitleLabel = subtitleLabel
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private weak var subtitleLabel: UILabel?

    func setSubtitle(_ subtitle: String) { subtitleLabel?.text = subtitle }
}

// MARK: - Stat Tile
final class StatTileView: UIView {
    private let valueLabel: UILabel
    private let detailLabel = UILabel.make(font: .preferred(.caption2), color: .secondaryLabel)
    private let title: String

    init(title: String, color: UIColor) {
        self.title = title
        valueLabel = UILabel.make(font: .preferred(.title2, weight: .bold, design: .rounded), color: color)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle()
        let titleLabel = UILabel.make(title, font: .preferred(.caption1), color: .secondaryLabel)
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.8
        let content = UIStackView.make(.vertical, spacing: 4, [titleLabel, valueLabel, detailLabel])
        addSubview(content)
        content.pinEdges(to: self, insets: .all(16))
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(value: String, detail: String) {
        valueLabel.text = value
        detailLabel.text = detail
        accessibilityLabel = "\(title): \(value). \(detail)"
    }
}

// MARK: - Chip
final class ChipView: UIView {
    private let iconView = UIImageView()
    private let label = UILabel.make(font: .preferred(.caption2, weight: .semibold))

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption2)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        let content = UIStackView.make(.horizontal, spacing: 4, alignment: .center, [iconView, label])
        addSubview(content)
        content.pinEdges(to: self, insets: NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func configure(text: String, symbol: String, color: UIColor) {
        label.text = text
        label.textColor = color
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = color
        backgroundColor = color.withAlphaComponent(0.12)
        accessibilityLabel = text
    }
}
