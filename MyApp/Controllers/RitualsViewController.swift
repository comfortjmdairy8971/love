import UIKit
import SwiftUI

// MARK: - Rituals (with Ideas segment)
final class RitualsViewController: UIViewController {
    private enum Mode: Int { case rituals, ideas }
    private enum Section { case active, suggestions }

    private struct Suggestion {
        let title: String
        let icon: String
        let frequency: RitualFrequency

        static var all: [Suggestion] {
            [
                .init(title: String(localized: "Friday Date Night"), icon: "moon.stars.fill", frequency: .weekly),
                .init(title: String(localized: "Morning coffee together"), icon: "cup.and.saucer.fill", frequency: .daily),
                .init(title: String(localized: "Sunday walk"), icon: "figure.walk", frequency: .weekly),
                .init(title: String(localized: "Monthly adventure"), icon: "map.fill", frequency: .monthly),
            ]
        }
    }

    private let store = DataStore.shared
    private var rituals: [Ritual] = []
    private var suggestions: [Suggestion] = []
    private var sections: [Section] { suggestions.isEmpty ? [.active] : [.active, .suggestions] }

    private let segmentedControl = UISegmentedControl(items: [
        String(localized: "Rituals"),
        String(localized: "Ideas"),
    ])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let ideasViewController = IdeasViewController()
    private lazy var addButton = UIBarButtonItem(
        systemItem: .add,
        primaryAction: UIAction { [weak self] _ in self?.presentAddRitual() }
    )
    private lazy var emptyCell = ViewContainerCell(hosting: EmptyStateView(
        symbol: "flame",
        title: String(localized: "No rituals yet"),
        message: String(localized: "Rituals are the little traditions you repeat. Check one off each time to grow its streak.")
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String(localized: "Rituals & Ideas")
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Rituals.screen
        addButton.accessibilityLabel = String(localized: "Add New Ritual")
        addButton.accessibilityIdentifier = AccessibilityID.Rituals.addButton
        segmentedControl.accessibilityIdentifier = AccessibilityID.Rituals.modeControl
        tableView.accessibilityIdentifier = AccessibilityID.Rituals.table
        navigationItem.rightBarButtonItem = addButton

        setUpLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Completion state depends on the current day/week/month.
        tableView.reloadData()
    }

    private func setUpLayout() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = Mode.rituals.rawValue
        segmentedControl.addAction(UIAction { [weak self] _ in self?.modeChanged() }, for: .valueChanged)
        view.addSubview(segmentedControl)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RitualCell.self, forCellReuseIdentifier: RitualCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
        view.addSubview(tableView)

        addChild(ideasViewController)
        let ideasView = ideasViewController.view!
        ideasView.translatesAutoresizingMaskIntoConstraints = false
        ideasView.isHidden = true
        view.addSubview(ideasView)
        ideasViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            ideasView.topAnchor.constraint(equalTo: tableView.topAnchor),
            ideasView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            ideasView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            ideasView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    private func modeChanged() {
        let showsIdeas = segmentedControl.selectedSegmentIndex == Mode.ideas.rawValue
        tableView.isHidden = showsIdeas
        ideasViewController.view.isHidden = !showsIdeas
        navigationItem.rightBarButtonItem = showsIdeas ? nil : addButton
        if !showsIdeas { view.endEditing(true) }
    }

    // MARK: Data
    @objc private func dataDidChange(_ notification: Notification) {
        guard (notification.object as AnyObject?) !== self else { return }
        reloadData()
    }

    private func reloadData() {
        rituals = store.rituals
        let existing = Set(rituals.map { $0.title.lowercased() })
        suggestions = Suggestion.all.filter { !existing.contains($0.title.lowercased()) }
        tableView.reloadData()
    }

    private func reloadAnimated() {
        UIView.transition(with: tableView, duration: 0.25, options: .transitionCrossDissolve) {
            self.reloadData()
        }
    }

    // MARK: Actions
    private func toggle(_ ritual: Ritual) {
        ritual.toggleCompletion()
        store.commit(from: self)
        let isDone = ritual.isCompleted()
        isDone ? Haptics.success() : Haptics.light()

        guard let row = rituals.firstIndex(where: { $0 === ritual }) else { return }
        let indexPath = IndexPath(row: row, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
        if isDone { (tableView.cellForRow(at: indexPath) as? RitualCell)?.playCompletionBounce() }
    }

    private func addSuggestion(_ suggestion: Suggestion) {
        store.insert(Ritual(title: suggestion.title, icon: suggestion.icon, frequency: suggestion.frequency), from: self)
        Haptics.light()
        reloadAnimated()
    }

    private func delete(_ ritual: Ritual) {
        store.delete(ritual, from: self)
        reloadAnimated()
    }

    private func presentAddRitual() {
        let addViewController = AddRitualViewController()
        let navigationController = UINavigationController(rootViewController: addViewController)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }
}

// MARK: - Table Data Source & Delegate
extension RitualsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .active: max(rituals.count, 1)
        case .suggestions: suggestions.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .active: rituals.isEmpty ? nil : String(localized: "Active Streaks")
        case .suggestions: String(localized: "Suggestions")
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section] == .active && !rituals.isEmpty
            ? String(localized: "Missing a whole period resets the streak.")
            : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .active:
            guard !rituals.isEmpty else { return emptyCell }
            let ritual = rituals[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: RitualCell.reuseID, for: indexPath) as! RitualCell
            cell.configure(with: ritual)
            cell.onToggle = { [weak self, weak ritual] in
                guard let ritual else { return }
                self?.toggle(ritual)
            }
            return cell

        case .suggestions:
            let suggestion = suggestions[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            var content = UIListContentConfiguration.valueCell()
            content.text = suggestion.title
            content.secondaryText = suggestion.frequency.title
            content.image = UIImage(systemName: suggestion.icon)
            content.imageProperties.tintColor = .brandAccent
            cell.contentConfiguration = content
            let plus = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
            plus.tintColor = .brandAccent
            cell.accessoryView = plus
            cell.accessibilityHint = "Adds this ritual"
            return cell
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        sections[indexPath.section] == .suggestions
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard sections[indexPath.section] == .suggestions else { return }
        addSuggestion(suggestions[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard sections[indexPath.section] == .active, !rituals.isEmpty else { return nil }
        let ritual = rituals[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { [weak self] _, _, completion in
            self?.delete(ritual)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

#Preview {
    UINavigationController(rootViewController: RitualsViewController())
}
