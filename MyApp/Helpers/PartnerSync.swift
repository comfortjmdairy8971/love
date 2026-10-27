import CloudKit
import Foundation
import SwiftData
import UIKit

extension Notification.Name {
    /// Posted whenever partner-sync link state or status text changes.
    static let partnerSyncDidChange = Notification.Name("PartnerSyncDidChange")
}

// MARK: - Sync Snapshot
/// Lightweight JSON payload stored in one CloudKit public record (no custom server).
struct CoupleSyncSnapshot: Codable, Equatable {
    var updatedAt: Date
    var profile: ProfileDTO
    var goals: [GoalDTO]
    var rituals: [RitualDTO]
    var logs: [LogDTO]
    var ideas: [IdeaDTO]

    struct ProfileDTO: Codable, Equatable {
        var yourName: String
        var partnerName: String
        var startDate: Date?
        var howWeMet: String
    }

    struct GoalDTO: Codable, Equatable {
        var category: String
        var targetMinutes: Int
    }

    struct RitualDTO: Codable, Equatable {
        var id: UUID
        var title: String
        var icon: String
        var frequency: String
        var streakCount: Int
        var lastCompletedDate: Date?
        var completionDates: [Date]
        var createdAt: Date
    }

    struct LogDTO: Codable, Equatable {
        var id: UUID
        var date: Date
        var category: String
        var durationMinutes: Int
        var note: String
        var secondaryCategoryRaws: [String]
        // Photos stay on-device for now (keeps CloudKit records small).
    }

    struct IdeaDTO: Codable, Equatable {
        var id: UUID
        var title: String
        var categoryRaw: String
        var isDone: Bool
        var createdAt: Date
    }
}

// MARK: - Partner Sync
/// Invite-code sync over Apple's CloudKit public database — both partners enter the same code, no custom backend.
@MainActor
final class PartnerSyncService {
    static let shared = PartnerSyncService()

    /// Hidden until the client's Apple team has CloudKit container `iCloud.com.eduval.moments` set up.
    static let isFeatureEnabled = false

    static let iCloudContainerID = "iCloud.com.eduval.moments"
    private static let recordType = "CoupleSpace"
    private static let payloadKey = "payload"
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private let defaults = UserDefaults.standard
    private let container = CKContainer(identifier: PartnerSyncService.iCloudContainerID)
    private var database: CKDatabase { container.publicCloudDatabase }

    private var syncTask: Task<Void, Never>?
    private var isApplyingRemote = false
    private(set) var isSyncing = false
    private(set) var lastErrorMessage: String?

    var coupleCode: String? {
        get { defaults.string(forKey: DefaultsKey.partnerSyncCoupleCode) }
        set {
            defaults.set(newValue, forKey: DefaultsKey.partnerSyncCoupleCode)
            notify()
        }
    }

    var lastSyncedAt: Date? {
        get { defaults.object(forKey: DefaultsKey.partnerSyncLastSyncedAt) as? Date }
        set {
            defaults.set(newValue, forKey: DefaultsKey.partnerSyncLastSyncedAt)
            notify()
        }
    }

    var isLinked: Bool { coupleCode != nil }

    var statusText: String {
        if let lastErrorMessage { return lastErrorMessage }
        if isSyncing { return String(localized: "Syncing…") }
        if let code = coupleCode {
            if let lastSyncedAt {
                let when = lastSyncedAt.formatted(date: .omitted, time: .shortened)
                return String(localized: "Linked · \(code) · synced \(when)")
            }
            return String(localized: "Linked · \(code)")
        }
        return String(localized: "Not linked yet")
    }

