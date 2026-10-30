import UIKit
import SwiftData
import SwiftUI

// MARK: - Settings
final class SettingsViewController: UIViewController {
    private enum Section: CaseIterable {
        case couple, sync, goals, preferences
        #if SHOW_DEVELOPER_TOOLS
        case developer
        #endif
        case data

        var title: String {
            switch self {
            case .couple: String(localized: "Our Story")
            case .sync: String(localized: "Partner Sync")
            case .goals: String(localized: "Weekly Goals (Minutes)")
            case .preferences: String(localized: "Preferences")
            #if SHOW_DEVELOPER_TOOLS
            case .developer: String(localized: "Developer Tools")
            #endif
            case .data: String(localized: "Data Management")
            }
        }

        static var visible: [Section] {
            allCases.filter { $0 != .sync || PartnerSyncService.isFeatureEnabled }
        }
    }

    private enum ActionRow: Int, CaseIterable { case resetWeek, eraseAll }

    private enum SyncRow: Int, CaseIterable {
        case status
        case primary
        case secondary
        case tertiary

        static func rows(isLinked: Bool) -> [SyncRow] {
            isLinked ? [.status, .primary, .secondary, .tertiary] : [.status, .primary, .secondary]
        }
    }

    private let store = DataStore.shared
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var goalRows: [ActivityCategory: GoalStepperRow] = [:]

    private lazy var howWeMetRow = HowWeMetRow { [weak self] in
        self?.presentStoryEditor()
    }

    private lazy var coupleCells: [ViewContainerCell] = {
        let profile = CoupleProfile.current
        let rowInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let yourName = CoupleTextRow(
            symbol: "person.fill",
            title: String(localized: "Your Name"),
            placeholder: String(localized: "Add name"),
            text: profile.yourName,
            identifier: AccessibilityID.Settings.yourNameField
        ) { text in CoupleProfile.update { $0.yourName = text } }
        let partnerName = CoupleTextRow(
            symbol: "heart.fill",
            title: String(localized: "Partner's Name"),
            placeholder: String(localized: "Add name"),
            text: profile.partnerName,
            identifier: AccessibilityID.Settings.partnerNameField
        ) { text in CoupleProfile.update { $0.partnerName = text } }
        return [yourName, partnerName, makeStartDateRow(profile.startDate), howWeMetRow].map {
            ViewContainerCell(hosting: $0, insets: rowInsets)
        }
    }()

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
        let icon = UIImageView.symbol("paintbrush.fill", color: .brandAccent)
        let control = UISegmentedControl(items: AppTheme.allCases.map(\.title))
        control.selectedSegmentIndex = AppTheme.current.rawValue
        control.addAction(UIAction { _ in
            AppTheme.current = AppTheme(rawValue: control.selectedSegmentIndex) ?? .system
            Haptics.light()
        }, for: .valueChanged)
        control.accessibilityLabel = String(localized: "Theme")
        control.accessibilityIdentifier = AccessibilityID.Settings.themeControl
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, control])
        return ViewContainerCell(hosting: row, insets: NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String(localized: "Settings")
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Settings.screen
        tableView.accessibilityIdentifier = AccessibilityID.Settings.table

        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")
        view.addSubview(tableView)
        tableView.pinEdges(to: view)

        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        if PartnerSyncService.isFeatureEnabled {
            NotificationCenter.default.addObserver(self, selector: #selector(syncDidChange), name: .partnerSyncDidChange, object: nil)
        }
        refreshGoals()
    }

    @objc private func dataDidChange(_ notification: Notification) {
        guard (notification.object as AnyObject?) !== self else { return }
        refreshGoals()
    }

    @objc private func syncDidChange() {
        guard let syncIndex = Section.visible.firstIndex(of: .sync) else { return }
        tableView.reloadSections(IndexSet(integer: syncIndex), with: .none)
    }

    private func refreshGoals() {
        _ = goalCells
        let goals = store.goals
        for (category, row) in goalRows {
            row.setMinutes(goals.target(for: category))
        }
    }

    private func makeStartDateRow(_ startDate: Date?) -> UIView {
        let icon = UIImageView.symbol("calendar", color: .brandAccent)
        let label = UILabel.make(String(localized: "Together Since"), font: .preferred(.body))
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.maximumDate = .now
        picker.tintColor = .brandAccent
        picker.date = startDate ?? .now
        picker.accessibilityLabel = String(localized: "Together Since")
        picker.accessibilityIdentifier = AccessibilityID.Settings.startDatePicker
        picker.addAction(UIAction { [weak picker] _ in
            guard let date = picker?.date else { return }
            CoupleProfile.update { $0.startDate = date }
        }, for: .valueChanged)
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 26)])
        return UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, label, .spacer(), picker])
    }

    // MARK: Actions
    #if SHOW_DEVELOPER_TOOLS
    private func replayOnboarding() {
        Haptics.light()
        AppRouter.hasCompletedOnboarding = false
        AppRouter.transition(to: OnboardingViewController(), in: view.window)
    }

    private func resetSampleRituals() {
        DataBootstrap.resetSeededRituals(context: store.context)
        store.commit(from: self)
        Haptics.success()
    }
    #endif

    private func confirmResetWeek() {
        confirm(
            title: String(localized: "Reset This Week?"),
            message: String(localized: "Deletes everything logged since the start of this week."),
            action: String(localized: "Reset")
        ) { [weak self] in
            self?.resetCurrentWeek()
        }
    }

    private func confirmEraseAll() {
        confirm(
            title: String(localized: "Erase All Data?"),
            message: String(localized: "Deletes all logged time, rituals and ideas, and restores default goals. This can't be undone."),
            action: String(localized: "Erase")
        ) { [weak self] in
            self?.eraseAllData()
        }
    }

    private func confirm(title: String, message: String, action: String, handler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
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
        CouplePhotoStore.remove()
        Haptics.success()
    }

    private func presentStoryEditor() {
        let editor = StoryNoteEditorViewController { [weak self] in
            self?.howWeMetRow.reload()
        }
        let navigation = UINavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }
}

