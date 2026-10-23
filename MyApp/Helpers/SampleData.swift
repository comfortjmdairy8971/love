import Foundation
import SwiftData

/// Seeds the in-memory store used by Xcode previews.
enum SampleData {
    static func populate(_ context: ModelContext) {
        let calendar = Calendar.current

        for category in ActivityCategory.allCases {
            context.insert(WeeklyGoal(category: category, targetMinutes: category.defaultGoalMinutes))
        }

        let durations = [15, 30, 45, 60, 90]
        let notes = ["", "Sunset walk by the river", "", "Tried the new ramen place", ""]
        for dayOffset in stride(from: 0, to: 70, by: 2) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let category = ActivityCategory.allCases[(dayOffset / 2) % ActivityCategory.allCases.count]
            let secondary: [ActivityCategory] = dayOffset % 4 == 1
                ? [ActivityCategory.allCases[((dayOffset / 2) + 1) % ActivityCategory.allCases.count]]
                : []
            context.insert(
                ActivityLog(
                    category: category,
                    durationMinutes: durations[dayOffset % durations.count],
                    date: date,
                    note: notes[(dayOffset / 2) % notes.count],
                    secondaryTags: secondary
                )
            )
        }

        let dateNight = Ritual(title: "Friday Date Night", icon: "moon.stars.fill", frequency: .weekly)
        dateNight.streakCount = 3
        dateNight.completionDates = [21, 14, 7].compactMap { calendar.date(byAdding: .day, value: -$0, to: .now) }
        dateNight.lastCompletedDate = dateNight.completionDates.last
        context.insert(dateNight)

        let coffee = Ritual(title: "Morning coffee together", icon: "cup.and.saucer.fill", frequency: .daily)
        coffee.streakCount = 5
        coffee.completionDates = (0..<5).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: .now) }
        coffee.lastCompletedDate = coffee.completionDates.last
        context.insert(coffee)

        context.insert(Idea(title: "Picnic at the lake", category: .date))
        context.insert(Idea(title: "Cooking class", category: .surprise))
        context.insert(Idea(title: "Sunday meal prep together", category: .chore))

        try? context.save()
    }
}
