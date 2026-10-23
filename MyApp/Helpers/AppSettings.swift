import UIKit

enum DefaultsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appTheme = "appTheme"
}

// MARK: - Theme
enum AppTheme: Int, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    static var current: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.integer(forKey: DefaultsKey.appTheme)) ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.appTheme)
            applyToAllWindows()
        }
    }

    static func applyToAllWindows() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = current.interfaceStyle }
        }
    }
}

// MARK: - Root Routing
enum AppRouter {
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.hasCompletedOnboarding) }
    }

    static func makeRootViewController() -> UIViewController {
        hasCompletedOnboarding ? MainTabBarController() : OnboardingViewController()
    }

    /// Cross-fades the window's root view controller.
    static func transition(to root: UIViewController, in window: UIWindow?) {
        guard let window else { return }
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            let wasEnabled = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            window.rootViewController = root
            UIView.setAnimationsEnabled(wasEnabled)
        }
    }
}
