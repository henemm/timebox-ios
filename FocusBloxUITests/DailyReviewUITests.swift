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

    // MARK: - Weekly Review Tests (Sprint 6)

    /// GIVEN: DailyReviewView is displayed
    /// WHEN: User looks at view
    /// THEN: Segmented picker with "Heute" and "Diese Woche" should exist
    /// EXPECTED TO FAIL: Segmented picker doesn't exist yet
    func testSegmentedPickerExists() throws {
        navigateToRueckblick()

        // Wait for view to load
        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "View should open")

        // Check for segmented picker buttons
        let heuteButton = app.buttons["Heute"]
        let dieseWocheButton = app.buttons["Diese Woche"]

        XCTAssertTrue(
            heuteButton.waitForExistence(timeout: 3),
            "Segmented picker should have 'Heute' option"
        )
        XCTAssertTrue(
            dieseWocheButton.exists,
            "Segmented picker should have 'Diese Woche' option"
        )
    }

    /// GIVEN: DailyReviewView is displayed
    /// WHEN: User taps "Diese Woche" segment
    /// THEN: Weekly view should be shown with week date range header
    /// EXPECTED TO FAIL: Weekly view doesn't exist yet
    func testWeeklyViewShown() throws {
        navigateToRueckblick()

        // Wait for view to load
        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "View should open")

        // Tap "Diese Woche" segment
        let dieseWocheButton = app.buttons["Diese Woche"]
        XCTAssertTrue(
            dieseWocheButton.waitForExistence(timeout: 3),
            "Diese Woche button should exist"
        )
        dieseWocheButton.tap()

        // Weekly view should show date range (e.g., "20. - 26. Jan")
        // We check for the pattern of week range or the "Diese Woche" text
        let weekHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] ' - '")
        ).firstMatch

        // Either we have blocks with a date range header, or empty state
        let emptyState = app.staticTexts["Diese Woche noch keine Focus Blocks"]

        XCTAssertTrue(
            weekHeader.waitForExistence(timeout: 3) || emptyState.exists,
            "Weekly view should show date range header or empty state"
        )
    }

    /// GIVEN: DailyReviewView is in weekly mode
    /// WHEN: No focus blocks exist this week
    /// THEN: Should show weekly empty state message
    /// EXPECTED TO FAIL: Weekly empty state doesn't exist yet
    func testWeeklyEmptyState() throws {
        navigateToRueckblick()

        // Wait for view to load
        let navTitle = app.navigationBars["Rückblick"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "View should open")

        // Tap "Diese Woche" segment
        let dieseWocheButton = app.buttons["Diese Woche"]
        XCTAssertTrue(
            dieseWocheButton.waitForExistence(timeout: 3),
            "Diese Woche button should exist"
        )
        dieseWocheButton.tap()

        // Check for empty state text OR actual content
        // (We can't guarantee no blocks exist in test environment)
        let emptyText = app.staticTexts["Diese Woche noch keine Focus Blocks"]
        let hasContent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] ' - '")
        ).firstMatch.exists

        XCTAssertTrue(
            emptyText.waitForExistence(timeout: 3) || hasContent,
            "Should show either empty state or weekly content"
        )
    }
}
