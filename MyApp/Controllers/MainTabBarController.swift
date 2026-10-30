import UIKit
import SwiftUI

// MARK: - Root Tab Bar
final class MainTabBarController: UITabBarController {
    /// Shared with every tab so the live timer is not recreated when switching.
    private let timerManager = TimerManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.tintColor = .brandAccent
        tabBar.accessibilityIdentifier = AccessibilityID.Tab.bar
        // Tab titles stay English so they fit the floating tab bar; screen content is localized.
        viewControllers = [
            makeTab(DashboardViewController(timerManager: timerManager), title: "Dashboard", symbol: "chart.pie.fill", identifier: AccessibilityID.Tab.dashboard),
            makeTab(RitualsViewController(), title: "Rituals", symbol: "sparkles", identifier: AccessibilityID.Tab.rituals),
            makeTab(InsightsViewController(), title: "Insights", symbol: "chart.bar.fill", identifier: AccessibilityID.Tab.insights),
            makeTab(SettingsViewController(), title: "Settings", symbol: "gearshape.fill", identifier: AccessibilityID.Tab.settings),
        ]
    }

    private func makeTab(_ root: UIViewController, title: String, symbol: String, identifier: String) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        let item = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil)
        item.accessibilityIdentifier = identifier
        navigationController.tabBarItem = item
        return navigationController
    }
}

#Preview {
    MainTabBarController()
}
