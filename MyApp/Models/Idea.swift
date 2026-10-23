import UIKit
import SwiftData

// MARK: - Idea Category
enum IdeaCategory: String, CaseIterable, Identifiable {
    case date, surprise, chore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: "Going Out"
        case .surprise: "Adventures"
        case .chore: "At Home"
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
        case .date: .systemPink
        case .surprise: .systemOrange
        case .chore: .systemBlue
        }
    }

    var placeholder: String {
        switch self {
        case .date: "New date night or outing idea"
        case .surprise: "New adventure or surprise idea"
        case .chore: "Home or nesting project to share"
        }
    }
}

// MARK: - Idea
@Model
final class Idea {
    var title: String
    var categoryRaw: String
    var isDone: Bool
    var createdAt: Date

    init(title: String, category: IdeaCategory) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.isDone = false
        self.createdAt = .now
    }

    var category: IdeaCategory { IdeaCategory(rawValue: categoryRaw) ?? .date }
}
