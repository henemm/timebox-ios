import XCTest

/// UI Tests for Due Date Notification Settings
/// TDD RED: These tests MUST FAIL because the Settings section doesn't exist yet
final class DueDateNotificationUITests: XCTestCase {

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

    // MARK: - Helper

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    // MARK: - Settings Section Tests

    /// GIVEN: Settings view is open
    /// WHEN: Scrolling through sections
    /// THEN: Section "Frist-Erinnerungen" should exist
    /// EXPECTED TO FAIL: Section doesn't exist yet
    func testSettingsSectionVisible() throws {
        navigateToSettings()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")

        // Look for the morning reminder toggle as proof that the section exists
        let morningToggle = app.switches["morningReminderToggle"]
        XCTAssertTrue(morningToggle.waitForExistence(timeout: 3),
                      "Morning reminder toggle should exist in Frist-Erinnerungen section")
    }

    /// GIVEN: Settings view is open, morning reminder toggle exists
    /// WHEN: Toggling morning reminder ON
    /// THEN: Time picker for morning hour should appear
    /// EXPECTED TO FAIL: Toggle and picker don't exist yet
    func testMorningReminderToggleShowsTimePicker() throws {
        navigateToSettings()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")

        let morningToggle = app.switches["morningReminderToggle"]
        XCTAssertTrue(morningToggle.waitForExistence(timeout: 3), "Morning reminder toggle should exist")

        // Toggle ON if it's OFF
        if morningToggle.value as? String == "0" {
            morningToggle.tap()
        }

        // Time picker should appear
        let timePicker = app.datePickers["morningTimePicker"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: 3),
                      "Morning time picker should appear when toggle is ON")
    }

}
