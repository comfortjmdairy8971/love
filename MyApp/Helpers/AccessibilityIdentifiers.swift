import Foundation

/// Stable identifiers for UI tests. `MyAppUITests/AppNavigationUITests.swift` mirrors the values it uses.
enum AccessibilityID {
    enum Onboarding {
        static let root = "onboarding.root"
        static let pageControl = "onboarding.pageControl"

        static let welcomePage = "onboarding.welcome"
        static let getStartedButton = "onboarding.welcome.getStarted"

        static let namesPage = "onboarding.names"
        static let yourNameField = "onboarding.names.yourName"
        static let partnerNameField = "onboarding.names.partnerName"
        static let namesContinueButton = "onboarding.names.continue"

        static let photoPage = "onboarding.photo"
        static let photoButton = "onboarding.photo.button"
        static let photoNextButton = "onboarding.photo.next"
        static let photoSkipButton = "onboarding.photo.skip"

        static let anniversaryPage = "onboarding.anniversary"
        static let anniversaryPicker = "onboarding.anniversary.datePicker"
        static let anniversaryContinueButton = "onboarding.anniversary.continue"

        static let howWeMetPage = "onboarding.howWeMet"
        static let howWeMetText = "onboarding.howWeMet.text"
        static let howWeMetNextButton = "onboarding.howWeMet.next"
        static let howWeMetSkipButton = "onboarding.howWeMet.skip"

        static let goalsPage = "onboarding.goals"
        static let continueButton = "onboarding.goals.continue"
        static func goalStepper(_ category: ActivityCategory) -> String { "onboarding.goals.stepper.\(category.rawValue)" }

        static let ritualsPage = "onboarding.rituals"
        static let startTrackingButton = "onboarding.rituals.startTracking"
        static func ritualPreset(_ slug: String) -> String { "onboarding.rituals.preset.\(slug)" }
    }

    enum Tab {
        static let bar = "tabBar.main"
        static let dashboard = "tab.dashboard"
        static let rituals = "tab.rituals"
        static let insights = "tab.insights"
        static let settings = "tab.settings"
    }

    enum Dashboard {
        static let screen = "dashboard.screen"
        static let coupleHeader = "dashboard.coupleHeader"
        static let couplePhoto = "dashboard.couplePhoto"
        static let livePillStart = "dashboard.livePill.start"
        static let livePillStop = "dashboard.livePill.stop"
        static let rings = "dashboard.rings"
        static func card(_ category: ActivityCategory) -> String { "dashboard.card.\(category.rawValue)" }
        static func quickAdd(_ category: ActivityCategory) -> String { "dashboard.card.\(category.rawValue).quickAdd" }
    }

    enum Rituals {
        static let screen = "rituals.screen"
        static let modeControl = "rituals.modeControl"
        static let addButton = "rituals.addButton"
        static let table = "rituals.table"
        static let checkButton = "rituals.cell.check"
    }

    enum Insights {
        static let screen = "insights.screen"
        static let rangeControl = "insights.rangeControl"
        static let monthControl = "insights.monthControl"
        static let shareRecapButton = "insights.shareRecap"
    }

    enum Settings {
        static let screen = "settings.screen"
        static let table = "settings.table"
        static let yourNameField = "settings.couple.yourName"
        static let partnerNameField = "settings.couple.partnerName"
        static let startDatePicker = "settings.couple.startDate"
        static let howWeMetField = "settings.couple.howWeMet"
        static let couplePhoto = "settings.couple.photo"
        static func goalStepper(_ category: ActivityCategory) -> String { "settings.goal.stepper.\(category.rawValue)" }
        static let themeControl = "settings.themeControl"
        static let createInvite = "settings.sync.createInvite"
        static let joinInvite = "settings.sync.joinInvite"
        static let syncNow = "settings.sync.syncNow"
        static let copyCode = "settings.sync.copyCode"
        static let unlink = "settings.sync.unlink"
        static let replayOnboarding = "settings.replayOnboarding"
        static let resetWeek = "settings.resetWeek"
        static let eraseAll = "settings.eraseAll"
    }
}

/// Launch arguments understood by the app.
enum LaunchArgument {
    static let resetOnboarding = "-UITesting_ResetOnboarding"
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains(resetOnboarding) }
}
