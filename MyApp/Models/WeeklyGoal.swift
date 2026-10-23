import Foundation
import SwiftData

// MARK: - Weekly Goal
@Model
final class WeeklyGoal {
    var categoryRaw: String
    var targetMinutes: Int

    init(category: ActivityCategory, targetMinutes: Int) {
        self.categoryRaw = category.rawValue
        self.targetMinutes = targetMinutes
    }

    var category: ActivityCategory {
        ActivityCategory.resolve(categoryRaw) ?? .goingOut
    }
}

extension Array where Element == WeeklyGoal {
    func target(for category: ActivityCategory) -> Int {
        first { $0.category == category }?.targetMinutes ?? category.defaultGoalMinutes
    }
}
