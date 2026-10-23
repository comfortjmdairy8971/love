import Foundation

/// "45m", "2h", "1h 30m".
func formatDuration(minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    switch (hours, remainder) {
    case (0, _): return "\(remainder)m"
    case (_, 0): return "\(hours)h"
    default: return "\(hours)h \(remainder)m"
    }
}

/// Stopwatch style: "MM:SS", or "HH:MM:SS" past an hour.
func formatElapsed(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    return hours > 0
        ? String(format: "%02d:%02d:%02d", hours, minutes, secs)
        : String(format: "%02d:%02d", minutes, secs)
}

extension Array where Element == ActivityLog {
    /// Whole days since the most recent log involving `category` (expects newest-first logs).
    func daysSinceLast(_ category: ActivityCategory, calendar: Calendar = .current) -> Int? {
        guard let last = first(where: { $0.involves(category, includeSecondary: true) })?.date else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: .now)).day
    }
}
