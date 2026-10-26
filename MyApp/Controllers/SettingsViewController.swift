import UIKit
import SwiftData
import SwiftUI

// MARK: - Settings
final class SettingsViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case goals, preferences, developer, data

        var title: String {
            switch self {
            case .goals: "Weekly Goals (Minutes)"
            case .preferences: "Preferences"
            case .developer: "Developer Tools"
            case .data: "Data Management"
            }
        }
    }

    private enum ActionRow: Int, CaseIterable { case resetWeek, eraseAll }

    private let store = DataStore.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var goalRows: [ActivityCategory: GoalStepperRow] = [:]

    private lazy var goalCells: [ViewContainerCell] = ActivityCategory.allCases.map { category in
        let row = GoalStepperRow(category: category)
        row.onChange = { [weak self] minutes in
            guard let self else { return }
            self.store.setGoal(minutes, for: category, from: self)
        }
        goalRows[category] = row
        return ViewContainerCell(hosting: row, insets: NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private lazy var themeCell: ViewContainerCell = {
        let icon = UIImageView.symbol("paintbrush.fill", color: .systemPink)
        let label = UILabel.make("Theme", font: .preferred(.body))
        let control = UISegmentedControl(items: AppTheme.allCases.map(\.title))
        control.selectedSegmentIndex = AppTheme.current.rawValue
        control.addAction(UIAction { _ in
            AppTheme.current = AppTheme(rawValue: control.selectedSegmentIndex) ?? .system
            Haptics.light()
        }, for: .valueChanged)
        control.accessibilityLabel = "Theme"
        control.accessibilityIdentifier = AccessibilityID.Settings.themeControl
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, label, .spacer(), control])
        return ViewContainerCell(hosting: row, insets: NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Settings.screen
        tableView.accessibilityIdentifier = AccessibilityID.Settings.table

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")
        view.addSubview(tableView)
        tableView.pinEdges(to: view)

        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        refreshGoals()
    }

    @objc private func dataDidChange(_ notification: Notification) {
        guard (notification.object as AnyObject?) !== self else { return }
        refreshGoals()
    }

    private func refreshGoals() {
        _ = goalCells
        let goals = store.goals
        for (category, row) in goalRows {
            row.setMinutes(goals.target(for: category))
        }
    }

    // MARK: Actions
    private func replayOnboarding() {
        Haptics.light()
        AppRouter.hasCompletedOnboarding = false
        AppRouter.transition(to: OnboardingViewController(), in: view.window)
    }

    private func confirmResetWeek() {
        confirm(
            title: "Reset This Week?",
            message: "Deletes everything logged since the start of this week.",
            action: "Reset"
        ) { [weak self] in
            self?.resetCurrentWeek()
        }
    }

    private func confirmEraseAll() {
        confirm(
            title: "Erase All Data?",
            message: "Deletes all logged time, rituals and ideas, and restores default goals. This can't be undone.",
            action: "Erase"
        ) { [weak self] in
            self?.eraseAllData()
        }
    }

    private func confirm(title: String, message: String, action: String, handler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: action, style: .destructive) { _ in handler() })
        present(alert, animated: true)
    }

    private func resetCurrentWeek() {
        let weekStart = Calendar.current.weekInterval(containing: .now).start
        for log in store.logs where log.date >= weekStart {
            store.context.delete(log)
        }
        store.commit(from: self)
        Haptics.success()
    }

    private func eraseAllData() {
        store.deleteAll(FetchDescriptor<ActivityLog>())
        store.deleteAll(FetchDescriptor<Ritual>())
        store.deleteAll(FetchDescriptor<Idea>())
        for goal in store.goals {
            goal.targetMinutes = goal.category.defaultGoalMinutes
        }
        store.commit()
        DataBootstrap.syncGoalStorage(context: store.context)
        Haptics.success()
    }
}

// MARK: - Table Data Source & Delegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .goals: goalCells.count
        case .preferences, .developer: 1
        case .data: ActionRow.allCases.count
        case nil: 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .goals:
            return goalCells[indexPath.row]
        case .preferences:
            return themeCell
        case .developer:
            return actionCell(
                at: indexPath,
                title: "Replay Onboarding",
                symbol: "play.circle.fill",
                color: .systemPink,
                identifier: AccessibilityID.Settings.replayOnboarding
            )
        case .data:
            switch ActionRow(rawValue: indexPath.row) {
            case .resetWeek:
                return actionCell(
                    at: indexPath,
                    title: "Reset Current Week",
                    symbol: "arrow.counterclockwise.circle.fill",
                    color: .systemRed,
                    identifier: AccessibilityID.Settings.resetWeek
                )
            case .eraseAll, nil:
                return actionCell(
                    at: indexPath,
                    title: "Erase All Data",
                    symbol: "trash.fill",
                    color: .systemRed,
                    identifier: AccessibilityID.Settings.eraseAll
                )
            }
        case nil:
            return UITableViewCell()
        }
    }

    private func actionCell(at indexPath: IndexPath, title: String, symbol: String, color: UIColor, identifier: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
        cell.accessibilityIdentifier = identifier
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.textProperties.color = color
        content.image = UIImage(systemName: symbol)
        content.imageProperties.tintColor = color
        cell.contentConfiguration = content
        cell.accessibilityTraits = .button
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        [Section.developer.rawValue, Section.data.rawValue].contains(indexPath.section)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .developer:
            replayOnboarding()
        case .data:
            ActionRow(rawValue: indexPath.row) == .resetWeek ? confirmResetWeek() : confirmEraseAll()
        default:
            break
        }
    }
}

// MARK: - Goal Stepper Row
final class GoalStepperRow: UIView {
    var onChange: ((Int) -> Void)?

    private let category: ActivityCategory
    private let valueLabel = UILabel.make(font: .preferred(.body), color: .secondaryLabel)
    private let stepper = UIStepper()

    init(category: ActivityCategory, minimum: Double = 15, maximum: Double = 600) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        stepper.minimumValue = minimum
        stepper.maximumValue = maximum
        stepper.stepValue = 15
        stepper.accessibilityLabel = "\(category.title) weekly goal"
        stepper.accessibilityIdentifier = AccessibilityID.Settings.goalStepper(category)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let minutes = Int(self.stepper.value)
            self.updateLabel(minutes)
            self.onChange?(minutes)
        }, for: .valueChanged)

        let icon = UIImageView.symbol(category.icon, color: category.color)
        let title = UILabel.make(category.title, font: .preferred(.body))
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, title, .spacer(), valueLabel, stepper])
        addSubview(row)
        row.pinEdges(to: self)
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 26)])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMinutes(_ minutes: Int) {
        stepper.value = Double(minutes)
        updateLabel(minutes)
    }

    private func updateLabel(_ minutes: Int) {
        valueLabel.text = "\(minutes)m"
        stepper.accessibilityValue = formatDuration(minutes: minutes)
    }
}

#Preview {
    UINavigationController(rootViewController: SettingsViewController())
}
