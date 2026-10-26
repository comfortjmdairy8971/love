import UIKit
import SwiftData
import SwiftUI

// MARK: - Onboarding
final class OnboardingViewController: UIPageViewController {
    private let store = DataStore.shared
    private let pageControl = UIPageControl()

    private lazy var welcomePage = OnboardingWelcomeViewController()
    private lazy var goalsPage = OnboardingGoalsViewController()
    private lazy var ritualsPage = OnboardingRitualsViewController()
    private lazy var pages: [OnboardingPageViewController] = [welcomePage, goalsPage, ritualsPage]

    init() {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = AccessibilityID.Onboarding.root
        dataSource = self
        delegate = self

        welcomePage.onAction = { [weak self] in self?.advance(to: 1) }
        goalsPage.onAction = { [weak self] in self?.advance(to: 2) }
        ritualsPage.onAction = { [weak self] in self?.finish() }
        setViewControllers([welcomePage], direction: .forward, animated: false)

        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPageIndicatorTintColor = .systemPink
        pageControl.pageIndicatorTintColor = UIColor.systemPink.withAlphaComponent(0.25)
        pageControl.backgroundStyle = .prominent
        pageControl.accessibilityIdentifier = AccessibilityID.Onboarding.pageControl
        pageControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.advance(to: self.pageControl.currentPage, updatingPageControl: false)
        }, for: .valueChanged)
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    private var currentIndex: Int {
        viewControllers?.first.flatMap { page in pages.firstIndex { $0 === page } } ?? 0
    }

    private func advance(to index: Int, updatingPageControl: Bool = true) {
        guard pages.indices.contains(index), index != currentIndex else { return }
        Haptics.light()
        let direction: NavigationDirection = index > currentIndex ? .forward : .reverse
        if updatingPageControl { pageControl.currentPage = index }
        setViewControllers([pages[index]], direction: direction, animated: true)
    }

    private func finish() {
        for category in ActivityCategory.allCases {
            store.setGoal(goalsPage.minutes(for: category), for: category, from: self)
        }

        let existingTitles = Set(store.rituals.map { $0.title.lowercased() })
        for preset in ritualsPage.selectedPresets where !existingTitles.contains(preset.title.lowercased()) {
            store.context.insert(Ritual(title: preset.title, icon: preset.icon, frequency: preset.frequency))
        }
        store.commit(from: self)

        Haptics.success()
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
        AppRouter.transition(to: MainTabBarController(), in: view.window)
    }
}

// MARK: - Page Data Source & Delegate
extension OnboardingViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index > 0 else { return nil }
        return pages[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        if completed { pageControl.currentPage = currentIndex }
    }
}

#Preview {
    OnboardingViewController()
}
