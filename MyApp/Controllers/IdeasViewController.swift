import UIKit

// MARK: - Ideas (shown inside the Rituals tab)
final class IdeasViewController: UIViewController {
    private enum Section { case controls, empty, todo, done }

    private let store = DataStore.shared
    private var ideas: [Idea] = []
    private var selectedCategory: IdeaCategory = .date

    private var categoryIdeas: [Idea] { ideas.filter { $0.categoryRaw == selectedCategory.rawValue } }
    private var openIdeas: [Idea] = []
    private var doneIdeas: [Idea] = []
    private var sections: [Section] {
        var result: [Section] = [.controls]
        if openIdeas.isEmpty && doneIdeas.isEmpty { result.append(.empty) }
        if !openIdeas.isEmpty { result.append(.todo) }
        if !doneIdeas.isEmpty { result.append(.done) }
        return result
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let categoryControl = UISegmentedControl(items: IdeaCategory.allCases.map(\.title))
    private let inputField = UITextField()
    private let addButton = UIButton(type: .system)

    private lazy var categoryCell: ViewContainerCell = {
        let cell = ViewContainerCell(hosting: categoryControl, insets: .zero)
        cell.backgroundConfiguration = .clear()
        return cell
    }()
    private lazy var inputCell = ViewContainerCell(
        hosting: UIStackView.make(.horizontal, spacing: 8, alignment: .center, [inputField, addButton])
    )

    private var trimmedInput: String {
        (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setUpControls()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "IdeaCell")
        view.addSubview(tableView)
        tableView.pinEdges(to: view)

        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        reloadData()
    }

    private func setUpControls() {
        categoryControl.translatesAutoresizingMaskIntoConstraints = false
        categoryControl.selectedSegmentIndex = 0
        categoryControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.selectedCategory = IdeaCategory.allCases[self.categoryControl.selectedSegmentIndex]
            self.updateInputAppearance()
            self.reloadAnimated()
        }, for: .valueChanged)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.font = .preferredFont(forTextStyle: .body)
        inputField.adjustsFontForContentSizeCategory = true
        inputField.returnKeyType = .done
        inputField.delegate = self
        inputField.addAction(UIAction { [weak self] _ in self?.updateInputAppearance() }, for: .editingChanged)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(textStyle: .title2), forImageIn: .normal)
        addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.accessibilityLabel = "Add Idea"
        addButton.addAction(UIAction { [weak self] _ in self?.addIdea() }, for: .touchUpInside)
        updateInputAppearance()
    }

    private func updateInputAppearance() {
        inputField.placeholder = selectedCategory.placeholder
        addButton.isEnabled = !trimmedInput.isEmpty
        addButton.tintColor = trimmedInput.isEmpty ? .tertiaryLabel : selectedCategory.color
    }

    // MARK: Data
    @objc private func dataDidChange(_ notification: Notification) {
        guard (notification.object as AnyObject?) !== self else { return }
        reloadData()
    }

    private func reloadData() {
        ideas = store.ideas
        openIdeas = categoryIdeas.filter { !$0.isDone }
        doneIdeas = categoryIdeas.filter(\.isDone)
        tableView.reloadData()
    }

    private func reloadAnimated() {
        UIView.transition(with: tableView, duration: 0.25, options: .transitionCrossDissolve) {
            self.reloadData()
        }
    }

    // MARK: Actions
    private func addIdea() {
        guard !trimmedInput.isEmpty else { return }
        store.insert(Idea(title: trimmedInput, category: selectedCategory), from: self)
        inputField.text = ""
        updateInputAppearance()
        Haptics.light()
        reloadAnimated()
    }

    private func toggle(_ idea: Idea) {
        idea.isDone.toggle()
        store.commit(from: self)
        Haptics.light()
        reloadAnimated()
    }

    private func delete(_ idea: Idea) {
        store.delete(idea, from: self)
        reloadAnimated()
    }

    private func idea(at indexPath: IndexPath) -> Idea? {
        switch sections[indexPath.section] {
        case .todo: openIdeas[indexPath.row]
        case .done: doneIdeas[indexPath.row]
        case .controls, .empty: nil
        }
    }
}

// MARK: - Table Data Source & Delegate
extension IdeasViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .controls: 2
        case .empty: 1
        case .todo: openIdeas.count
        case .done: doneIdeas.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .todo: "To Do"
        case .done: "Done"
        case .controls, .empty: nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .controls:
            return indexPath.row == 0 ? categoryCell : inputCell
        case .empty:
            let cell = ViewContainerCell(hosting: EmptyStateView(
                symbol: selectedCategory.icon,
                title: "No \(selectedCategory.title.lowercased()) ideas yet",
                message: "Add your first one above."
            ))
            cell.backgroundConfiguration = .clear()
            return cell
        case .todo, .done:
            guard let idea = idea(at: indexPath) else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(withIdentifier: "IdeaCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.image = UIImage(systemName: idea.isDone ? "checkmark.circle.fill" : "circle")
            content.imageProperties.tintColor = idea.isDone ? selectedCategory.color : .tertiaryLabel
            content.attributedText = NSAttributedString(string: idea.title, attributes: [
                .strikethroughStyle: idea.isDone ? NSUnderlineStyle.single.rawValue : 0,
                .foregroundColor: idea.isDone ? UIColor.secondaryLabel : UIColor.label,
                .font: UIFont.preferredFont(forTextStyle: .body),
            ])
            cell.contentConfiguration = content
            cell.accessibilityTraits = idea.isDone ? [.button, .selected] : .button
            cell.accessibilityHint = idea.isDone ? "Marks as not done" : "Marks as done"
            return cell
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        idea(at: indexPath) != nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let idea = idea(at: indexPath) else { return }
        toggle(idea)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let idea = idea(at: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.delete(idea)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension IdeasViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        addIdea()
        return false
    }
}
