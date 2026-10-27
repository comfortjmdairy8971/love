import UIKit

// MARK: - Activity Category
enum ActivityCategory: String, CaseIterable, Identifiable, Codable {
    case goingOut
    case deepTalks
    case atHome
    case newAdventures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goingOut: "Going Out"
        case .deepTalks: "Deep Talks"
        case .atHome: "At Home"
        case .newAdventures: "New Adventures"
        }
    }

    var icon: String {
        switch self {
        case .goingOut: "figure.walk.motion"
        case .deepTalks: "bubble.left.and.bubble.right.fill"
        case .atHome: "house.fill"
        case .newAdventures: "sparkles"
        }
    }

    var color: UIColor {
        switch self {
        case .goingOut: .brandAccent
        case .deepTalks: .brandAqua
        case .atHome: .brandViolet
        case .newAdventures: .brandOrange
        }
    }

    var info: String {
        switch self {
        case .goingOut: "Date nights, walks, dining, events"
        case .deepTalks: "Heart-to-heart talks, check-ins"
        case .atHome: "Cooking, chores, shared home tasks"
        case .newAdventures: "Novel experiences, surprises"
        }
    }

    var defaultGoalMinutes: Int {
        switch self {
        case .goingOut: 120
        case .deepTalks: 60
        case .atHome: 90
        case .newAdventures: 30
        }
    }

    /// `UserDefaults` keys mirroring each weekly target goal.
    var goalStorageKey: String {
        switch self {
        case .goingOut: "goalGoingOut"
        case .deepTalks: "goalDeepTalks"
        case .atHome: "goalAtHome"
        case .newAdventures: "goalNewAdventures"
        }
    }

    /// Retired `UserDefaults` keys for logged minutes (minutes now come from `ActivityLog`).
    var retiredMinutesStorageKey: String {
        switch self {
        case .goingOut: "goingOutMin"
        case .deepTalks: "deepTalksMin"
        case .atHome: "atHomeMin"
        case .newAdventures: "newAdventuresMin"
        }
    }

    /// Legacy `UserDefaults` keys from the earlier category naming.
    var legacyMinutesKeys: [String] {
        switch self {
        case .goingOut: ["qualityTimeMin"]
        case .deepTalks: ["meaningfulTalksMin"]
        case .atHome: ["homeNestingMin", "sharedChoresMin"]
        case .newAdventures: ["surprisesMin"]
        }
    }

    var legacyGoalKeys: [String] {
        switch self {
        case .goingOut: ["goalQualityTime"]
        case .deepTalks: ["goalMeaningfulTalks"]
        case .atHome: ["goalHomeNesting", "goalSharedChores"]
        case .newAdventures: ["goalSurprises"]
        }
    }

    /// Resolves both current and legacy raw category strings.
    nonisolated static func resolve(_ raw: String) -> ActivityCategory? {
        if let current = ActivityCategory(rawValue: raw) {
            return current
        }
        switch raw {
        case "qualityTime": return .goingOut
        case "talks": return .deepTalks
        case "homeNesting", "chores": return .atHome
        case "surprises": return .newAdventures
        default: return nil
        }
    }
}
