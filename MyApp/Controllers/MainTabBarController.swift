import UIKit
import SwiftUI

// MARK: - Root Tab Bar
final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.tintColor = .systemPink
        viewControllers = [
            makeTab(DashboardViewController(), title: "Dashboard", symbol: "chart.pie.fill"),
            makeTab(RitualsViewController(), title: "Rituals", symbol: "sparkles"),
            makeTab(InsightsViewController(), title: "Insights", symbol: "chart.bar.fill"),
            makeTab(SettingsViewController(), title: "Settings", symbol: "gearshape.fill"),
        ]
    }

    private func makeTab(_ root: UIViewController, title: String, symbol: String) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil)
        return navigationController
    }
}

#Preview {
    MainTabBarController()
}
