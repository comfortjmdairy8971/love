import UIKit

// MARK: - Activity Log History Cell
final class ActivityLogCell: UITableViewCell {
    static let reuseID = "ActivityLogCell"
    private static let thumbnailSide: CGFloat = 52

    private let durationLabel = UILabel.make(font: .preferred(.subheadline, weight: .bold))
    private let dateLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel)
    private let noteLabel = UILabel.make(font: .preferred(.subheadline), lines: 2)
    private let thumbnailView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 8
        thumbnailView.layer.cornerCurve = .continuous

        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let topRow = UIStackView.make(.horizontal, spacing: 6, alignment: .firstBaseline, [durationLabel, dateLabel])
        let texts = UIStackView.make(.vertical, spacing: 4, alignment: .leading, [topRow, noteLabel])
        let content = UIStackView.make(.horizontal, spacing: 12, alignment: .top, [texts, .spacer(), thumbnailView])
        contentView.addSubview(content)
        content.pinEdges(to: contentView.layoutMarginsGuide)

        NSLayoutConstraint.activate([
            thumbnailView.widthAnchor.constraint(equalToConstant: Self.thumbnailSide),
            thumbnailView.heightAnchor.constraint(equalToConstant: Self.thumbnailSide),
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with log: ActivityLog, color: UIColor) {
        durationLabel.text = "+\(formatDuration(minutes: log.durationMinutes))"
        durationLabel.textColor = color
        dateLabel.text = log.date.formatted(date: .abbreviated, time: .shortened)
        noteLabel.text = log.note
        noteLabel.isHidden = log.note.isEmpty

        let thumbnail = ThumbnailCache.thumbnail(for: log, side: Self.thumbnailSide, scale: traitCollection.displayScale)
        thumbnailView.image = thumbnail
        thumbnailView.isHidden = thumbnail == nil

        accessibilityLabel = [
            "\(formatDuration(minutes: log.durationMinutes)) on \(dateLabel.text ?? "")",
            log.note.isEmpty ? nil : log.note,
            thumbnail == nil ? nil : "Has photo",
        ].compactMap(\.self).joined(separator: ". ")
    }
}
