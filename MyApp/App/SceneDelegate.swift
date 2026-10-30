import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = .brandAccent
        window.overrideUserInterfaceStyle = AppTheme.current.interfaceStyle
        window.rootViewController = UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding)
            ? MainTabBarController()
            : OnboardingViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        TimerManager.shared.syncFromStartDate()
    }
}
