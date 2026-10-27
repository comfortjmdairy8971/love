import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after every saved change. `object` is the sender passed to `DataStore.commit(from:)`, if any.
    static let dataStoreDidChange = Notification.Name("DataStoreDidChange")
}

// MARK: - Data Store
/// Owns the SwiftData container and replaces SwiftUI's `@Query` with explicit fetches + change notifications.
final class DataStore {
    static let shared = DataStore()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private init() {
        let inMemory = Self.isRunningForPreviews
        do {
            // Partner sync talks to CloudKit directly (`PartnerSyncService`).
            // Keep SwiftData local — `.automatic` turns on CloudKit when entitlements exist
            // and then requires every attribute to be optional or have a default.
            container = try ModelContainer(
                for: Schema(AppSchema.models),
                configurations: ModelConfiguration(
                    isStoredInMemoryOnly: inMemory,
                    cloudKitDatabase: .none
                )
            )
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        if inMemory {
            SampleData.populate(container.mainContext)
        }
    }

    // MARK: Mutations
    func insert<Model: PersistentModel>(_ model: Model, from sender: AnyObject? = nil) {
        context.insert(model)
        commit(from: sender)
    }

    func delete<Model: PersistentModel>(_ model: Model, from sender: AnyObject? = nil) {
        context.delete(model)
        commit(from: sender)
    }

    /// Deletes object-by-object (rather than a batch delete) so every fetch sees the change immediately.
    func deleteAll<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) {
        fetch(descriptor).forEach(context.delete)
    }

    /// Saves and tells every screen to refresh. Senders can ignore their own notifications.
    func commit(from sender: AnyObject? = nil) {
        try? context.save()
        NotificationCenter.default.post(name: .dataStoreDidChange, object: sender)
    }

    // MARK: Queries
    func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
        (try? context.fetch(descriptor)) ?? []
    }

    /// Newest first.
    var logs: [ActivityLog] {
        fetch(FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    /// Newest first.
    func logs(for category: ActivityCategory) -> [ActivityLog] {
        let raw = category.rawValue
        return fetch(FetchDescriptor<ActivityLog>(
            predicate: #Predicate { $0.category == raw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
    }

    var goals: [WeeklyGoal] { fetch(FetchDescriptor<WeeklyGoal>()) }

    var rituals: [Ritual] {
        fetch(FetchDescriptor<Ritual>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    /// Newest first.
    var ideas: [Idea] {
        fetch(FetchDescriptor<Idea>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func targetMinutes(for category: ActivityCategory) -> Int {
        goals.target(for: category)
    }

    /// Updates (or creates) the `WeeklyGoal` and mirrors it into `UserDefaults`.
    func setGoal(_ minutes: Int, for category: ActivityCategory, from sender: AnyObject? = nil) {
        if let goal = goals.first(where: { $0.category == category }) {
            goal.targetMinutes = minutes
        } else {
            context.insert(WeeklyGoal(category: category, targetMinutes: minutes))
        }
        UserDefaults.standard.set(Double(minutes), forKey: category.goalStorageKey)
        commit(from: sender)
    }
}
