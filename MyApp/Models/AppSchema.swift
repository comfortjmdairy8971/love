import Foundation
import SwiftData

// MARK: - Schema
enum AppSchema {
    static let models: [any PersistentModel.Type] = [ActivityLog.self, WeeklyGoal.self, Ritual.self, Idea.self]
}

// MARK: - Bootstrap & Migration
enum DataBootstrap {
    /// Seeds missing goals, migrates legacy identifiers, and syncs goal `UserDefaults` keys.
    static func run(context: ModelContext, defaults: UserDefaults = .standard) {
        let existingLogs = (try? context.fetch(FetchDescriptor<ActivityLog>())) ?? []
        var seenIDs = Set<UUID>()
        for log in existingLogs {
            if let resolved = ActivityCategory.resolve(log.category), log.category != resolved.rawValue {
                log.category = resolved.rawValue
            }
            log.secondaryCategoryRaws = log.secondaryCategoryRaws.compactMap { ActivityCategory.resolve($0)?.rawValue }
            // Rows migrated from the pre-`id` schema all share the column's default UUID.
            if !seenIDs.insert(log.id).inserted {
                log.id = UUID()
                seenIDs.insert(log.id)
            }
        }

        let existingRituals = (try? context.fetch(FetchDescriptor<Ritual>())) ?? []
        var seenRitualIDs = Set<UUID>()
        for ritual in existingRituals {
            if !seenRitualIDs.insert(ritual.id).inserted {
                ritual.id = UUID()
                seenRitualIDs.insert(ritual.id)
            }
            if ritual.completionDates.isEmpty, let last = ritual.lastCompletedDate {
                ritual.completionDates = [last]
            }
        }

        let existingGoals = (try? context.fetch(FetchDescriptor<WeeklyGoal>())) ?? []
        for goal in existingGoals {
            if let resolved = ActivityCategory.resolve(goal.categoryRaw), goal.categoryRaw != resolved.rawValue {
                goal.categoryRaw = resolved.rawValue
            }
        }

        let seededCategories = Set(existingGoals.map { ActivityCategory.resolve($0.categoryRaw)?.rawValue ?? $0.categoryRaw })

        for category in ActivityCategory.allCases {
            let legacyGoalValue = category.legacyGoalKeys.compactMap { defaults.object(forKey: $0) as? Double }.first
            let storedGoal = (defaults.object(forKey: category.goalStorageKey) as? Double) ?? legacyGoalValue
            let initialGoal = storedGoal.map { Int($0) } ?? category.defaultGoalMinutes

            if !seededCategories.contains(category.rawValue) {
                context.insert(WeeklyGoal(category: category, targetMinutes: initialGoal))
            }
            if defaults.object(forKey: category.goalStorageKey) == nil {
                defaults.set(Double(initialGoal), forKey: category.goalStorageKey)
            }

            for legacyMinKey in category.legacyMinutesKeys {
                let legacyMinutes = defaults.integer(forKey: legacyMinKey)
                if legacyMinutes > 0 {
                    context.insert(ActivityLog(category: category, durationMinutes: legacyMinutes))
                    defaults.removeObject(forKey: legacyMinKey)
                }
            }
            category.legacyGoalKeys.forEach(defaults.removeObject(forKey:))
            defaults.removeObject(forKey: category.retiredMinutesStorageKey)
        }
        ["currentWeekStart", "togetherTimerStart", "togetherTimerCategory"].forEach(defaults.removeObject(forKey:))

        try? context.save()
        syncGoalStorage(context: context, defaults: defaults)
    }

    /// Mirrors `WeeklyGoal` targets into `UserDefaults` keys (`goalGoingOut`, etc.).
    static func syncGoalStorage(context: ModelContext, defaults: UserDefaults = .standard) {
        let goals = (try? context.fetch(FetchDescriptor<WeeklyGoal>())) ?? []
        for category in ActivityCategory.allCases {
            defaults.set(Double(goals.target(for: category)), forKey: category.goalStorageKey)
        }
    }
}

// MARK: - Calendar Helpers
extension Calendar {
    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 7 * 86_400)
    }

    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 30 * 86_400)
    }
}
