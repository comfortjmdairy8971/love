import UIKit

// MARK: - Suggestion Cell
/// Icon + title/frequency stacked on the left, plus button on the right. Frequency always sits under the title so long translations (e.g. "Hebdomadaire") don't clip against the accessory.
final class SuggestionCell: UITableViewCell {
    static let reuseID = "SuggestionCell"

    private let iconTile = IconTileView(symbol: "sparkles", color: .brandAccent, side: 34, cornerRadius: 9, pointSize: 15)
    private let titleLabel = UILabel.make(font: .preferred(.body, weight: .medium), lines: 0)
    private let frequencyLabel = UILabel.make(font: .preferred(.subheadline), color: .secondaryLabel, lines: 1)
    private let plusView = UIImageView.symbol("plus.circle.fill", style: .title2, color: .brandAccent)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default

        titleLabel.lineBreakMode = .byWordWrapping
        frequencyLabel.lineBreakMode = .byTruncatingTail
        plusView.setContentHuggingPriority(.required, for: .horizontal)
        plusView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let texts = UIStackView.make(.vertical, spacing: 4, alignment: .leading, [titleLabel, frequencyLabel])
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)
        texts.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let content = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [iconTile, texts, plusView])
        contentView.addSubview(content)
        content.pinEdges(to: contentView.layoutMarginsGuide)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, icon: String, frequency: String) {
        iconTile.configure(symbol: icon, color: .brandAccent)
        titleLabel.text = title
        frequencyLabel.text = frequency
        accessibilityLabel = "\(title), \(frequency)"
        accessibilityHint = String(localized: "Adds this ritual")
    }
}
