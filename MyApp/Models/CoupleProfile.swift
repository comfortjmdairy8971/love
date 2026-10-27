import Foundation

extension Notification.Name {
    /// Posted whenever `CoupleProfile.current` is saved.
    static let coupleProfileDidChange = Notification.Name("CoupleProfileDidChange")
}

// MARK: - Couple Profile
/// The couple's names and story, persisted in `UserDefaults`.
struct CoupleProfile: Equatable {
    static let howWeMetCharacterLimit = 280

    var yourName: String
    var partnerName: String
    var startDate: Date?
    var howWeMet: String

    static var current: CoupleProfile {
        get {
            let defaults = UserDefaults.standard
            return CoupleProfile(
                yourName: defaults.string(forKey: DefaultsKey.coupleYourName) ?? "",
                partnerName: defaults.string(forKey: DefaultsKey.couplePartnerName) ?? "",
                startDate: defaults.object(forKey: DefaultsKey.coupleStartDate) as? Date,
                howWeMet: defaults.string(forKey: DefaultsKey.coupleHowWeMet) ?? ""
            )
        }
        set {
            guard newValue != current else { return }
            let defaults = UserDefaults.standard
            defaults.set(newValue.yourName.trimmed, forKey: DefaultsKey.coupleYourName)
            defaults.set(newValue.partnerName.trimmed, forKey: DefaultsKey.couplePartnerName)
            defaults.set(newValue.startDate, forKey: DefaultsKey.coupleStartDate)
            defaults.set(newValue.howWeMet.trimmed, forKey: DefaultsKey.coupleHowWeMet)
            NotificationCenter.default.post(name: .coupleProfileDidChange, object: nil)
        }
    }

    static func update(_ change: (inout CoupleProfile) -> Void) {
        var profile = current
        change(&profile)
        current = profile
    }

    /// "Valeria & Alex", or a single name if only one is set.
    var displayNames: String? {
        let names = [yourName.trimmed, partnerName.trimmed].filter { !$0.isEmpty }
        return names.isEmpty ? nil : names.joined(separator: " & ")
    }

    var hasDetails: Bool { displayNames != nil || startDate != nil }

    /// Whole days since the story began, or `nil` if no (past) start date is set.
    func daysTogether(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let startDate else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: now)).day
        return days.map { max($0, 0) }
    }

    /// "2 years, 3 months" (or "12 days" during the first month).
    func durationText(now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let startDate, let days = daysTogether(now: now, calendar: calendar), days > 0 else { return nil }
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month], from: start, to: end)
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = (parts.year ?? 0) > 0 || (parts.month ?? 0) > 0 ? [.year, .month] : [.day]
        return formatter.string(from: start, to: end)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
