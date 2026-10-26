import UIKit

// MARK: - Page Base
/// A page with arbitrary content above a full-width capsule action button.
class OnboardingPageViewController: UIViewController {
    var onAction: (() -> Void)?

    let contentView = UIView()
    private let buttonTitle: String
    private let pageIdentifier: String
    private let buttonIdentifier: String

    init(buttonTitle: String, pageIdentifier: String, buttonIdentifier: String) {
        self.buttonTitle = buttonTitle
        self.pageIdentifier = pageIdentifier
        self.buttonIdentifier = buttonIdentifier
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = pageIdentifier

        let button = UIButton(configuration: .capsule(title: buttonTitle, color: .systemPink))
        button.accessibilityIdentifier = buttonIdentifier
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        view.addSubview(button)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: guide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            contentView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            contentView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -20),

            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -56),
        ])
    }

    /// Embeds a vertically scrolling stack that starts with a title and subtitle.
    func makeScrollingStack(title: String, subtitle: String) -> UIStackView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        contentView.addSubview(scrollView)
        scrollView.pinEdges(to: contentView)

        let titleLabel = UILabel.make(title, font: .preferred(.title1, weight: .bold), lines: 0)
        titleLabel.accessibilityTraits = .header
        let subtitleLabel = UILabel.make(subtitle, font: .preferred(.subheadline), color: .secondaryLabel, lines: 0)
        let header = UIStackView.make(.vertical, spacing: 8, [titleLabel, subtitleLabel])

        let stack = UIStackView.make(.vertical, spacing: 20, [header])
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 0, bottom: 8, trailing: 0)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        return stack
    }
}

// MARK: - Step 1: Welcome
final class OnboardingWelcomeViewController: OnboardingPageViewController {
    private let heartView = UIImageView(image: UIImage(systemName: "heart.circle.fill"))

    init() {
        super.init(
            buttonTitle: "Get Started",
            pageIdentifier: AccessibilityID.Onboarding.welcomePage,
            buttonIdentifier: AccessibilityID.Onboarding.getStartedButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        heartView.translatesAutoresizingMaskIntoConstraints = false
        heartView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 110)
        heartView.tintColor = .systemPink
        heartView.layer.shadowColor = UIColor.systemPink.cgColor
        heartView.layer.shadowOpacity = 0.35
        heartView.layer.shadowRadius = 24
        heartView.layer.shadowOffset = CGSize(width: 0, height: 10)
        heartView.isAccessibilityElement = false

        let titleLabel = UILabel.make("Nurture Your Relationship", font: .preferred(.largeTitle, weight: .bold), lines: 0, alignment: .center)
        titleLabel.accessibilityTraits = .header
        let subtitleLabel = UILabel.make(
            "Set weekly goals for quality time, track meaningful connection, and build recurring rituals together.",
            font: .preferred(.body),
            color: .secondaryLabel,
            lines: 0,
            alignment: .center
        )
        let texts = UIStackView.make(.vertical, spacing: 12, [titleLabel, subtitleLabel])
        let stack = UIStackView.make(.vertical, spacing: 24, alignment: .center, [heartView, texts])
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
            texts.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startPulse),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPulse()
    }

    @objc private func startPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.08
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        heartView.layer.add(pulse, forKey: "pulse")
    }
}

// MARK: - Step 2: Goals
final class OnboardingGoalsViewController: OnboardingPageViewController {
    private var minutesByCategory: [ActivityCategory: Int] = [:]

    init() {
        super.init(
            buttonTitle: "Continue",
            pageIdentifier: AccessibilityID.Onboarding.goalsPage,
            buttonIdentifier: AccessibilityID.Onboarding.continueButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func minutes(for category: ActivityCategory) -> Int {
        minutesByCategory[category] ?? DataStore.shared.targetMinutes(for: category)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = makeScrollingStack(
            title: "Set Your Weekly Goals",
            subtitle: "Choose how many minutes per week you want to aim for in each area."
        )
        for category in ActivityCategory.allCases {
            let card = GoalSetupCardView(category: category, minutes: minutes(for: category))
            card.onChange = { [weak self] minutes in
                self?.minutesByCategory[category] = minutes
                UserDefaults.standard.set(Double(minutes), forKey: category.goalStorageKey)
            }
            stack.addArrangedSubview(card)
        }
    }
}

private final class GoalSetupCardView: UIView {
    var onChange: ((Int) -> Void)?

    private let category: ActivityCategory
    private let valueLabel: UILabel
    private let stepper = UIStepper()

    init(category: ActivityCategory, minutes: Int) {
        self.category = category
        valueLabel = UILabel.make(font: .preferred(.subheadline, weight: .semibold), color: category.color)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle()

        stepper.minimumValue = 15
        stepper.maximumValue = 600
        stepper.stepValue = 15
        stepper.value = Double(minutes)
        stepper.accessibilityLabel = "\(category.title) goal"
        stepper.accessibilityIdentifier = AccessibilityID.Onboarding.goalStepper(category)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let minutes = Int(self.stepper.value)
            self.updateLabel(minutes)
            Haptics.light()
            self.onChange?(minutes)
        }, for: .valueChanged)

        let icon = IconTileView(symbol: category.icon, color: category.color, side: 36, cornerRadius: 9)
        let texts = UIStackView.make(.vertical, spacing: 2, [
            UILabel.make(category.title, font: .preferred(.headline)),
            valueLabel,
        ])
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, texts, .spacer(), stepper])
        addSubview(row)
        row.pinEdges(to: self, insets: .all(16))
        updateLabel(minutes)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateLabel(_ minutes: Int) {
        valueLabel.text = formatDuration(minutes: minutes) + " / week"
        stepper.accessibilityValue = formatDuration(minutes: minutes)
    }
}

