import XCTest

/// UI Tests for Daily Review Feature (Sprint 5)
///
/// Tests the "Rückblick" tab that shows completed tasks for the day.
final class DailyReviewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func navigateToRueckblick() {
        let rueckblickTab = app.tabBars.buttons["Rückblick"]
        if rueckblickTab.waitForExistence(timeout: 5) {
            rueckblickTab.tap()
        }
    }

    // MARK: - Tab Navigation Tests

    /// GIVEN: App is launched
    /// WHEN: User looks at tab bar
    /// THEN: "Rückblick" tab should exist
    /// EXPECTED TO FAIL: Tab doesn't exist yet
    func testRueckblickTabExists() throws {
        let rueckblickTab = app.tabBars.buttons["Rückblick"]
        XCTAssertTrue(
            rueckblickTab.waitForExistence(timeout: 5),
            "Rückblick tab should exist in tab bar"
        )
    }

    /// GIVEN: App is launched
    /// WHEN: User taps Rückblick tab
    /// THEN: DailyReviewView should open with navigation title
    /// EXPECTED TO FAIL: View doesn't exist yet
    func testRueckblickViewOpens() throws {
        navigateToRueckblick()

        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(
            navTitle.waitForExistence(timeout: 5),
            "Rückblick view should open with navigation title"
        )
    }

    // MARK: - Content Tests

    /// GIVEN: DailyReviewView is displayed
    /// WHEN: No focus blocks exist today
    /// THEN: Should show empty state message
    /// EXPECTED TO FAIL: View doesn't exist yet
    func testEmptyStateShown() throws {
        navigateToRueckblick()

        // Wait for view to load
        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "View should open")

        // Check for empty state text
        let emptyText = app.staticTexts["Heute noch keine Focus Blocks"]
        let hasBlocks = app.staticTexts["Erledigt"].exists

        XCTAssertTrue(
            emptyText.exists || hasBlocks,
            "Should show either empty state or blocks"
        )
    }

    // MARK: - Settings Tests

    /// GIVEN: DailyReviewView is displayed
    /// WHEN: Settings button is tapped
    /// THEN: Settings should open
    /// EXPECTED TO FAIL: View doesn't exist yet
    func testSettingsButtonWorks() throws {
        navigateToRueckblick()

        // Wait for view to load
        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "View should open")

        // Tap settings button
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 3),
            "Settings button should exist"
        )
        settingsButton.tap()

        // Settings should open
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings view should open"
        )
    }
}
