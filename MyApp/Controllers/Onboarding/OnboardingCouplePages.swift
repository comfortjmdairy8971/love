import UIKit

// MARK: - Step 2: Partner Names
final class OnboardingNamesViewController: OnboardingPageViewController {
    private let yourNameField = RoundedTextField(placeholder: String(localized: "Your Name"))
    private let partnerNameField = RoundedTextField(placeholder: String(localized: "Partner's Name"))

    init() {
        super.init(
            buttonTitle: String(localized: "Continue"),
            pageIdentifier: AccessibilityID.Onboarding.namesPage,
            buttonIdentifier: AccessibilityID.Onboarding.namesContinueButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = makeScrollingStack(
            title: String(localized: "What are your names?"),
            subtitle: String(localized: "Shown together on your home screen."),
            verticallyCentered: true
        )

        let profile = CoupleProfile.current
        yourNameField.text = profile.yourName
        yourNameField.textContentType = .givenName
        yourNameField.returnKeyType = .next
        yourNameField.accessibilityIdentifier = AccessibilityID.Onboarding.yourNameField
        partnerNameField.text = profile.partnerName
        partnerNameField.returnKeyType = .done
        partnerNameField.accessibilityIdentifier = AccessibilityID.Onboarding.partnerNameField

        for field in [yourNameField, partnerNameField] {
            field.delegate = self
            field.addAction(UIAction { [weak self] _ in self?.updateContinueButton() }, for: .editingChanged)
        }

        let heart = UIImageView.symbol("heart.fill", style: .title3, color: .brandAccent)
        heart.isAccessibilityElement = false
        let fields = UIStackView.make(.vertical, spacing: 12, alignment: .center, [yourNameField, heart, partnerNameField])
        NSLayoutConstraint.activate([
            yourNameField.widthAnchor.constraint(equalTo: fields.widthAnchor),
            partnerNameField.widthAnchor.constraint(equalTo: fields.widthAnchor),
        ])
        stack.addArrangedSubview(fields)
        updateContinueButton()
    }

    private var hasBothNames: Bool {
        !(yourNameField.text ?? "").trimmed.isEmpty && !(partnerNameField.text ?? "").trimmed.isEmpty
    }

    private func updateContinueButton() {
        primaryButton.isEnabled = hasBothNames
    }

    func save() {
        CoupleProfile.update { profile in
            profile.yourName = yourNameField.text ?? ""
            profile.partnerName = partnerNameField.text ?? ""
        }
    }
}

extension OnboardingNamesViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === yourNameField {
            partnerNameField.becomeFirstResponder()
        } else if hasBothNames {
            textField.resignFirstResponder()
            onAction?()
        } else {
            yourNameField.becomeFirstResponder()
        }
        return false
    }
}

// MARK: - Anniversary
final class OnboardingAnniversaryViewController: OnboardingPageViewController {
    private let datePicker = UIDatePicker()
    private let summaryLabel = UILabel.make(
        font: .preferred(.title2, weight: .bold, design: .rounded),
        color: .brandAccent,
        lines: 0,
        alignment: .center
    )
    private let detailLabel = UILabel.make(
        font: .preferred(.subheadline),
        color: .secondaryLabel,
        lines: 0,
        alignment: .center
    )

    init() {
        super.init(
            buttonTitle: String(localized: "Continue"),
            pageIdentifier: AccessibilityID.Onboarding.anniversaryPage,
            buttonIdentifier: AccessibilityID.Onboarding.anniversaryContinueButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = makeScrollingStack(
            title: String(localized: "When did your story begin?"),
            subtitle: String(localized: "We'll celebrate every day since."),
            verticallyCentered: true
        )

        let sinceLabel = UILabel.make(String(localized: "Together since"), font: .preferred(.body))
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = .now
        datePicker.tintColor = .brandAccent
        datePicker.date = CoupleProfile.current.startDate ?? .now
        datePicker.accessibilityLabel = String(localized: "Together since")
        datePicker.accessibilityIdentifier = AccessibilityID.Onboarding.anniversaryPicker
        datePicker.addAction(UIAction { [weak self] _ in self?.updateSummary() }, for: .valueChanged)

        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [sinceLabel, .spacer(), datePicker])
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.applyCardStyle()
        card.addSubview(row)
        row.pinEdges(to: card, insets: .all(16))

        let summary = UIStackView.make(.vertical, spacing: 6, alignment: .center, [summaryLabel, detailLabel])
        stack.addArrangedSubview(card)
        stack.addArrangedSubview(summary)
        updateSummary()
    }

    private func updateSummary() {
        let preview = CoupleProfile(yourName: "", partnerName: "", startDate: datePicker.date, howWeMet: "")
        if let duration = preview.durationText(), let days = preview.daysTogether() {
            summaryLabel.text = String(localized: "Together for \(duration) 💞")
            detailLabel.text = days == 1
                ? String(localized: "1 day and counting")
                : String(localized: "\(days.formatted()) days and counting")
            detailLabel.isHidden = false
        } else {
            summaryLabel.text = String(localized: "A brand-new story — how exciting! ✨")
            detailLabel.isHidden = true
        }
    }

    func save() {
        CoupleProfile.update { $0.startDate = datePicker.date }
    }
}

// MARK: - Step 5: How You Met
final class OnboardingHowWeMetViewController: OnboardingPageViewController {
    private let textView = UITextView()
    private let placeholderLabel = UILabel.make(
        String(localized: "We met at a friend's birthday and talked until sunrise…"),
        font: .preferred(.body),
        color: .tertiaryLabel,
        lines: 0
    )
    private let counterLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel, alignment: .right)

    init() {
        super.init(
            buttonTitle: String(localized: "Next"),
            pageIdentifier: AccessibilityID.Onboarding.howWeMetPage,
            buttonIdentifier: AccessibilityID.Onboarding.howWeMetNextButton
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = makeScrollingStack(
            title: String(localized: "How your story began"),
            subtitle: String(localized: "First look, first spark — however it started.")
        )

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .preferred(.body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.layer.cornerRadius = 14
        textView.layer.cornerCurve = .continuous
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.text = CoupleProfile.current.howWeMet
        textView.delegate = self
        textView.accessibilityLabel = String(localized: "How your story began")
        textView.accessibilityIdentifier = AccessibilityID.Onboarding.howWeMetText

        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            textView.heightAnchor.constraint(equalToConstant: 140),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 17),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor, constant: -34),
        ])

        stack.addArrangedSubview(UIStackView.make(.vertical, spacing: 6, [textView, counterLabel]))
        updateTextState()
    }

    private func updateTextState() {
        placeholderLabel.isHidden = !textView.text.isEmpty
        counterLabel.text = "\(textView.text.count)/\(CoupleProfile.howWeMetCharacterLimit)"
    }

    func save() {
        CoupleProfile.update { $0.howWeMet = textView.text }
    }
}

extension OnboardingHowWeMetViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= CoupleProfile.howWeMetCharacterLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        updateTextState()
    }
}
