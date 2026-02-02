import XCTest

/// TDD-RED: UI Tests for Bug 25 - SwiftData Error on App Launch
/// The app shows "Fehler - SwiftDataError error 1" instead of tasks
final class SwiftDataErrorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // DON'T use -UITesting flag - we want to test real SwiftData behavior
        // NOT the mock data
        app.launchArguments = ["-ResetUserDefaults"]
        app.launch()

        // Handle permission dialogs
        handlePermissionDialogs()
    }

    private func handlePermissionDialogs() {
        // Handle any system alerts (Notifications, Reminders, Calendar)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // Try to dismiss up to 3 permission dialogs
        for _ in 0..<3 {
            sleep(1)
            let allowButton = springboard.buttons["Erlauben"]
            if allowButton.waitForExistence(timeout: 2) {
                allowButton.tap()
            }
            let allowButtonEN = springboard.buttons["Allow"]
            if allowButtonEN.waitForExistence(timeout: 1) {
                allowButtonEN.tap()
            }
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - TDD-RED Tests

    /// Test that BacklogView shows tasks, not an error
    /// This test will FAIL if SwiftDataError occurs
    func testBacklogViewShowsNoError() throws {
        // GIVEN: App is launched

        // WHEN: Looking at the Backlog tab (should be default)
        // Wait for app to load
        sleep(2)

        // THEN: No error should be visible
        let errorView = app.staticTexts["Fehler"]
        let hasError = errorView.waitForExistence(timeout: 3)

        // Take screenshot for evidence
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BacklogView-State"
        attachment.lifetime = .keepAlways
        add(attachment)

        // If error is shown, test fails (TDD-RED)
        XCTAssertFalse(hasError, "BacklogView should NOT show 'Fehler' - SwiftData should work")
    }

    /// Test that app can display task list without SwiftData errors
    func testAppLaunchesWithoutSwiftDataError() throws {
        // GIVEN: App is launched

        // WHEN: Waiting for initial load
        sleep(2)

        // THEN: Check for SwiftDataError in any text
        let swiftDataError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SwiftDataError'"))

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AppLaunch-SwiftDataCheck"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(swiftDataError.count, 0, "No SwiftDataError should be visible on app launch")
    }

    /// Test that Backlog tab is functional (can see task list or empty state)
    func testBacklogTabIsFunctional() throws {
        // GIVEN: App is launched

        // WHEN: Tapping Backlog tab (if not already there)
        let backlogTab = app.buttons["Backlog"]
        if backlogTab.exists {
            backlogTab.tap()
        }

        sleep(2)

        // THEN: Should see either tasks OR empty state, but NOT error
        let errorView = app.staticTexts["Fehler"]
        let emptyState = app.staticTexts["Keine Tasks"]
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BacklogTab-Functional"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Either empty state or view mode switcher should be visible (NOT error)
        let isFunctional = emptyState.exists || viewModeSwitcher.exists
        let hasError = errorView.exists

        XCTAssertFalse(hasError, "Backlog should not show error state")
        XCTAssertTrue(isFunctional, "Backlog should show either tasks or empty state")
    }
}
