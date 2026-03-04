import XCTest

/// UI Tests fuer Badge-Overdue + Interaktive Notifications Feature.
/// Notification-Actions sind System-UI und nicht per XCUITest simulierbar.
/// Diese Tests verifizieren, dass die NotificationActionDelegate-Integration
/// beim App-Start keine Crashes verursacht und die App korrekt funktioniert.
final class BadgeOverdueUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Verhalten: App startet korrekt mit NotificationActionDelegate + Category-Registration
    /// Bricht wenn: registerDueDateActions() oder Delegate-Setup in .onAppear crasht
    func testAppLaunchesWithNotificationDelegate() throws {
        // App should launch without crash — verifies that registerDueDateActions()
        // and NotificationActionDelegate setup in .onAppear work correctly
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App should launch and show tab bar")
    }

    /// Verhalten: Backlog-Tab ist erreichbar nach Delegate-Setup
    /// Bricht wenn: NotificationActionDelegate-Retain-Cycle die App-Navigation blockiert
    func testBacklogNavigationWorksWithDelegateSetup() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Verify backlog content loads — delegate setup should not interfere
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Backlog navigation should load")
    }
}