// MARK: - Table Data Source & Delegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    private func section(at index: Int) -> Section? {
        Section.visible.indices.contains(index) ? Section.visible[index] : nil
    }

    func numberOfSections(in tableView: UITableView) -> Int { Section.visible.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.section(at: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch self.section(at: section) {
        case .couple:
            String(localized: "Shown on your Dashboard.")
        case .sync:
            String(localized: "Uses your iCloud account. Create a code on one phone, join with it on the other. Activity photos stay on each device.")
        default:
            nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.section(at: section) {
        case .couple: coupleCells.count
        case .sync: SyncRow.rows(isLinked: PartnerSyncService.shared.isLinked).count
        case .goals: goalCells.count
        case .preferences: 1
        #if SHOW_DEVELOPER_TOOLS
        case .developer: 2
        #endif
        case .data: ActionRow.allCases.count
        case nil: 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch section(at: indexPath.section) {
        case .couple:
            return coupleCells[indexPath.row]
        case .sync:
            return syncCell(at: indexPath)
        case .goals:
            return goalCells[indexPath.row]
        case .preferences:
            return themeCell
        #if SHOW_DEVELOPER_TOOLS
        case .developer:
            if indexPath.row == 0 {
                return actionCell(
                    at: indexPath,
                    title: String(localized: "Replay Onboarding"),
                    symbol: "play.circle.fill",
                    color: .brandAccent,
                    identifier: AccessibilityID.Settings.replayOnboarding
                )
            }
            return actionCell(
                at: indexPath,
                title: String(localized: "Reset Sample Rituals"),
                symbol: "arrow.triangle.2.circlepath",
                color: .brandAccent,
                identifier: AccessibilityID.Settings.resetSampleRituals
            )
        #endif
        case .data:
            switch ActionRow(rawValue: indexPath.row) {
            case .resetWeek:
                return actionCell(
                    at: indexPath,
                    title: String(localized: "Reset Current Week"),
                    symbol: "arrow.counterclockwise.circle.fill",
                    color: .systemRed,
                    identifier: AccessibilityID.Settings.resetWeek
                )
            case .eraseAll, nil:
                return actionCell(
                    at: indexPath,
                    title: String(localized: "Erase All Data"),
                    symbol: "trash.fill",
                    color: .systemRed,
                    identifier: AccessibilityID.Settings.eraseAll
                )
            }
        case nil:
            return UITableViewCell()
        }
    }

    private func syncCell(at indexPath: IndexPath) -> UITableViewCell {
        let sync = PartnerSyncService.shared
        let rows = SyncRow.rows(isLinked: sync.isLinked)
        guard rows.indices.contains(indexPath.row) else { return UITableViewCell() }
        switch rows[indexPath.row] {
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = sync.statusText
            content.textProperties.color = .secondaryLabel
            content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.image = UIImage(systemName: sync.isLinked ? "person.2.fill" : "person.2")
            content.imageProperties.tintColor = .brandAccent
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        case .primary:
            if sync.isLinked {
                return actionCell(
                    at: indexPath,
                    title: String(localized: "Sync Now"),
                    symbol: "arrow.triangle.2.circlepath",
                    color: .brandAccent,
                    identifier: AccessibilityID.Settings.syncNow
                )
            }
            return actionCell(
                at: indexPath,
                title: String(localized: "Create Invite Code"),
                symbol: "plus.bubble.fill",
                color: .brandAccent,
                identifier: AccessibilityID.Settings.createInvite
            )
        case .secondary:
            if sync.isLinked {
                return actionCell(
                    at: indexPath,
                    title: String(localized: "Copy Invite Code"),
                    symbol: "doc.on.doc.fill",
                    color: .brandAccent,
                    identifier: AccessibilityID.Settings.copyCode
                )
            }
            return actionCell(
                at: indexPath,
                title: String(localized: "Join with Code"),
                symbol: "rectangle.and.pencil.and.ellipsis",
                color: .brandAccent,
                identifier: AccessibilityID.Settings.joinInvite
            )
        case .tertiary:
            return actionCell(
                at: indexPath,
                title: String(localized: "Unlink Partner"),
                symbol: "link.badge.minus",
                color: .systemRed,
                identifier: AccessibilityID.Settings.unlink
            )
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
        switch section(at: indexPath.section) {
        case .sync:
            let rows = SyncRow.rows(isLinked: PartnerSyncService.shared.isLinked)
            return rows.indices.contains(indexPath.row) && rows[indexPath.row] != .status
        #if SHOW_DEVELOPER_TOOLS
        case .developer:
            return true
        #endif
        case .data:
            return true
        default:
            return false
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch section(at: indexPath.section) {
        case .sync:
            handleSyncTap(at: indexPath.row)
        #if SHOW_DEVELOPER_TOOLS
        case .developer:
            indexPath.row == 0 ? replayOnboarding() : resetSampleRituals()
        #endif
        case .data:
            ActionRow(rawValue: indexPath.row) == .resetWeek ? confirmResetWeek() : confirmEraseAll()
        default:
            break
        }
    }

    private func handleSyncTap(at row: Int) {
        let sync = PartnerSyncService.shared
        let rows = SyncRow.rows(isLinked: sync.isLinked)
        guard rows.indices.contains(row) else { return }
        switch rows[row] {
        case .status:
            break
        case .primary:
            sync.isLinked ? syncNow() : createInvite()
        case .secondary:
            sync.isLinked ? copyInviteCode() : promptJoinCode()
        case .tertiary:
            confirmUnlink()
        }
    }

    private func createInvite() {
        Task {
            do {
                let code = try await PartnerSyncService.shared.createCouple()
                Haptics.success()
                let alert = UIAlertController(
                    title: String(localized: "Invite Code Ready"),
                    message: String(localized: "Share this code with your partner:\n\n\(code)"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: String(localized: "Copy"), style: .default) { _ in
                    UIPasteboard.general.string = code
                })
                alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel))
                present(alert, animated: true)
            } catch {
                presentSyncError(error)
            }
        }
    }

    private func promptJoinCode() {
        let alert = UIAlertController(
            title: String(localized: "Join Partner"),
            message: String(localized: "Enter the 6-character invite code from your partner."),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "ABC123"
            field.autocapitalizationType = .allCharacters
            field.autocorrectionType = .no
            field.accessibilityIdentifier = AccessibilityID.Settings.joinInvite
        }
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Join"), style: .default) { [weak self] _ in
            let code = alert.textFields?.first?.text ?? ""
            self?.join(with: code)
        })
        present(alert, animated: true)
    }

    private func join(with code: String) {
        Task {
            do {
                try await PartnerSyncService.shared.joinCouple(code: code)
                Haptics.success()
            } catch {
                presentSyncError(error)
            }
        }
    }

    private func syncNow() {
        Task {
            do {
                try await PartnerSyncService.shared.syncNow()
                Haptics.success()
            } catch {
                presentSyncError(error)
            }
        }
    }

    private func copyInviteCode() {
        guard let code = PartnerSyncService.shared.coupleCode else { return }
        UIPasteboard.general.string = code
        Haptics.light()
        let alert = UIAlertController(
            title: String(localized: "Copied"),
            message: String(localized: "Invite code \(code) is on the clipboard."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel))
        present(alert, animated: true)
    }

    private func confirmUnlink() {
        confirm(
            title: String(localized: "Unlink Partner?"),
            message: String(localized: "This phone will stop syncing. Your local data stays. Your partner can keep using the same code."),
            action: String(localized: "Unlink")
        ) {
            PartnerSyncService.shared.unlink()
            Haptics.light()
        }
    }

    private func presentSyncError(_ error: Error) {
        Haptics.light()
        let alert = UIAlertController(
            title: String(localized: "Sync Unavailable"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - How We Met Row
final class HowWeMetRow: UIView {
    private let onTap: () -> Void
    private let titleLabel = UILabel.make(String(localized: "How we met"), font: .preferred(.body))
    private let previewLabel = UILabel.make(font: .preferred(.subheadline), color: .secondaryLabel)

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.applySingleLineTitle(minimumScale: 0.85)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        previewLabel.applySingleLineTitle(minimumScale: 0.85)
        previewLabel.textAlignment = .right
        previewLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let icon = UIImageView.symbol("sparkles", color: .brandAccent)
        let chevron = UIImageView.symbol("chevron.right", color: .tertiaryLabel)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, titleLabel, previewLabel, chevron])
        addSubview(row)
        row.pinEdges(to: self)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = AccessibilityID.Settings.howWeMetField
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload() {
        let note = CoupleProfile.current.howWeMet.trimmed
        previewLabel.text = note.isEmpty ? String(localized: "A few words") : note
        accessibilityLabel = String(localized: "How we met")
        accessibilityValue = note.isEmpty ? String(localized: "A few words") : note
        accessibilityHint = String(localized: "Opens the story note")
    }

    @objc private func handleTap() {
        Haptics.light()
        onTap()
    }
}

// MARK: - Story Note Editor
final class StoryNoteEditorViewController: UIViewController, UITextViewDelegate {
    private let onSave: () -> Void
    private let textView = UITextView()
    private let placeholderLabel = UILabel.make(
        String(localized: "We met at a friend's birthday and talked until sunrise…"),
        font: .preferred(.body),
        color: .tertiaryLabel,
        lines: 0
    )
    private let counterLabel = UILabel.make(font: .preferred(.caption1), color: .secondaryLabel, alignment: .right)

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "How we met")
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String(localized: "Done"),
            primaryAction: UIAction { [weak self] _ in self?.saveAndDismiss() }
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
        textView.accessibilityLabel = String(localized: "How we met")
        textView.accessibilityIdentifier = AccessibilityID.Settings.howWeMetField

        textView.addSubview(placeholderLabel)
        let stack = UIStackView.make(.vertical, spacing: 8, [textView, counterLabel])
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 17),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor, constant: -34),
        ])
        updateTextState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= CoupleProfile.howWeMetCharacterLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        updateTextState()
    }

    private func updateTextState() {
        placeholderLabel.isHidden = !textView.text.isEmpty
        counterLabel.text = "\(textView.text.count)/\(CoupleProfile.howWeMetCharacterLimit)"
    }

    private func saveAndDismiss() {
        CoupleProfile.update { $0.howWeMet = String(textView.text.prefix(CoupleProfile.howWeMetCharacterLimit)) }
        onSave()
        dismiss(animated: true)
    }
}

// MARK: - Couple Text Row
/// "Title ........ value" row with an inline, right-aligned text field that saves when editing ends.
final class CoupleTextRow: UIView, UITextFieldDelegate {
    private let field = UITextField()
    private let onCommit: (String) -> Void

    init(symbol: String, title: String, placeholder: String, text: String, identifier: String, onCommit: @escaping (String) -> Void) {
        self.onCommit = onCommit
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        field.translatesAutoresizingMaskIntoConstraints = false
        field.text = text
        field.placeholder = placeholder
        field.font = .preferred(.body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .secondaryLabel
        field.textAlignment = .right
        field.autocapitalizationType = .sentences
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.accessibilityLabel = title
        field.accessibilityIdentifier = identifier
        field.delegate = self
        field.addAction(UIAction { [weak self] _ in self?.commit() }, for: .editingDidEnd)

        let icon = UIImageView.symbol(symbol, color: .brandAccent)
        let label = UILabel.make(title, font: .preferred(.body))
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView.make(.horizontal, spacing: 12, alignment: .center, [icon, label, field])
        addSubview(row)
        row.pinEdges(to: self)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func commit() {
        onCommit(field.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
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
        title.applyFlexibleTitle()
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