    private init() {}

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(localDataDidChange), name: .dataStoreDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(localDataDidChange), name: .coupleProfileDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        scheduleSync(delayNanoseconds: 500_000_000)
    }

    @objc private func localDataDidChange() {
        guard isLinked, !isApplyingRemote else { return }
        scheduleSync(delayNanoseconds: 1_500_000_000)
    }

    @objc private func appDidBecomeActive() {
        guard isLinked else { return }
        scheduleSync(delayNanoseconds: 300_000_000)
    }

    private func scheduleSync(delayNanoseconds: UInt64) {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            try? await self.syncNow()
        }
    }

    func createCouple() async throws -> String {
        let code = Self.makeCode()
        let snapshot = captureLocalSnapshot()
        try await save(snapshot: snapshot, code: code, existing: nil)
        coupleCode = code
        lastSyncedAt = .now
        lastErrorMessage = nil
        notify()
        return code
    }

    func joinCouple(code rawCode: String) async throws {
        let code = Self.normalize(rawCode)
        guard code.count == 6 else {
            throw SyncError.invalidCode
        }
        let recordID = Self.recordID(for: code)
        let remoteRecord: CKRecord
        do {
            remoteRecord = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw SyncError.codeNotFound
        }
        guard let remote = try decodeSnapshot(from: remoteRecord) else {
            throw SyncError.corruptedPayload
        }
        let merged = merge(local: captureLocalSnapshot(), remote: remote)
        try apply(merged)
        try await save(snapshot: merged, code: code, existing: remoteRecord)
        coupleCode = code
        lastSyncedAt = .now
        lastErrorMessage = nil
        notify()
    }

    func unlink() {
        coupleCode = nil
        lastSyncedAt = nil
        lastErrorMessage = nil
        notify()
    }

    func syncNow() async throws {
        guard let code = coupleCode else { return }
        guard !isSyncing else { return }
        isSyncing = true
        lastErrorMessage = nil
        notify()
        defer {
            isSyncing = false
            notify()
        }

        do {
            try await ensureiCloudAccount()
            let recordID = Self.recordID(for: code)
            let existing = try? await database.record(for: recordID)
            let remote = try existing.flatMap(decodeSnapshot(from:))
            let local = captureLocalSnapshot()
            let merged = remote.map { merge(local: local, remote: $0) } ?? local
            if merged != local {
                try apply(merged)
            }
            try await save(snapshot: merged, code: code, existing: existing)
            lastSyncedAt = .now
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = (error as? SyncError)?.errorDescription ?? error.localizedDescription
            throw error
        }
    }

    // MARK: CloudKit I/O
    private func ensureiCloudAccount() async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available: return
        case .noAccount: throw SyncError.noiCloudAccount
        case .restricted, .temporarilyUnavailable: throw SyncError.iCloudUnavailable
        case .couldNotDetermine: throw SyncError.iCloudUnavailable
        @unknown default: throw SyncError.iCloudUnavailable
        }
    }

    private func save(snapshot: CoupleSyncSnapshot, code: String, existing: CKRecord?) async throws {
        let record = existing ?? CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: code))
        let data = try JSONEncoder().encode(snapshot)
        guard let json = String(data: data, encoding: .utf8) else { throw SyncError.corruptedPayload }
        record[Self.payloadKey] = json as CKRecordValue
        record["code"] = code as CKRecordValue
        record["updatedAt"] = snapshot.updatedAt as CKRecordValue
        _ = try await database.save(record)
    }

    private func decodeSnapshot(from record: CKRecord) throws -> CoupleSyncSnapshot? {
        guard let json = record[Self.payloadKey] as? String, let data = json.data(using: .utf8) else {
            return nil
        }
        return try JSONDecoder().decode(CoupleSyncSnapshot.self, from: data)
    }

    // MARK: Local capture / apply
    private func captureLocalSnapshot() -> CoupleSyncSnapshot {
        let store = DataStore.shared
        let profile = CoupleProfile.current
        return CoupleSyncSnapshot(
            updatedAt: .now,
            profile: .init(
                yourName: profile.yourName,
                partnerName: profile.partnerName,
                startDate: profile.startDate,
                howWeMet: profile.howWeMet
            ),
            goals: store.goals.map { .init(category: $0.categoryRaw, targetMinutes: $0.targetMinutes) },
            rituals: store.rituals.map {
                .init(
                    id: $0.id,
                    title: $0.title,
                    icon: $0.icon,
                    frequency: $0.frequency,
                    streakCount: $0.streakCount,
                    lastCompletedDate: $0.lastCompletedDate,
                    completionDates: $0.completionDates,
                    createdAt: $0.createdAt
                )
            },
            logs: store.logs.map {
                .init(
                    id: $0.id,
                    date: $0.date,
                    category: $0.category,
                    durationMinutes: $0.durationMinutes,
                    note: $0.note,
                    secondaryCategoryRaws: $0.secondaryCategoryRaws
                )
            },
            ideas: store.ideas.map {
                .init(id: $0.id, title: $0.title, categoryRaw: $0.categoryRaw, isDone: $0.isDone, createdAt: $0.createdAt)
            }
        )
    }

    private func apply(_ snapshot: CoupleSyncSnapshot) throws {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        CoupleProfile.current = CoupleProfile(
            yourName: snapshot.profile.yourName,
            partnerName: snapshot.profile.partnerName,
            startDate: snapshot.profile.startDate,
            howWeMet: snapshot.profile.howWeMet
        )

        let store = DataStore.shared
        let context = store.context

        // Goals: upsert by category.
        let existingGoals = store.goals
        for dto in snapshot.goals {
            if let goal = existingGoals.first(where: { $0.categoryRaw == dto.category }) {
                goal.targetMinutes = dto.targetMinutes
            } else if let category = ActivityCategory.resolve(dto.category) {
                context.insert(WeeklyGoal(category: category, targetMinutes: dto.targetMinutes))
            }
        }

        // Rituals: union by id.
        var ritualsByID = Dictionary(uniqueKeysWithValues: store.rituals.map { ($0.id, $0) })
        for dto in snapshot.rituals {
            if let ritual = ritualsByID[dto.id] {
                ritual.title = dto.title
                ritual.icon = dto.icon
                ritual.frequency = dto.frequency
                ritual.streakCount = dto.streakCount
                ritual.lastCompletedDate = dto.lastCompletedDate
                ritual.completionDates = dto.completionDates
            } else {
                let ritual = Ritual(title: dto.title, icon: dto.icon, frequency: RitualFrequency(rawValue: dto.frequency) ?? .weekly)
                ritual.id = dto.id
                ritual.streakCount = dto.streakCount
                ritual.lastCompletedDate = dto.lastCompletedDate
                ritual.completionDates = dto.completionDates
                ritual.createdAt = dto.createdAt
                context.insert(ritual)
                ritualsByID[dto.id] = ritual
            }
        }

        // Logs: union by id (photos stay local-only).
        var logsByID = Dictionary(uniqueKeysWithValues: store.logs.map { ($0.id, $0) })
        for dto in snapshot.logs {
            if let log = logsByID[dto.id] {
                log.date = dto.date
                log.category = dto.category
                log.durationMinutes = dto.durationMinutes
                log.note = dto.note
                log.secondaryCategoryRaws = dto.secondaryCategoryRaws
            } else if let category = ActivityCategory.resolve(dto.category) {
                let log = ActivityLog(
                    category: category,
                    durationMinutes: dto.durationMinutes,
                    date: dto.date,
                    note: dto.note,
                    secondaryTags: dto.secondaryCategoryRaws.compactMap(ActivityCategory.resolve)
                )
                log.id = dto.id
                context.insert(log)
                logsByID[dto.id] = log
            }
        }

        // Ideas: union by id.
        var ideasByID = Dictionary(uniqueKeysWithValues: store.ideas.map { ($0.id, $0) })
        for dto in snapshot.ideas {
            if let idea = ideasByID[dto.id] {
                idea.title = dto.title
                idea.categoryRaw = dto.categoryRaw
                idea.isDone = dto.isDone
            } else {
                let idea = Idea(title: dto.title, category: IdeaCategory(rawValue: dto.categoryRaw) ?? .date)
                idea.id = dto.id
                idea.isDone = dto.isDone
                idea.createdAt = dto.createdAt
                context.insert(idea)
                ideasByID[dto.id] = idea
            }
        }

        DataBootstrap.syncGoalStorage(context: context)
        store.commit(from: self)
    }

    /// Prefer non-empty profile fields; union lists by id; keep the newest `updatedAt`.
    private func merge(local: CoupleSyncSnapshot, remote: CoupleSyncSnapshot) -> CoupleSyncSnapshot {
        let newer = remote.updatedAt >= local.updatedAt ? remote : local
        let older = newer == remote ? local : remote

        // Prefer non-empty, then the newer snapshot's value.
        func choose(_ newerValue: String, _ olderValue: String) -> String {
            let n = newerValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let o = olderValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { return newerValue }
            if !o.isEmpty { return olderValue }
            return newerValue
        }

        let profile = CoupleSyncSnapshot.ProfileDTO(
            yourName: choose(newer.profile.yourName, older.profile.yourName),
            partnerName: choose(newer.profile.partnerName, older.profile.partnerName),
            startDate: newer.profile.startDate ?? older.profile.startDate,
            howWeMet: choose(newer.profile.howWeMet, older.profile.howWeMet)
        )

        var goalsByCategory = Dictionary(uniqueKeysWithValues: older.goals.map { ($0.category, $0) })
        for goal in newer.goals { goalsByCategory[goal.category] = goal }

        var rituals = Dictionary(uniqueKeysWithValues: older.rituals.map { ($0.id, $0) })
        for ritual in newer.rituals { rituals[ritual.id] = ritual }

        var logs = Dictionary(uniqueKeysWithValues: older.logs.map { ($0.id, $0) })
        for log in newer.logs { logs[log.id] = log }

        var ideas = Dictionary(uniqueKeysWithValues: older.ideas.map { ($0.id, $0) })
        for idea in newer.ideas { ideas[idea.id] = idea }

        return CoupleSyncSnapshot(
            updatedAt: max(local.updatedAt, remote.updatedAt),
            profile: profile,
            goals: Array(goalsByCategory.values),
            rituals: Array(rituals.values),
            logs: Array(logs.values),
            ideas: Array(ideas.values)
        )
    }

    private func notify() {
        NotificationCenter.default.post(name: .partnerSyncDidChange, object: self)
    }

    private static func makeCode() -> String {
        String((0..<6).map { _ in codeAlphabet.randomElement()! })
    }

    private static func normalize(_ code: String) -> String {
        code.uppercased().filter { codeAlphabet.contains($0) }
    }

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "couple-\(code)")
    }

    enum SyncError: LocalizedError {
        case invalidCode, codeNotFound, corruptedPayload, noiCloudAccount, iCloudUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                String(localized: "Enter the 6-character invite code.")
            case .codeNotFound:
                String(localized: "No couple found for that code.")
            case .corruptedPayload:
                String(localized: "Synced data looks damaged. Try again.")
            case .noiCloudAccount:
                String(localized: "Sign in to iCloud in Settings to sync.")
            case .iCloudUnavailable:
                String(localized: "iCloud is unavailable right now.")
            }
        }
    }
}
