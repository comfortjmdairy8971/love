import UIKit

// MARK: - Couple Header
/// Dashboard card with the couple's photo, names, and how long they've been together.
final class CoupleHeaderView: UIView {
    var onPhotoTap: (() -> Void)? {
        get { avatar.onTap }
        set { avatar.onTap = newValue }
    }

    private let avatar = CoupleAvatarView(side: 52, showsCameraBadge: true)
    private let namesLabel = UILabel.make(font: .preferred(.title2, weight: .bold, design: .rounded), lines: 0)
    private let durationLabel = UILabel.make(font: .preferred(.subheadline, weight: .semibold), color: .brandAccent, lines: 0)
    private let detailLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel, lines: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle()

        let texts = UIStackView.make(.vertical, spacing: 2, [namesLabel, durationLabel, detailLabel])
        let content = UIStackView.make(.horizontal, spacing: 14, alignment: .center, [avatar, texts])
        addSubview(content)
        content.pinEdges(to: self, insets: .all(16))

        isAccessibilityElement = false
        accessibilityIdentifier = AccessibilityID.Dashboard.coupleHeader
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with profile: CoupleProfile, now: Date = .now, calendar: Calendar = .current) {
        isHidden = !profile.hasDetails
        avatar.reload()
        namesLabel.text = profile.displayNames ?? String(localized: "Our Story")

        if let startDate = profile.startDate, let days = profile.daysTogether(now: now, calendar: calendar) {
            durationLabel.text = Self.headline(startDate: startDate, profile: profile, now: now, calendar: calendar)
            let since = startDate.formatted(date: .long, time: .omitted)
            detailLabel.text = days == 1
                ? String(localized: "1 day since \(since)")
                : String(localized: "\(days.formatted()) days since \(since)")
            detailLabel.isHidden = false
        } else {
            durationLabel.text = String(localized: "Add the day your story began in Settings")
            detailLabel.isHidden = true
        }

        accessibilityLabel = [namesLabel.text, durationLabel.text, detailLabel.isHidden ? nil : detailLabel.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private static func headline(startDate: Date, profile: CoupleProfile, now: Date, calendar: Calendar) -> String {
        let start = calendar.dateComponents([.month, .day], from: startDate)
        let today = calendar.dateComponents([.month, .day], from: now)
        let years = calendar.dateComponents([.year], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: now)).year ?? 0
        if years > 0, start.month == today.month, start.day == today.day {
            return years == 1
                ? String(localized: "Happy 1-year anniversary! 🎉")
                : String(localized: "Happy \(years)-year anniversary! 🎉")
        }
        return profile.durationText(now: now, calendar: calendar).map { String(localized: "Together for \($0) 💞") }
            ?? String(localized: "Your story starts today ✨")
    }
}