// MARK: - Step 3: Rituals
struct RitualPreset {
    let slug: String
    let title: String
    let icon: String
    let frequency: RitualFrequency

    static let all: [RitualPreset] = [
        .init(slug: "fridayDinner", title: "Friday Dinner Out", icon: "fork.knife", frequency: .weekly),
        .init(slug: "sundayWalk", title: "Sunday Morning Walk", icon: "figure.walk", frequency: .weekly),
        .init(slug: "weeklyCheckIn", title: "Weekly Check-in", icon: "bubble.left.and.bubble.right.fill", frequency: .weekly),
        .init(slug: "phoneFreeEvening", title: "Phone-Free Evening", icon: "iphone.slash", frequency: .weekly),
    ]
}

final class OnboardingRitualsViewController: OnboardingPageViewController {
    private let maxSelections = 2
    private var chips: [RitualPresetChipView] = []
    private let captionLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel)

    var selectedPresets: [RitualPreset] {
        chips.filter(\.isSelected).map(\.preset)
    }

    init() {
        super.init(
            buttonTitle: "Start Tracking",
            pageIdentifier: AccessibilityID.Onboarding.ritualsPage,
            buttonIdentifier: AccessibilityID.Onboarding.startTrackingButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = makeScrollingStack(
            title: "Pick 1–2 Initial Rituals",
            subtitle: "Recurring habits keep connection consistent week after week."
        )
        chips = RitualPreset.all.map { preset in
            let chip = RitualPresetChipView(preset: preset)
            chip.addAction(UIAction { [weak self, weak chip] _ in
                guard let chip else { return }
                self?.toggle(chip)
            }, for: .touchUpInside)
            return chip
        }
        stack.addArrangedSubview(UIStackView.make(.vertical, spacing: 12, chips))
        stack.addArrangedSubview(captionLabel)
        updateCaption()
    }

    private func toggle(_ chip: RitualPresetChipView) {
        guard chip.isSelected || selectedPresets.count < maxSelections else {
            chip.shake()
            return
        }
        Haptics.light()
        chip.setSelected(!chip.isSelected, animated: true)
        updateCaption()
    }

    private func updateCaption() {
        let count = selectedPresets.count
        captionLabel.text = count == 0 ? "You can always add rituals later." : "\(count) of \(maxSelections) selected"
    }
}

private final class RitualPresetChipView: UIControl {
    let preset: RitualPreset

    private let iconTile: IconTileView
    private let titleLabel: UILabel
    private let frequencyLabel: UILabel
    private let checkmark = UIImageView()

    init(preset: RitualPreset) {
        self.preset = preset
        iconTile = IconTileView(symbol: preset.icon, color: .systemPink, side: 34, cornerRadius: 9, pointSize: 14)
        titleLabel = UILabel.make(preset.title, font: .preferred(.headline))
        frequencyLabel = UILabel.make(preset.frequency.title, font: .preferred(.caption1))
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        checkmark.setContentHuggingPriority(.required, for: .horizontal)

        let texts = UIStackView.make(.vertical, spacing: 2, [titleLabel, frequencyLabel])
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [iconTile, texts, .spacer(), checkmark])
        row.isUserInteractionEnabled = false
        addSubview(row)
        row.pinEdges(to: self, insets: .all(14))

        isAccessibilityElement = true
        accessibilityLabel = "\(preset.title), \(preset.frequency.title)"
        accessibilityIdentifier = AccessibilityID.Onboarding.ritualPreset(preset.slug)
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        isSelected = selected
        guard animated else { return applyStyle() }
        UIView.animate(springDuration: 0.3, bounce: 0.3) { self.applyStyle() }
    }

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -8, 8, -5, 5, 0]
        animation.duration = 0.35
        layer.add(animation, forKey: "shake")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func applyStyle() {
        let pink = UIColor.systemPink
        backgroundColor = isSelected ? pink : .secondarySystemGroupedBackground
        layer.borderColor = pink.withAlphaComponent(isSelected ? 0 : 0.25).cgColor
        iconTile.configure(
            symbol: preset.icon,
            color: isSelected ? .white : pink,
            symbolColor: isSelected ? pink : .white
        )
        titleLabel.textColor = isSelected ? .white : .label
        frequencyLabel.textColor = isSelected ? UIColor.white.withAlphaComponent(0.8) : .secondaryLabel
        checkmark.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkmark.tintColor = isSelected ? .white : .tertiaryLabel
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
