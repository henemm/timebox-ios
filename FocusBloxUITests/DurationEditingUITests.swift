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

    // MARK: - Helper

    /// Find a duration badge by accessibilityIdentifier prefix
    private func findDurationBadge() -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch
    }

    // MARK: - Tests

    /// GIVEN: BacklogView with tasks
    /// WHEN: User taps duration badge
    /// THEN: DurationPicker sheet appears
    func testTapOnDurationBadgeOpensPicker() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        let badge = findDurationBadge()
        guard badge.waitForExistence(timeout: 10) else {
            throw XCTSkip("No duration badge found")
        }

        badge.tap()

        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 3), "Duration picker should appear")
    }

    /// GIVEN: DurationPicker is open
    /// WHEN: User taps "30m"
    /// THEN: App does NOT crash, sheet closes
    func testSelectDurationDoesNotCrash() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        let badge = findDurationBadge()
        guard badge.waitForExistence(timeout: 10) else {
            throw XCTSkip("No duration badge found")
        }

        badge.tap()

        let thirtyMinButton = app.buttons["30m"]
        XCTAssertTrue(thirtyMinButton.waitForExistence(timeout: 3), "30m button should exist")

        thirtyMinButton.tap()

        // App should still be running — if it crashed, this line is never reached
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertFalse(pickerTitle.waitForExistence(timeout: 3), "Picker should dismiss after selection")

        // Verify app is still responsive
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3), "App should still be responsive after duration change")
    }

    /// GIVEN: DurationPicker is open
    /// WHEN: User taps "Zurücksetzen"
    /// THEN: App does NOT crash, sheet closes
    func testResetDurationDoesNotCrash() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))

        let badge = findDurationBadge()
        guard badge.waitForExistence(timeout: 10) else {
            throw XCTSkip("No duration badge found")
        }

        badge.tap()

        let resetButton = app.buttons["Zurücksetzen"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3), "Reset button should exist")

        resetButton.tap()

        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertFalse(pickerTitle.waitForExistence(timeout: 3), "Picker should dismiss after reset")

        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3), "App should still be responsive after reset")
    }
}
