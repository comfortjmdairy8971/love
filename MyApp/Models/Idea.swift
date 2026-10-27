import UIKit
import SwiftData

// MARK: - Idea Category
enum IdeaCategory: String, CaseIterable, Identifiable {
    case date, surprise, chore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: String(localized: "Going Out")
        case .surprise: String(localized: "Adventures")
        case .chore: String(localized: "At Home")
        }
    }

    var icon: String {
        switch self {
        case .date: "figure.walk.motion"
        case .surprise: "sparkles"
        case .chore: "house.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .date: .brandAccent
        case .surprise: .brandOrange
        case .chore: .brandViolet
        }
    }

    var placeholder: String {
        switch self {
        case .date: String(localized: "New date night or outing idea")
        case .surprise: String(localized: "New adventure or surprise idea")
        case .chore: String(localized: "Home or nesting project to share")
        }
    }
}

// MARK: - Idea
@Model
final class Idea {
    var id: UUID = UUID()
    var title: String
    var categoryRaw: String
    var isDone: Bool
    var createdAt: Date

    init(title: String, category: IdeaCategory) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.isDone = false
        self.createdAt = .now
    }

    var category: IdeaCategory { IdeaCategory(rawValue: categoryRaw) ?? .date }
}
