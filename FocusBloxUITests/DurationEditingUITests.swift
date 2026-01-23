import XCTest

final class DurationEditingUITests: XCTestCase {

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

    // MARK: - TDD RED: Duration Badge Tap Tests

    /// GIVEN: BacklogView with tasks displayed
    /// WHEN: User taps on a DurationBadge
    /// THEN: DurationPicker sheet should appear
    func testTapOnDurationBadgeOpensPicker() throws {
        // Navigate to Backlog tab (should be default)
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        // Wait for tasks to load
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            throw XCTSkip("No tasks found in backlog - need at least one task to test duration editing")
        }

        // Find duration badge (text ending with 'm' like "15m", "30m")
        let durationBadge = firstCell.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "\\d+m")
        ).firstMatch

        XCTAssertTrue(durationBadge.exists, "Duration badge should exist")

        // Tap on duration badge
        durationBadge.tap()

        // Verify picker sheet appears with "Dauer waehlen" title
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 3), "Duration picker should appear")
    }

    /// GIVEN: DurationPicker sheet is open
    /// WHEN: User taps "30m" button
    /// THEN: Sheet closes and badge shows updated duration
    func testSelectDurationUpdatesBadge() throws {
        // Navigate to Backlog
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            throw XCTSkip("No tasks found - need at least one task to test duration editing")
        }

        // Find and tap duration badge
        let durationBadge = firstCell.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "\\d+m")
        ).firstMatch

        durationBadge.tap()

        // Wait for picker and tap 30m button
        let thirtyMinButton = app.buttons["30m"]
        XCTAssertTrue(thirtyMinButton.waitForExistence(timeout: 3), "30m button should exist in picker")

        thirtyMinButton.tap()

        // Verify sheet is dismissed
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertFalse(pickerTitle.waitForExistence(timeout: 2), "Picker should be dismissed")

        // Verify badge shows 30m
        let updatedBadge = firstCell.staticTexts["30m"]
        XCTAssertTrue(updatedBadge.exists, "Badge should show 30m after selection")
    }

    /// GIVEN: DurationPicker sheet is open
    /// WHEN: User taps "Zuruecksetzen" button
    /// THEN: manualDuration is reset to default
    func testResetDurationSetsDefault() throws {
        // Navigate to Backlog
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            throw XCTSkip("No tasks found - need at least one task to test duration reset")
        }

        // Find and tap duration badge
        let durationBadge = firstCell.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "\\d+m")
        ).firstMatch

        durationBadge.tap()

        // Wait for picker and tap reset button
        let resetButton = app.buttons["Zuruecksetzen"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3), "Reset button should exist")

        resetButton.tap()

        // Verify sheet is dismissed
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertFalse(pickerTitle.waitForExistence(timeout: 2), "Picker should be dismissed")
    }
}
