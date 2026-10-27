import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if LaunchArgument.isUITesting {
            UserDefaults.standard.set(false, forKey: DefaultsKey.hasCompletedOnboarding)
            CoupleProfile.current = CoupleProfile(yourName: "", partnerName: "", startDate: nil, howWeMet: "")
            CouplePhotoStore.remove()
            PartnerSyncService.shared.unlink()
        }
        DataBootstrap.run(context: DataStore.shared.context)
        if PartnerSyncService.isFeatureEnabled {
            PartnerSyncService.shared.start()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
