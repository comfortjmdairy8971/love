import Foundation

// MARK: - Monthly Recap Data
struct MonthlyRecap {
    let month: DateInterval
    let totalMinutes: Int
    let moments: Int
    let ritualsCompleted: Int
    let breakdown: [(category: ActivityCategory, minutes: Int)]

    init(month: DateInterval, logs: [ActivityLog], rituals: [Ritual]) {
        let monthLogs = logs.filter { $0.date >= month.start && $0.date < month.end }
        let minutes = monthLogs.minutesByCategory(in: month)
        self.month = month
        self.totalMinutes = minutes.values.reduce(0, +)
        self.moments = monthLogs.count
        self.ritualsCompleted = rituals.reduce(0) { $0 + $1.completions(in: month) }
        self.breakdown = ActivityCategory.allCases
            .map { (category: $0, minutes: minutes[$0] ?? 0) }
            .sorted { $0.minutes > $1.minutes }
    }

    var monthName: String { month.start.formatted(.dateTime.month(.wide).year()) }

    var hoursText: String {
        let hours = Double(totalMinutes) / 60
        return hours.formatted(.number.precision(.fractionLength(0...1)))
    }

    var topCategory: ActivityCategory? {
        guard let top = breakdown.first, top.minutes > 0 else { return nil }
        return top.category
    }
}
