import XCTest

/// Walks through onboarding and every main tab, attaching a screenshot of each screen to the test report.
@MainActor
final class AppNavigationUITests: XCTestCase {
    /// Mirrors `AccessibilityID` in the app target (UI tests can't import the app module).
    private enum ID {
        static let welcomePage = "onboarding.welcome"
        static let getStartedButton = "onboarding.welcome.getStarted"
        static let goalsPage = "onboarding.goals"
        static let continueButton = "onboarding.goals.continue"
        static let ritualsPage = "onboarding.rituals"
        static let fridayDinnerPreset = "onboarding.rituals.preset.fridayDinner"
        static let startTrackingButton = "onboarding.rituals.startTracking"
    }

    private struct Tab {
        let label: String
        let identifier: String
        let screen: String
        let screenshot: String
    }

    private let tabs = [
        Tab(label: "Dashboard", identifier: "tab.dashboard", screen: "dashboard.screen", screenshot: "04_Tab_Dashboard"),
        Tab(label: "Rituals", identifier: "tab.rituals", screen: "rituals.screen", screenshot: "05_Tab_Rituals"),
        Tab(label: "Insights", identifier: "tab.insights", screen: "insights.screen", screenshot: "06_Tab_Insights"),
        Tab(label: "Settings", identifier: "tab.settings", screen: "settings.screen", screenshot: "07_Tab_Settings"),
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting_ResetOnboarding"]
        app.launch()
        self.app = app
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testOnboardingAndMainTabNavigation() throws {
        XCTContext.runActivity(named: "Onboarding") { _ in
            XCTAssertTrue(element(ID.welcomePage).waitForExistence(timeout: 10), "Onboarding did not start on the Welcome page")
            let getStarted = app.buttons[ID.getStartedButton]
            waitUntilHittable(getStarted)
            takeScreenshot(named: "01_Onboarding_Welcome")
            getStarted.tap()

            XCTAssertTrue(element(ID.goalsPage).waitForExistence(timeout: 5), "Goals page did not appear")
            let continueButton = app.buttons[ID.continueButton]
            waitUntilHittable(continueButton)
            takeScreenshot(named: "02_Onboarding_Goals")
            continueButton.tap()

            XCTAssertTrue(element(ID.ritualsPage).waitForExistence(timeout: 5), "Rituals page did not appear")
            let fridayDinner = element(ID.fridayDinnerPreset)
            waitUntilHittable(fridayDinner)
            fridayDinner.tap()
            XCTAssertTrue(fridayDinner.isSelected, "Friday Dinner preset should be selected after tapping it")
            takeScreenshot(named: "03_Onboarding_Rituals")
            app.buttons[ID.startTrackingButton].tap()
        }

        XCTContext.runActivity(named: "Main Tabs") { _ in
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Main tab bar did not appear after onboarding")

            for (index, tab) in tabs.enumerated() {
                let button = tabButton(for: tab, at: index, in: tabBar)
                XCTAssertTrue(button.waitForExistence(timeout: 5), "\(tab.label) tab button not found")
                // The floating tab bar reports unselected tabs as not hittable, so tap their center directly.
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertTrue(element(tab.screen).waitForExistence(timeout: 5), "\(tab.label) screen did not appear")
                takeScreenshot(named: tab.screenshot)
            }
        }
    }

    // MARK: Helpers
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Prefers the accessibility identifier, then the visible label, then the tab's position.
    private func tabButton(for tab: Tab, at index: Int, in tabBar: XCUIElement) -> XCUIElement {
        let byIdentifier = tabBar.buttons[tab.identifier]
        if byIdentifier.exists { return byIdentifier }
        let byLabel = tabBar.buttons[tab.label]
        if byLabel.exists { return byLabel }
        return tabBar.buttons.element(boundBy: index)
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) was not hittable within \(timeout)s", file: file, line: line)
    }
}
