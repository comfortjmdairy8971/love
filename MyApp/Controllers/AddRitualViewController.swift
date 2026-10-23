import UIKit

// MARK: - Add Ritual Sheet
final class AddRitualViewController: UIViewController {
    private let store = DataStore.shared

    private let titleField = UITextField()
    private let frequencyControl = UISegmentedControl(items: RitualFrequency.allCases.map(\.title))
    private var iconButtons: [UIButton] = []
    private var selectedIcon = Ritual.defaultIcon
    private lazy var addButton = UIBarButtonItem(title: "Add", primaryAction: UIAction { [weak self] _ in self?.add() })

    private var trimmedTitle: String {
        (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Ritual"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        if #available(iOS 26.0, *) {
            addButton.style = .prominent
        } else {
            // Fallback on earlier versions
        }
        addButton.isEnabled = false
        navigationItem.rightBarButtonItem = addButton
        setUpLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        titleField.becomeFirstResponder()
    }

    private func setUpLayout() {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.placeholder = "e.g. Friday Date Night"
        titleField.font = .preferredFont(forTextStyle: .body)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.clearButtonMode = .whileEditing
        titleField.returnKeyType = .done
        titleField.delegate = self
        titleField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.addButton.isEnabled = !self.trimmedTitle.isEmpty
        }, for: .editingChanged)
        let fieldCard = UIView()
        fieldCard.translatesAutoresizingMaskIntoConstraints = false
        fieldCard.applyCardStyle(cornerRadius: 12)
        fieldCard.addSubview(titleField)
        titleField.pinEdges(to: fieldCard, insets: NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

        frequencyControl.translatesAutoresizingMaskIntoConstraints = false
        frequencyControl.selectedSegmentIndex = RitualFrequency.allCases.firstIndex(of: .weekly) ?? 0

        let iconTitle = UILabel.make("ICON", font: .preferred(.footnote), color: .secondaryLabel)
        let content = UIStackView.make(.vertical, spacing: 16, [
            fieldCard,
            labeled("REPEATS", frequencyControl),
            iconTitle,
            makeIconGrid(),
        ])
        content.setCustomSpacing(8, after: iconTitle)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func labeled(_ title: String, _ view: UIView) -> UIView {
        let label = UILabel.make(title, font: .preferred(.footnote), color: .secondaryLabel)
        return UIStackView.make(.vertical, spacing: 8, [label, view])
    }

    private func makeIconGrid() -> UIView {
        let columns = 6
        let icons = Ritual.iconChoices
        let rows = stride(from: 0, to: icons.count, by: columns).map { start in
            let buttons = icons[start..<min(start + columns, icons.count)].map(makeIconButton)
            return UIStackView.make(.horizontal, spacing: 10, distribution: .fillEqually, buttons)
        }
        updateIconSelection()
        return UIStackView.make(.vertical, spacing: 10, rows)
    }

    private func makeIconButton(_ symbol: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        config.background.cornerRadius = 10
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.accessibilityLabel = symbol.replacingOccurrences(of: ".", with: " ")
        button.addAction(UIAction { [weak self] _ in
            self?.selectedIcon = symbol
            self?.updateIconSelection()
            Haptics.light()
        }, for: .touchUpInside)
        iconButtons.append(button)
        return button
    }

    private func updateIconSelection() {
        for (button, symbol) in zip(iconButtons, Ritual.iconChoices) {
            let isSelected = symbol == selectedIcon
            button.configuration?.baseBackgroundColor = isSelected ? .systemPink : UIColor.systemPink.withAlphaComponent(0.1)
            button.configuration?.baseForegroundColor = isSelected ? .white : .systemPink
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func add() {
        guard !trimmedTitle.isEmpty else { return }
        let frequency = RitualFrequency.allCases[frequencyControl.selectedSegmentIndex]
        store.insert(Ritual(title: trimmedTitle, icon: selectedIcon, frequency: frequency))
        Haptics.success()
        dismiss(animated: true)
    }
}

extension AddRitualViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
