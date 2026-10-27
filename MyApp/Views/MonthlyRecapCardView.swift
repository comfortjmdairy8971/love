import UIKit

// MARK: - Shareable Monthly Recap Card
/// Fixed-size artwork (340×500) so the shared image looks identical on every device.
final class MonthlyRecapCardView: UIView {
    static let size = CGSize(width: 340, height: 500)

    private let monthLabel = MonthlyRecapCardView.label(font: .systemFont(ofSize: 20, weight: .bold))
    private let hoursLabel = MonthlyRecapCardView.label(font: .rounded(ofSize: 64, weight: .heavy))
    private let subtitleLabel = MonthlyRecapCardView.label(font: .systemFont(ofSize: 17, weight: .semibold), alpha: 0.9)
    private let topCategoryBadge = RecapBadgeView()
    private let ritualsBadge = RecapBadgeView()
    private let breakdownStack = UIStackView.make(.vertical, spacing: 10)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 28
        layer.cornerCurve = .continuous
        clipsToBounds = true
        setUpBackground()
        setUpContent()
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size.width),
            heightAnchor.constraint(equalToConstant: Self.size.height),
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func label(font: UIFont, alpha: CGFloat = 1) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = UIColor.white.withAlphaComponent(alpha)
        return label
    }

    private func setUpBackground() {
        let gradient = GradientView(colors: [.brandAccent, .systemPurple, UIColor.systemOrange.withAlphaComponent(0.9)])
        addSubview(gradient)
        gradient.pinEdges(to: self)

        for (side, offset, alpha) in [(CGFloat(260), CGPoint(x: 140, y: -190), 0.12), (200, CGPoint(x: -150, y: 210), 0.08)] {
            let circle = UIView()
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.backgroundColor = UIColor.white.withAlphaComponent(alpha)
            circle.layer.cornerRadius = side / 2
            gradient.addSubview(circle)
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: side),
                circle.heightAnchor.constraint(equalToConstant: side),
                circle.centerXAnchor.constraint(equalTo: centerXAnchor, constant: offset.x),
                circle.centerYAnchor.constraint(equalTo: centerYAnchor, constant: offset.y),
            ])
        }
    }

    private func setUpContent() {
        let eyebrow = Self.label(font: .systemFont(ofSize: 12, weight: .heavy), alpha: 0.8)
        eyebrow.attributedText = NSAttributedString(string: "OUR MONTH", attributes: [.kern: 2])
        let titles = UIStackView.make(.vertical, spacing: 2, [eyebrow, monthLabel])
        let header = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [AppLogoPlaceholderView(), titles, .spacer()])

        let hours = UIStackView.make(.vertical, spacing: 0, [hoursLabel, subtitleLabel])
        let badges = UIStackView.make(.horizontal, spacing: 10, distribution: .fillEqually, [topCategoryBadge, ritualsBadge])

        let content = UIStackView.make(.vertical, spacing: 18, [header, hours, badges, breakdownStack, .spacer()])
        addSubview(content)
        content.pinEdges(to: self, insets: .all(24))
    }

    func configure(with recap: MonthlyRecap) {
        monthLabel.text = recap.monthName
        hoursLabel.text = recap.hoursText
        subtitleLabel.text = "hours together · \(recap.moments) moments"
        topCategoryBadge.configure(
            symbol: recap.topCategory?.icon ?? "heart.fill",
            caption: "Top category",
            value: recap.topCategory?.title ?? "—"
        )
        ritualsBadge.configure(symbol: "flame.fill", caption: "Rituals done", value: "\(recap.ritualsCompleted)")

        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let maxMinutes = max(recap.breakdown.first?.minutes ?? 0, 1)
        for item in recap.breakdown {
            breakdownStack.addArrangedSubview(
                RecapBarRow(category: item.category, minutes: item.minutes, fraction: CGFloat(item.minutes) / CGFloat(maxMinutes))
            )
        }

        accessibilityLabel = "\(recap.monthName) recap: \(recap.hoursText) hours together, \(recap.moments) moments, "
            + "top category \(recap.topCategory?.title ?? "none"), \(recap.ritualsCompleted) rituals completed."
    }

    func renderImage() -> UIImage {
        layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = traitCollection.displayScale
        format.opaque = false
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            if window != nil {
                drawHierarchy(in: bounds, afterScreenUpdates: true)
            } else {
                layer.render(in: context.cgContext)
            }
        }
    }
}

// MARK: - Recap Building Blocks
private final class AppLogoPlaceholderView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.white.withAlphaComponent(0.22)
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor

        let heart = UIImageView(image: UIImage(systemName: "heart.fill"))
        heart.translatesAutoresizingMaskIntoConstraints = false
        heart.tintColor = .white
        heart.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        heart.layer.shadowColor = UIColor.white.cgColor
        heart.layer.shadowOpacity = 0.5
        heart.layer.shadowRadius = 6
        heart.layer.shadowOffset = .zero
        addSubview(heart)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44),
            heart.centerXAnchor.constraint(equalTo: centerXAnchor),
            heart.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class RecapBadgeView: UIView {
    private let iconView = UIImageView()
    private let captionLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.white.withAlphaComponent(0.2)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .white
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        captionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        valueLabel.font = .systemFont(ofSize: 15, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7

        let texts = UIStackView.make(.vertical, spacing: 0, [captionLabel, valueLabel])
        let content = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [iconView, texts])
        addSubview(content)
        content.pinEdges(to: self, insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func configure(symbol: String, caption: String, value: String) {
        iconView.image = UIImage(systemName: symbol)
        captionLabel.text = caption
        valueLabel.text = value
    }
}

private final class RecapBarRow: UIView {
    init(category: ActivityCategory, minutes: Int, fraction: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: category.icon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .white
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let title = UILabel()
        title.text = category.title
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .white
        let duration = UILabel()
        duration.text = formatDuration(minutes: minutes)
        duration.font = .systemFont(ofSize: 15)
        duration.textColor = UIColor.white.withAlphaComponent(0.9)
        let labels = UIStackView.make(.horizontal, spacing: 6, alignment: .center, [icon, title, .spacer(), duration])

        let track = UIView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        track.layer.cornerRadius = 3
        let fill = UIView()
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.backgroundColor = .white
        fill.layer.cornerRadius = 3
        track.addSubview(fill)

        let stack = UIStackView.make(.vertical, spacing: 4, [labels, track])
        addSubview(stack)
        stack.pinEdges(to: self)

        NSLayoutConstraint.activate([
            track.heightAnchor.constraint(equalToConstant: 6),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: min(max(fraction, 0), 1)),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
