import UIKit

// MARK: - Dynamic Hero Banner
final class HeroBannerView: UIView {
    private let overdueDays = 7

    private let inProgressCard = UIView()
    private let headerIcon = UIImageView.symbol("sparkles", style: .headline, color: .systemPink)
    private let goingOutPill = DaysSincePillView(category: .goingOut)
    private let adventuresPill = DaysSincePillView(category: .newAdventures)
    private let subtitleLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel, lines: 0)

    private let celebrationCard = UIView()

    private lazy var stack = UIStackView.make(.vertical, [inProgressCard, celebrationCard])
    private var allGoalsAchieved = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self)
        setUpInProgressCard()
        setUpCelebrationCard()
        celebrationCard.isHidden = true
        celebrationCard.alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpInProgressCard() {
        inProgressCard.applyCardStyle()
        let title = UILabel.make("Haven't done in a while", font: .preferred(.headline))
        let header = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [headerIcon, title, .spacer()])
        let pills = UIStackView.make(.horizontal, spacing: 12, distribution: .fillEqually, [goingOutPill, adventuresPill])
        let content = UIStackView.make(.vertical, spacing: 12, [header, pills, subtitleLabel])
        inProgressCard.addSubview(content)
        content.pinEdges(to: inProgressCard, insets: .all(16))
    }

    private func setUpCelebrationCard() {
        celebrationCard.layer.shadowColor = UIColor.systemPink.cgColor
        celebrationCard.layer.shadowOpacity = 0.28
        celebrationCard.layer.shadowRadius = 12
        celebrationCard.layer.shadowOffset = CGSize(width: 0, height: 6)

        let gradient = GradientView(colors: [.systemPink, .systemOrange, UIColor.systemPurple.withAlphaComponent(0.9)])
        gradient.layer.cornerRadius = 16
        gradient.layer.cornerCurve = .continuous
        gradient.clipsToBounds = true
        celebrationCard.addSubview(gradient)
        gradient.pinEdges(to: celebrationCard)

        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconCircle.layer.cornerRadius = 24
        let icon = UIImageView.symbol("party.popper.fill", style: .title2, color: .white)
        iconCircle.addSubview(icon)

        let eyebrow = UILabel.make(font: .preferred(.caption1, weight: .heavy), color: UIColor.white.withAlphaComponent(0.9))
        eyebrow.attributedText = NSAttributedString(string: "ALL WEEKLY GOALS COMPLETE!", attributes: [.kern: 0.8])
        let message = UILabel.make(
            "Your weekly goals achieved! A great reason to celebrate together! 🎉",
            font: .preferred(.subheadline, weight: .semibold),
            color: .white,
            lines: 0
        )
        let texts = UIStackView.make(.vertical, spacing: 4, [eyebrow, message])
        let content = UIStackView.make(.horizontal, spacing: 14, alignment: .center, [iconCircle, texts])
        gradient.addSubview(content)
        content.pinEdges(to: gradient, insets: .all(16))

        NSLayoutConstraint.activate([
            iconCircle.widthAnchor.constraint(equalToConstant: 48),
            iconCircle.heightAnchor.constraint(equalToConstant: 48),
            icon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
        ])
        celebrationCard.isAccessibilityElement = true
        celebrationCard.accessibilityLabel = "All weekly goals complete! \(message.text ?? "")"
    }

    // MARK: Updates
    func configure(allGoalsAchieved achieved: Bool, goingOutDays: Int?, adventureDays: Int?, animated: Bool) {
        goingOutPill.configure(days: goingOutDays, overdueDays: overdueDays)
        adventuresPill.configure(days: adventureDays, overdueDays: overdueDays)

        let needsAttention = [goingOutDays, adventureDays].contains { ($0 ?? .max) >= overdueDays }
        headerIcon.image = UIImage(systemName: needsAttention ? "hourglass.bottomhalf.filled" : "sparkles")
        headerIcon.tintColor = needsAttention ? .systemOrange : .systemPink
        subtitleLabel.text = Self.subtitle(goingOutDays: goingOutDays, adventureDays: adventureDays)

        guard achieved != allGoalsAchieved else { return }
        allGoalsAchieved = achieved
        let changes = {
            self.inProgressCard.isHidden = achieved
            self.inProgressCard.alpha = achieved ? 0 : 1
            self.celebrationCard.isHidden = !achieved
            self.celebrationCard.alpha = achieved ? 1 : 0
            self.superview?.layoutIfNeeded()
        }
        guard animated else { return changes() }
        UIView.animate(springDuration: 0.45, bounce: 0.2, animations: changes)
    }

    private static func subtitle(goingOutDays: Int?, adventureDays: Int?) -> String {
        if let days = goingOutDays, days > 0 {
            return "\(days) \(days == 1 ? "day" : "days") since your last date night out"
        }
        if let days = adventureDays, days > 0 {
            return "\(days) \(days == 1 ? "day" : "days") since your last new adventure"
        }
        if goingOutDays == 0 || adventureDays == 0 {
            return "You made time for Going Out or New Adventures today!"
        }
        return "Log a date night out or a new adventure to start tracking."
    }
}

// MARK: - Days Since Pill
final class DaysSincePillView: UIView {
    private let category: ActivityCategory
    private let valueLabel = UILabel.make(font: .preferred(.subheadline, weight: .bold))

    init(category: ActivityCategory) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = category.color.withAlphaComponent(0.08)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        let icon = IconTileView(symbol: category.icon, color: category.color, side: 30, cornerRadius: 8, pointSize: 14)
        let caption = UILabel.make(category.title, font: .preferred(.caption1), color: .secondaryLabel)
        caption.adjustsFontSizeToFitWidth = true
        caption.minimumScaleFactor = 0.8
        let texts = UIStackView.make(.vertical, spacing: 2, [caption, valueLabel])
        let content = UIStackView.make(.horizontal, spacing: 10, alignment: .center, [icon, texts])
        addSubview(content)
        content.pinEdges(to: self, insets: .all(10))

        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(days: Int?, overdueDays: Int) {
        let text = switch days {
        case nil: "Not yet"
        case 0: "Today"
        case 1: "1 day"
        case let days?: "\(days) days"
        }
        valueLabel.text = text
        valueLabel.textColor = (days ?? .max) >= overdueDays ? .systemOrange : .label
        accessibilityLabel = "\(category.title): \(days == nil ? "not logged yet" : text)"
    }
}
