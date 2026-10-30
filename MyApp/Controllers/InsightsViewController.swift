import UIKit
import SwiftUI

// MARK: - Insights & Monthly Recap
final class InsightsViewController: UIViewController {
    private enum TimeSpan: Int, CaseIterable {
        case four = 4, eight = 8, twelve = 12
        var title: String { "\(rawValue)W" }
    }

    private let store = DataStore.shared
    private let calendar = Calendar.current
    private var range: TimeSpan = .eight
    private var showsPreviousMonth = false

    private var logs: [ActivityLog] = []
    private var goals: [WeeklyGoal] = []
    private var rituals: [Ritual] = []

    // Layout
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView.make(.vertical, spacing: 20)
    private let rangeControl = UISegmentedControl(items: TimeSpan.allCases.map(\.title))

    // Summary
    private let thisWeekTile = StatTileView(title: String(localized: "This week"), color: .brandAccent)
    private let averageTile = StatTileView(title: String(localized: "Weekly average"), color: .systemPurple)
    private let balanceMessageLabel = UILabel.make(font: .preferred(.subheadline, weight: .medium), lines: 0)
    private let leadingChip = ChipView()
    private let laggingChip = ChipView()

    // Peak days
    private let peakCard = InsightCardView(title: String(localized: "Best Day for Connection"), subtitle: "")
    private let bestDayLabel = UILabel.make(font: .preferred(.title3, weight: .bold))
    private let peakHost = UIHostingController(rootView: WeekdayPeakChart())

    // Charts
    private let weeklyCard = InsightCardView(
        title: String(localized: "Weekly Breakdown"),
        subtitle: String(localized: "Hours per week, by category")
    )
    private let weeklyHost = UIHostingController(rootView: WeeklyBreakdownChart())
    private let weeklyEmpty = InsightsViewController.makeEmptyChart()
    private let balanceCard = InsightCardView(title: String(localized: "Category Balance"), subtitle: "")
    private let donutHost = UIHostingController(rootView: CategoryBalanceChart())
    private let legendStack = UIStackView.make(.vertical, spacing: 10)
    private let balanceEmpty = InsightsViewController.makeEmptyChart()

    // Recap
    private let monthControl = UISegmentedControl(items: [
        String(localized: "This Month"),
        String(localized: "Last Month"),
    ])
    private let recapCard = MonthlyRecapCardView()
    private let shareButton = UIButton(configuration: .capsule(
        title: String(localized: "Share Recap"),
        symbol: "square.and.arrow.up",
        color: .brandAccent
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String(localized: "Insights")
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Insights.screen
        rangeControl.accessibilityIdentifier = AccessibilityID.Insights.rangeControl
        monthControl.accessibilityIdentifier = AccessibilityID.Insights.monthControl
        shareButton.accessibilityIdentifier = AccessibilityID.Insights.shareRecapButton
        setUpLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    // MARK: Layout
    private func setUpLayout() {
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 32, trailing: 16)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        rangeControl.selectedSegmentIndex = TimeSpan.allCases.firstIndex(of: range) ?? 1
        rangeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.range = TimeSpan.allCases[self.rangeControl.selectedSegmentIndex]
            self.reloadData()
        }, for: .valueChanged)

        let tiles = UIStackView.make(.horizontal, spacing: 12, distribution: .fillEqually, [thisWeekTile, averageTile])

        contentStack.addArrangedSubview(rangeControl)
        contentStack.addArrangedSubview(tiles)
        contentStack.addArrangedSubview(makeBalanceSummaryCard())
        contentStack.addArrangedSubview(peakCard)
        contentStack.addArrangedSubview(weeklyCard)
        contentStack.addArrangedSubview(balanceCard)
        contentStack.addArrangedSubview(makeRecapSection())

