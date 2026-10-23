import UIKit
import SwiftUI

// MARK: - Dashboard
final class DashboardViewController: UIViewController {
    private let store = DataStore.shared

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.make(.vertical, spacing: 24)
    private let livePill = LivePillView()
    private let heroBanner = HeroBannerView()
    private let rings = ConcentricRingsView()
    private var cards: [ActivityCategory: CategoryCardView] = [:]

    private var selectedCategory: ActivityCategory?
    private var progress: [ActivityCategory: Double] = [:]

    // Live timer
    private var timer: Timer?
    private var timerStartDate: Date?
    private var elapsedSeconds = 0
    private var isTimerActive = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Weekly State"
        view.backgroundColor = .systemGroupedBackground
        setUpLayout()
        setUpCallbacks()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        reloadData(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Picks up a new week, and animates rings changed from another screen.
        reloadData(animated: true)
    }

    // MARK: Layout
    private func setUpLayout() {
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)
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
            cards[category] = CategoryCardView(category: category)
        }
        let rows = stride(from: 0, to: categories.count, by: 2).map { index in
            UIStackView.make(.horizontal, spacing: 16, distribution: .fillEqually, categories[index..<min(index + 2, categories.count)].compactMap { cards[$0] })
        }
        let grid = UIStackView.make(.vertical, spacing: 16, rows)

        [livePill, heroBanner, ringsWrapper, grid].forEach(contentStack.addArrangedSubview)
    }

    private func setUpCallbacks() {
        rings.onRingTapped = { [weak self] category in self?.toggleSelection(category) }
        rings.onCenterTapped = { [weak self] in self?.clearSelection() }
        livePill.onStart = { [weak self] in self?.startTimer() }
        livePill.onStop = { [weak self] in self?.stopTimer() }

        for (category, card) in cards {
            card.onQuickAdd = { [weak self] in self?.quickAdd(to: category) }
            card.addAction(UIAction { [weak self] _ in self?.showDetail(for: category) }, for: .touchUpInside)
        }
    }

    // MARK: Data
    @objc private func dataDidChange() {
        reloadData(animated: view.window != nil)
    }

    private func reloadData(animated: Bool) {
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
    private func startTimer() {
        Haptics.tap()
        timerStartDate = Date()
        elapsedSeconds = 0
        isTimerActive = true
        scheduleTimer()
        livePill.configure(state: .running, elapsedSeconds: 0, animated: true)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.tick()
            }
        }
        timer.tolerance = 0.1
        // `.common` keeps the stopwatch ticking while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard isTimerActive, let timerStartDate else { return }
        // Derived from the start date so time spent in the background still counts.
        elapsedSeconds = Int(Date().timeIntervalSince(timerStartDate))
        livePill.setElapsed(elapsedSeconds)
    }

    private func stopTimer() {
        Haptics.tap()
        if isTimerActive, let timerStartDate {
            elapsedSeconds = Int(Date().timeIntervalSince(timerStartDate))
        }
        isTimerActive = false
        timer?.invalidate()
        timer = nil
        livePill.configure(state: .paused, elapsedSeconds: elapsedSeconds, animated: true)
        presentCategoryPicker()
    }

    private func presentCategoryPicker() {
        let minutes = max(1, elapsedSeconds / 60)
        let sheet = UIAlertController(
            title: "Which category did you spend time on?",
            message: "Logs \(formatDuration(minutes: minutes)) together.",
            preferredStyle: .actionSheet
        )
        for category in ActivityCategory.allCases {
            sheet.addAction(UIAlertAction(title: category.title, style: .default) { [weak self] _ in
                self?.saveTimer(to: category)
            })
        }
        sheet.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.resetTimer()
        })
        sheet.addAction(UIAlertAction(title: "Keep Timing", style: .cancel) { [weak self] _ in
            self?.resumeTimer()
        })
        sheet.popoverPresentationController?.sourceView = livePill.stopButton
        present(sheet, animated: true)
    }

    private func saveTimer(to category: ActivityCategory) {
        let minutes = max(1, elapsedSeconds / 60)
        store.insert(ActivityLog(category: category, durationMinutes: minutes, date: Date(), note: ""))
        Haptics.success()
        resetTimer()
    }

    private func resumeTimer() {
        timerStartDate = Date().addingTimeInterval(-Double(elapsedSeconds))
        isTimerActive = true
        scheduleTimer()
        livePill.configure(state: .running, elapsedSeconds: elapsedSeconds, animated: true)
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        timerStartDate = nil
        elapsedSeconds = 0
        livePill.configure(state: .idle, elapsedSeconds: 0, animated: true)
    }
}

#Preview {
    let navigationController = UINavigationController(rootViewController: DashboardViewController())
    navigationController.navigationBar.prefersLargeTitles = true
    return navigationController
}
