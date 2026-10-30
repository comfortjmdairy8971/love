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
        deduplicateRituals(in: existingRituals, context: context)

        let existingGoals = (try? context.fetch(FetchDescriptor<WeeklyGoal>())) ?? []
        for goal in existingGoals {
            if let resolved = ActivityCategory.resolve(goal.categoryRaw), goal.categoryRaw != resolved.rawValue {
                goal.categoryRaw = resolved.rawValue
            }
        }

        let existingIdeas = (try? context.fetch(FetchDescriptor<Idea>())) ?? []
        var seenIdeaIDs = Set<UUID>()
        for idea in existingIdeas {
            if !seenIdeaIDs.insert(idea.id).inserted {
                idea.id = UUID()
                seenIdeaIDs.insert(idea.id)
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

    /// Collapses EN/FR copies of the same preset and refreshes titles to the current locale.
    static func deduplicateRituals(in rituals: [Ritual], context: ModelContext) {
        for ritual in rituals {
            if ritual.presetKey.isEmpty, let preset = RitualPreset.matching(title: ritual.title) {
                ritual.presetKey = preset.slug
            } else if let preset = RitualPreset.matching(slug: ritual.presetKey) {
                ritual.presetKey = preset.slug
            }
            if let preset = RitualPreset.matching(slug: ritual.presetKey) {
                ritual.title = preset.title
                if ritual.icon.isEmpty { ritual.icon = preset.icon }
            }
        }

        func keepBest(_ group: [Ritual]) -> Ritual {
            group.max { lhs, rhs in
                if lhs.completionDates.count != rhs.completionDates.count {
                    return lhs.completionDates.count < rhs.completionDates.count
                }
                return lhs.createdAt > rhs.createdAt
            } ?? group[0]
        }

        func merge(into keeper: Ritual, extras: [Ritual]) {
            for extra in extras {
                keeper.completionDates = Array(Set(keeper.completionDates + extra.completionDates)).sorted()
                keeper.streakCount = max(keeper.streakCount, extra.streakCount)
                if let last = extra.lastCompletedDate, last > (keeper.lastCompletedDate ?? .distantPast) {
                    keeper.lastCompletedDate = last
                }
                context.delete(extra)
            }
        }

        let keyed = Dictionary(grouping: rituals.filter { !$0.presetKey.isEmpty }, by: \.presetKey)
        for (_, group) in keyed where group.count > 1 {
            let keeper = keepBest(group)
            merge(into: keeper, extras: group.filter { $0 !== keeper })
        }

        let untitled = rituals.filter { $0.presetKey.isEmpty && !$0.title.trimmed.isEmpty }
        let byTitle = Dictionary(grouping: untitled) { $0.title.trimmed.lowercased() }
        for (_, group) in byTitle where group.count > 1 {
            let keeper = keepBest(group)
            merge(into: keeper, extras: group.filter { $0 !== keeper })
        }
    }

    #if SHOW_DEVELOPER_TOOLS
    /// Deletes catalog rituals so Debug can start from a clean preset list.
    static func resetSeededRituals(context: ModelContext) {
        let rituals = (try? context.fetch(FetchDescriptor<Ritual>())) ?? []
        for ritual in rituals {
            let isPreset = !ritual.presetKey.isEmpty || RitualPreset.matching(title: ritual.title) != nil
            if isPreset { context.delete(ritual) }
        }
        try? context.save()
    }
    #endif

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
