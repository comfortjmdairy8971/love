import UIKit

// MARK: - Activity Log History Cell
final class ActivityLogCell: UITableViewCell {
    static let reuseID = "ActivityLogCell"

    private let durationLabel = UILabel.make(font: .preferred(.subheadline, weight: .bold))
    private let dateLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel)
    private let noteLabel = UILabel.make(font: .preferred(.subheadline), lines: 2)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let topRow = UIStackView.make(.horizontal, spacing: 6, alignment: .firstBaseline, [durationLabel, dateLabel])
        let texts = UIStackView.make(.vertical, spacing: 4, alignment: .leading, [topRow, noteLabel])
        contentView.addSubview(texts)
        texts.pinEdges(to: contentView.layoutMarginsGuide)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with log: ActivityLog, color: UIColor) {
        durationLabel.text = "+\(formatDuration(minutes: log.durationMinutes))"
        durationLabel.textColor = color
        dateLabel.text = log.date.formatted(date: .abbreviated, time: .shortened)
        noteLabel.text = log.note
        noteLabel.isHidden = log.note.isEmpty

        accessibilityLabel = [
            "\(formatDuration(minutes: log.durationMinutes)) on \(dateLabel.text ?? "")",
            log.note.isEmpty ? nil : log.note,
        ].compactMap(\.self).joined(separator: ". ")
    }
}
