import Foundation

// MARK: - Ritual Preset Catalog
/// Built-in rituals identified by a stable `slug` so localized titles never insert duplicates.
struct RitualPreset: Equatable, Identifiable {
    var id: String { slug }

    let slug: String
    let icon: String
    let frequency: RitualFrequency
    /// English source string — always looked up via `String(localized:)`.
    let titleKey: String
    /// Historical titles (any language) used to recognize already-saved rows.
    let aliases: [String]

    var title: String { String(localized: String.LocalizationValue(titleKey)) }

    static let onboarding: [RitualPreset] = [
        .init(
            slug: "friday_dinner_out",
            icon: "fork.knife",
            frequency: .weekly,
            titleKey: "Friday Dinner Out",
            aliases: ["Friday Dinner Out", "Dîner du vendredi", "Friday Date Night", "Soirée du vendredi"]
        ),
        .init(
            slug: "sunday_morning_walk",
            icon: "figure.walk",
            frequency: .weekly,
            titleKey: "Sunday Morning Walk",
            aliases: ["Sunday Morning Walk", "Promenade du dimanche matin", "Sunday walk", "Promenade du dimanche"]
        ),
        .init(
            slug: "weekly_check_in",
            icon: "bubble.left.and.bubble.right.fill",
            frequency: .weekly,
            titleKey: "Weekly Check-in",
            aliases: ["Weekly Check-in", "Point hebdomadaire", "Weekly Sync"]
        ),
        .init(
            slug: "phone_free_evening",
            icon: "iphone.slash",
            frequency: .weekly,
            titleKey: "Phone-Free Evening",
            aliases: ["Phone-Free Evening", "Soirée sans téléphone"]
        ),
    ]

    static let suggestions: [RitualPreset] = [
        .init(
            slug: "friday_date_night",
            icon: "moon.stars.fill",
            frequency: .weekly,
            titleKey: "Friday Date Night",
            aliases: ["Friday Date Night", "Soirée du vendredi"]
        ),
        .init(
            slug: "morning_coffee",
            icon: "cup.and.saucer.fill",
            frequency: .daily,
            titleKey: "Morning coffee together",
            aliases: ["Morning coffee together", "Café du matin à deux"]
        ),
        .init(
            slug: "sunday_walk",
            icon: "figure.walk",
            frequency: .weekly,
            titleKey: "Sunday walk",
            aliases: ["Sunday walk", "Promenade du dimanche"]
        ),
        .init(
            slug: "monthly_adventure",
            icon: "map.fill",
            frequency: .monthly,
            titleKey: "Monthly adventure",
            aliases: ["Monthly adventure", "Aventure du mois"]
        ),
    ]

    static var all: [RitualPreset] { onboarding + suggestions }

    static func matching(title: String) -> RitualPreset? {
        let needle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        if let exact = all.first(where: { $0.titleKey.lowercased() == needle || $0.title.lowercased() == needle }) {
            return exact
        }
        return all.first { preset in
            preset.aliases.contains { $0.lowercased() == needle }
        }
    }

    static func matching(slug: String) -> RitualPreset? {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        let compact = key.replacingOccurrences(of: "_", with: "").lowercased()
        return all.first {
            $0.slug == key
                || $0.slug.replacingOccurrences(of: "_", with: "").lowercased() == compact
        }
    }
}
