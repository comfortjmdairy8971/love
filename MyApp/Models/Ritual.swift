import Foundation
import SwiftData

// MARK: - Ritual Frequency
enum RitualFrequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        }
    }

    var unit: String {
        switch self {
        case .daily: String(localized: "day")
        case .weekly: String(localized: "week")
        case .monthly: String(localized: "month")
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }
}

// MARK: - Ritual
@Model
final class Ritual {
    static let defaultIcon = "heart.fill"
    static let iconChoices = [
        "heart.fill", "moon.stars.fill", "cup.and.saucer.fill", "figure.walk",
        "fork.knife", "film.fill", "book.fill", "music.note",
        "map.fill", "leaf.fill", "gamecontroller.fill", "bed.double.fill",
    ]

    var id: UUID = UUID()
    /// Stable catalog slug (`phone_free_evening`). Empty for user-created rituals.
    var presetKey: String = ""
    var title: String
    var icon: String = Ritual.defaultIcon
    /// Raw `RitualFrequency` value (e.g. "weekly").
    @Attribute(originalName: "frequencyRaw") var frequency: String
    var streakCount: Int
    var lastCompletedDate: Date?
    var completionDates: [Date] = []
    var createdAt: Date

    init(title: String, icon: String = Ritual.defaultIcon, frequency: RitualFrequency, presetKey: String = "") {
        self.id = UUID()
        self.presetKey = presetKey
        self.title = title
        self.icon = icon
        self.frequency = frequency.rawValue
        self.streakCount = 0
        self.lastCompletedDate = nil
        self.completionDates = []
        self.createdAt = .now
    }

    convenience init(preset: RitualPreset) {
        self.init(title: preset.title, icon: preset.icon, frequency: preset.frequency, presetKey: preset.slug)
    }

    var ritualFrequency: RitualFrequency { RitualFrequency(rawValue: frequency) ?? .weekly }

    private func currentPeriod(_ now: Date) -> DateInterval? {
        Calendar.current.dateInterval(of: ritualFrequency.calendarComponent, for: now)
    }

    private func previousPeriod(_ now: Date) -> DateInterval? {
        guard let current = currentPeriod(now) else { return nil }
        return Calendar.current.dateInterval(of: ritualFrequency.calendarComponent, for: current.start.addingTimeInterval(-1))
    }

    func isCompleted(now: Date = .now) -> Bool {
        guard let last = lastCompletedDate, let period = currentPeriod(now) else { return false }
        return period.contains(last)
    }

    private func wasCompletedLastPeriod(now: Date) -> Bool {
        guard let last = lastCompletedDate, let period = previousPeriod(now) else { return false }
        return period.contains(last)
    }

    /// The streak is only alive if the ritual was done this period or the one before it.
    func activeStreak(now: Date = .now) -> Int {
        isCompleted(now: now) || wasCompletedLastPeriod(now: now) ? streakCount : 0
    }

    func toggleCompletion(now: Date = .now) {
        if isCompleted(now: now) {
            streakCount = max(streakCount - 1, 0)
            lastCompletedDate = streakCount > 0 ? previousPeriod(now)?.start : nil
            if let period = currentPeriod(now) {
                completionDates.removeAll { period.contains($0) }
            }
        } else {
            streakCount = wasCompletedLastPeriod(now: now) ? streakCount + 1 : 1
            lastCompletedDate = now
            completionDates.append(now)
        }
    }

    func completions(in interval: DateInterval) -> Int {
        completionDates.filter { $0 >= interval.start && $0 < interval.end }.count
    }
}
