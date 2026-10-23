import Foundation
import SwiftData

// MARK: - Activity Log
@Model
final class ActivityLog {
    var id: UUID = UUID()
    var date: Date
    /// Raw `ActivityCategory` value (e.g. "goingOut", shown as "Going Out").
    @Attribute(originalName: "categoryRaw") var category: String
    @Attribute(originalName: "minutes") var durationMinutes: Int
    var note: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var secondaryCategoryRaws: [String] = []

    init(
        category: ActivityCategory,
        durationMinutes: Int,
        date: Date = .now,
        note: String = "",
        imageData: Data? = nil,
        secondaryTags: [ActivityCategory] = []
    ) {
        self.id = UUID()
        self.date = date
        self.category = category.rawValue
        self.durationMinutes = durationMinutes
        self.note = note
        self.imageData = imageData
        self.secondaryCategoryRaws = secondaryTags
            .filter { $0 != category }
            .map(\.rawValue)
    }

    var activityCategory: ActivityCategory {
        ActivityCategory.resolve(category) ?? .goingOut
    }

    var secondaryTags: [ActivityCategory] {
        secondaryCategoryRaws.compactMap(ActivityCategory.resolve)
    }

    /// Checks whether this log counts as a given category (primary or secondary tag).
    func involves(_ target: ActivityCategory, includeSecondary: Bool = true) -> Bool {
        if activityCategory == target { return true }
        return includeSecondary && secondaryTags.contains(target)
    }
}

extension Sequence where Element == ActivityLog {
    /// Sums primary category minutes within the given date interval (never double-counts secondary tags).
    func minutesByCategory(in interval: DateInterval) -> [ActivityCategory: Int] {
        reduce(into: [:]) { totals, log in
            if log.date >= interval.start && log.date < interval.end {
                totals[log.activityCategory, default: 0] += log.durationMinutes
            }
        }
    }
}