        peakCard.bodyStack.addArrangedSubview(bestDayLabel)
        embed(peakHost, height: 160, in: peakCard.bodyStack)
        embed(weeklyHost, height: 220, in: weeklyCard.bodyStack)
        weeklyCard.bodyStack.addArrangedSubview(weeklyEmpty)
        embed(donutHost, height: 200, in: balanceCard.bodyStack)
        balanceCard.bodyStack.addArrangedSubview(legendStack)
        balanceCard.bodyStack.addArrangedSubview(balanceEmpty)
    }

    private func embed<Content: View>(_ host: UIHostingController<Content>, height: CGFloat, in stack: UIStackView) {
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        host.view.heightAnchor.constraint(equalToConstant: height).isActive = true
        stack.addArrangedSubview(host.view)
        host.didMove(toParent: self)
    }

    private static func makeEmptyChart() -> UIView {
        EmptyStateView(
            symbol: "chart.bar.xaxis",
            title: String(localized: "No activity yet"),
            message: String(localized: "Log some time together to see your trends.")
        )
    }

    private func makeBalanceSummaryCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.applyCardStyle()

        let bulb = IconTileView(
            symbol: "lightbulb.fill",
            color: UIColor.brandSun.withAlphaComponent(0.18),
            side: 28,
            cornerRadius: 14,
            pointSize: 13,
            symbolColor: .brandSun
        )
        let chips = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [leadingChip, laggingChip, .spacer()])
        let texts = UIStackView.make(.vertical, spacing: 8, [balanceMessageLabel, chips])
        let content = UIStackView.make(.horizontal, spacing: 12, alignment: .top, [bulb, texts])
        card.addSubview(content)
        content.pinEdges(to: card, insets: .all(16))
        return card
    }

    private func makeRecapSection() -> UIView {
        let title = UILabel.make(String(localized: "Monthly Recap"), font: .preferred(.headline))
        title.accessibilityTraits = .header
        let subtitle = UILabel.make(
            String(localized: "A shareable summary of your month"),
            font: .preferred(.caption1),
            color: .secondaryLabel
        )
        let header = UIStackView.make(.vertical, spacing: 2, [title, subtitle])

        monthControl.selectedSegmentIndex = 0
        monthControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.showsPreviousMonth = self.monthControl.selectedSegmentIndex == 1
            UIView.transition(with: self.recapCard, duration: 0.3, options: .transitionCrossDissolve) {
                self.updateRecap()
            }
        }, for: .valueChanged)

        let cardWrapper = UIView()
        cardWrapper.translatesAutoresizingMaskIntoConstraints = false
        cardWrapper.layer.shadowColor = UIColor.brandAccent.cgColor
        cardWrapper.layer.shadowOpacity = 0.3
        cardWrapper.layer.shadowRadius = 20
        cardWrapper.layer.shadowOffset = CGSize(width: 0, height: 10)
        cardWrapper.addSubview(recapCard)
        NSLayoutConstraint.activate([
            recapCard.topAnchor.constraint(equalTo: cardWrapper.topAnchor),
            recapCard.bottomAnchor.constraint(equalTo: cardWrapper.bottomAnchor),
            recapCard.centerXAnchor.constraint(equalTo: cardWrapper.centerXAnchor),
        ])

        shareButton.addAction(UIAction { [weak self] _ in self?.shareRecap() }, for: .touchUpInside)

        let section = UIStackView.make(.vertical, spacing: 14, [header, monthControl, cardWrapper, shareButton])
        section.setCustomSpacing(20, after: cardWrapper)
        return section
    }

    // MARK: Data
    @objc private func dataDidChange() {
        reloadData()
    }

    private var weekIntervals: [DateInterval] {
        let current = calendar.weekInterval(containing: .now)
        return (0..<range.rawValue).reversed().compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: current.start).map { calendar.weekInterval(containing: $0) }
        }
    }

    private func reloadData() {
        logs = store.logs
        goals = store.goals
        rituals = store.rituals

        let intervals = weekIntervals
        guard let first = intervals.first, let last = intervals.last else { return }
        let rangeInterval = DateInterval(start: first.start, end: last.end)
        let rangeMinutes = logs.minutesByCategory(in: rangeInterval)
        let shares = ActivityCategory.allCases.map { CategoryShare(category: $0, minutes: rangeMinutes[$0] ?? 0) }
        let rangeTotal = shares.reduce(0) { $0 + $1.minutes }

        updateSummary(rangeTotal: rangeTotal)
        updateBalanceSummary()
        updatePeakDays(in: rangeInterval)

        let hasData = rangeTotal > 0
        weeklyHost.view.isHidden = !hasData
        weeklyEmpty.isHidden = hasData
        weeklyHost.rootView = WeeklyBreakdownChart(
            buckets: intervals.flatMap { interval in
                let minutes = logs.minutesByCategory(in: interval)
                return ActivityCategory.allCases.map { WeekBucket(weekStart: interval.start, category: $0, minutes: minutes[$0] ?? 0) }
            },
            weeks: range.rawValue
        )

        balanceCard.setSubtitle(String(localized: "Share of time over the last \(range.rawValue) weeks"))
        donutHost.view.isHidden = !hasData
        legendStack.isHidden = !hasData
        balanceEmpty.isHidden = hasData
        donutHost.rootView = CategoryBalanceChart(shares: shares, totalMinutes: rangeTotal)
        updateLegend(shares: shares, total: rangeTotal)

        updateRecap()
    }

    private func weekTotal(weeksAgo: Int) -> Int {
        guard let date = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: .now) else { return 0 }
        return logs.minutesByCategory(in: calendar.weekInterval(containing: date)).values.reduce(0, +)
    }

    private func updateSummary(rangeTotal: Int) {
        let thisWeek = weekTotal(weeksAgo: 0)
        let delta = thisWeek - weekTotal(weeksAgo: 1)
        let deltaText = switch delta {
        case 0: String(localized: "Same as last week")
        case 1...: String(localized: "+\(formatDuration(minutes: delta)) vs last week")
        default: String(localized: "-\(formatDuration(minutes: -delta)) vs last week")
        }
        thisWeekTile.configure(value: formatDuration(minutes: thisWeek), detail: deltaText)
        averageTile.configure(
            value: formatDuration(minutes: rangeTotal / range.rawValue),
            detail: String(localized: "Last \(range.rawValue) weeks")
        )
    }

    private func updateBalanceSummary() {
        let thisWeek = logs.minutesByCategory(in: calendar.weekInterval(containing: .now))
        func goalProgress(_ category: ActivityCategory) -> Double {
            Double(thisWeek[category] ?? 0) / Double(max(goals.target(for: category), 1))
        }
        let dominant = ActivityCategory.allCases
            .filter { (thisWeek[$0] ?? 0) > 0 }
            .max { goalProgress($0) < goalProgress($1) }
        let lagging = ActivityCategory.allCases
            .filter { $0 != dominant }
            .min { goalProgress($0) < goalProgress($1) }
        let laggingNeedsLove = lagging.map { goalProgress($0) < 1 } ?? false

        balanceMessageLabel.text = switch (dominant, lagging) {
        case (nil, let lagging?):
            String(localized: "Nothing logged yet this week. Try scheduling a \(lagging.title) activity soon.")
        case (let dominant?, let lagging?) where laggingNeedsLove:
            String(localized: "Great job on \(dominant.title) this week! Try scheduling a \(lagging.title) activity soon.")
        case (let dominant?, _):
            String(localized: "Great job on \(dominant.title) this week! Every goal is on track.")
        default:
            String(localized: "Log some time together to see your balance.")
        }

        if let dominant {
            leadingChip.configure(text: String(localized: "Leading: \(dominant.title)"), symbol: dominant.icon, color: dominant.color)
        }
        leadingChip.isHidden = dominant == nil
        if let lagging, laggingNeedsLove {
            laggingChip.configure(text: String(localized: "Lagging: \(lagging.title)"), symbol: lagging.icon, color: lagging.color)
        }
        laggingChip.isHidden = !laggingNeedsLove
    }

    private func updatePeakDays(in interval: DateInterval) {
        var minutesByWeekday: [Int: Int] = [:]
        for log in logs where log.date >= interval.start && log.date < interval.end {
            minutesByWeekday[calendar.component(.weekday, from: log.date), default: 0] += log.durationMinutes
        }
        let orderedWeekdays = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        let totals = orderedWeekdays.map {
            WeekdayTotal(weekday: $0, symbol: calendar.shortWeekdaySymbols[$0 - 1], minutes: minutesByWeekday[$0] ?? 0)
        }
        let best = minutesByWeekday.max { $0.value < $1.value }

        if let best {
            bestDayLabel.text = calendar.weekdaySymbols[best.key - 1]
            peakCard.setSubtitle(String(localized: "\(formatDuration(minutes: best.value)) logged over the last \(range.rawValue) weeks"))
        } else {
            bestDayLabel.text = String(localized: "Not enough data yet")
            peakCard.setSubtitle(String(localized: "Your peak connection day will appear here"))
        }
        peakHost.view.isHidden = best == nil
        peakHost.rootView = WeekdayPeakChart(totals: totals, bestWeekday: best?.key)
    }

    private func updateLegend(shares: [CategoryShare], total: Int) {
        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard total > 0 else { return }
        for share in shares {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = share.category.color
            dot.layer.cornerRadius = 5
            let percent = Int((Double(share.minutes) / Double(total) * 100).rounded())
            let percentLabel = UILabel.make("\(percent)%", font: .preferred(.subheadline, weight: .semibold), alignment: .right)
            let categoryLabel = UILabel.make(share.category.title, font: .preferred(.subheadline))
            categoryLabel.applyFlexibleTitle()
            let row = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [
                dot,
                categoryLabel,
                .spacer(),
                UILabel.make(formatDuration(minutes: share.minutes), font: .preferred(.subheadline), color: .secondaryLabel),
                percentLabel,
            ])
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10),
                percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            ])
            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(share.category.title): \(formatDuration(minutes: share.minutes)), \(percent) percent"
            legendStack.addArrangedSubview(row)
        }
    }

    // MARK: Recap
    private var recap: MonthlyRecap {
        let reference = showsPreviousMonth ? calendar.date(byAdding: .month, value: -1, to: .now) ?? .now : .now
        return MonthlyRecap(month: calendar.monthInterval(containing: reference), logs: logs, rituals: rituals)
    }

    private func updateRecap() {
        recapCard.configure(with: recap)
    }

    private func shareRecap() {
        Haptics.tap()
        let image = recapCard.renderImage()
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = shareButton
        present(activityViewController, animated: true)
    }
}

#Preview {
    UINavigationController(rootViewController: InsightsViewController())
}
