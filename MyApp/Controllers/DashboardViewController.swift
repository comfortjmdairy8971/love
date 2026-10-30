import UIKit
import SwiftUI

// MARK: - Dashboard
final class DashboardViewController: UIViewController {
    private let store = DataStore.shared
    private let timerManager: TimerManager

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.make(.vertical, spacing: 24)
    private let coupleHeader = CoupleHeaderView()
    private let weeklyStateTitle = UILabel.make(
        String(localized: "Weekly State"),
        font: .preferred(.largeTitle, weight: .bold, design: .rounded),
        lines: 0
    )
    private let livePill = LivePillView()
    private let heroBanner = HeroBannerView()
    private let rings = ConcentricRingsView()
    private var cards: [ActivityCategory: CategoryCardView] = [:]

    private var selectedCategory: ActivityCategory?
    private var progress: [ActivityCategory: Double] = [:]

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        self.init(timerManager: .shared)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Couple story sits above "Weekly State" in the scroll content.
        navigationItem.title = String(localized: "Dashboard")
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Dashboard.screen
        setUpLayout()
        setUpCallbacks()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(coupleProfileDidChange), name: .coupleProfileDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(timerDidChange), name: .timerManagerDidChange, object: nil)
        reloadData(animated: false)
        refreshLivePill(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Picks up a new week, and animates rings changed from another screen.
        timerManager.syncFromStartDate()
        refreshLivePill(animated: false)
        reloadData(animated: true)
    }

    // MARK: Layout
    private func setUpLayout() {
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        weeklyStateTitle.accessibilityTraits = .header
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        let ringsWrapper = UIView()
        ringsWrapper.translatesAutoresizingMaskIntoConstraints = false
        ringsWrapper.addSubview(rings)
        NSLayoutConstraint.activate([
            rings.centerXAnchor.constraint(equalTo: ringsWrapper.centerXAnchor),
            rings.centerYAnchor.constraint(equalTo: ringsWrapper.centerYAnchor),
            // Leaves room for the selected ring's 1.08 scale.
            ringsWrapper.heightAnchor.constraint(equalTo: rings.heightAnchor, constant: 24),
        ])

        let categories = ActivityCategory.allCases
        for category in categories {
            let card = CategoryCardView(category: category)
            card.accessibilityIdentifier = AccessibilityID.Dashboard.card(category)
            card.quickAddButton.accessibilityIdentifier = AccessibilityID.Dashboard.quickAdd(category)
            cards[category] = card
        }
        rings.accessibilityIdentifier = AccessibilityID.Dashboard.rings
        let rows = stride(from: 0, to: categories.count, by: 2).map { index in
            UIStackView.make(.horizontal, spacing: 16, distribution: .fillEqually, categories[index..<min(index + 2, categories.count)].compactMap { cards[$0] })
        }
        let grid = UIStackView.make(.vertical, spacing: 16, rows)

        [coupleHeader, weeklyStateTitle, livePill, heroBanner, ringsWrapper, grid].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(16, after: coupleHeader)
        contentStack.setCustomSpacing(20, after: weeklyStateTitle)
    }

    private func setUpCallbacks() {
        rings.onRingTapped = { [weak self] category in self?.toggleSelection(category) }
        rings.onCenterTapped = { [weak self] in self?.clearSelection() }
        livePill.onStart = { [weak self] in
            Haptics.tap()
            self?.timerManager.startTimer()
        }
        livePill.onStop = { [weak self] in self?.stopTimer() }
        livePill.onResume = { [weak self] in
            Haptics.tap()
            self?.timerManager.resumeTimer()
        }
        livePill.onDiscard = { [weak self] in
            Haptics.light()
            self?.timerManager.resetTimer()
        }

        for (category, card) in cards {
            card.onQuickAdd = { [weak self] in self?.quickAdd(to: category) }
            card.addAction(UIAction { [weak self] _ in self?.showDetail(for: category) }, for: .touchUpInside)
        }
    }

    // MARK: Data
    @objc private func dataDidChange() {
        reloadData(animated: view.window != nil)
    }

    @objc private func coupleProfileDidChange() {
        updateCoupleHeader()
    }

    private func updateCoupleHeader() {
        let profile = CoupleProfile.current
        coupleHeader.configure(with: profile)
        // Pull "Weekly State" up when there's no couple card above it.
        contentStack.setCustomSpacing(profile.hasDetails ? 16 : 0, after: coupleHeader)
    }

    private func reloadData(animated: Bool) {
        updateCoupleHeader()
        let logs = store.logs
        let goals = store.goals
        let weekMinutes = logs.minutesByCategory(in: Calendar.current.weekInterval(containing: .now))

        var allGoalsAchieved = true
        for category in ActivityCategory.allCases {
            let current = weekMinutes[category] ?? 0
            let target = goals.target(for: category)
            progress[category] = min(Double(current) / Double(max(target, 1)), 1)
            if target <= 0 || current < target { allGoalsAchieved = false }
            cards[category]?.configure(currentMinutes: current, targetMinutes: target)
        }

        rings.update(progress: progress, animated: animated)
        rings.setCelebrating(allGoalsAchieved)
        heroBanner.configure(
            allGoalsAchieved: allGoalsAchieved,
            goingOutDays: logs.daysSinceLast(.goingOut),
            adventureDays: logs.daysSinceLast(.newAdventures),
            animated: animated
        )
        applySelection(animated: false)
    }

    private func percentage(for category: ActivityCategory?) -> Int {
        guard let category else { return 0 }
        return min(Int((progress[category] ?? 0) * 100), 100)
    }

    // MARK: Ring Selection
    private func toggleSelection(_ category: ActivityCategory) {
        Haptics.light()
        selectedCategory = selectedCategory == category ? nil : category
        applySelection(animated: true)
    }

    private func clearSelection() {
        guard selectedCategory != nil else { return }
        Haptics.light()
        selectedCategory = nil
        applySelection(animated: true)
    }

    private func applySelection(animated: Bool) {
        rings.setSelection(selectedCategory, percentage: percentage(for: selectedCategory), animated: animated)
        for (category, card) in cards {
            card.setSelected(category == selectedCategory, animated: animated)
        }
    }

    // MARK: Quick Add & Navigation
    private func quickAdd(to category: ActivityCategory) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.insert(ActivityLog(category: category, durationMinutes: 15))
    }

    private func showDetail(for category: ActivityCategory) {
        navigationController?.pushViewController(CategoryDetailViewController(category: category), animated: true)
    }

    // MARK: Live Timer
    @objc private func timerDidChange() {
        refreshLivePill(animated: livePill.state == .idle && timerManager.isTiming)
    }

    private func refreshLivePill(animated: Bool) {
        let seconds = Int(timerManager.elapsedSeconds)
        let state: LivePillView.State
        if timerManager.isTiming {
            state = .running
        } else if timerManager.elapsedSeconds > 0 {
            state = .paused
        } else {
            state = .idle
        }
        livePill.configure(state: state, elapsedSeconds: seconds, animated: animated)
    }

    private func stopTimer() {
        Haptics.tap()
        timerManager.pauseTimer()
        presentCategoryPicker()
    }

    private func presentCategoryPicker() {
        let elapsed = timerManager.elapsedSeconds
        let minutes = max(1, Int(elapsed) / 60)
        let sheet = UIAlertController(
            title: String(localized: "Which category did you spend time on?"),
            message: String(localized: "Logs \(formatDuration(minutes: minutes)) together."),
            preferredStyle: .actionSheet
        )
        for category in ActivityCategory.allCases {
            sheet.addAction(UIAlertAction(title: category.title, style: .default) { [weak self] _ in
                self?.saveTimer(to: category, elapsedSeconds: elapsed)
            })
        }
        sheet.addAction(UIAlertAction(title: String(localized: "Resume"), style: .default) { [weak self] _ in
            self?.timerManager.resumeTimer()
        })
        sheet.addAction(UIAlertAction(title: String(localized: "Discard"), style: .destructive) { [weak self] _ in
            self?.timerManager.resetTimer()
        })
        // Dismissing without a choice leaves the session paused.
        sheet.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        sheet.popoverPresentationController?.sourceView = livePill.stopButton
        present(sheet, animated: true)
    }

    private func saveTimer(to category: ActivityCategory, elapsedSeconds: TimeInterval) {
        let minutes = max(1, Int(elapsedSeconds) / 60)
        store.insert(ActivityLog(category: category, durationMinutes: minutes, date: Date(), note: ""))
        Haptics.success()
        timerManager.resetTimer()
    }
}

#Preview {
    let navigationController = UINavigationController(rootViewController: DashboardViewController())
    navigationController.navigationBar.prefersLargeTitles = true
    return navigationController
}
