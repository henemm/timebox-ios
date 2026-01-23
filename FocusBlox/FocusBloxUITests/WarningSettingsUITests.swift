import XCTest

/// UI Tests for Warning Settings (Sprint 2)
/// TDD RED: These tests MUST FAIL because the feature doesn't exist yet
final class WarningSettingsUITests: XCTestCase {

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

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    // MARK: - Warning Toggle Tests

    /// GIVEN: Settings view is open
    /// WHEN: Looking at the settings form
    /// THEN: A toggle for "Vorwarnung" should exist
    /// EXPECTED TO FAIL: Toggle doesn't exist yet
    func testWarningToggleExistsInSettings() throws {
        navigateToSettings()

        // Wait for settings to appear
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")

        // Look for the warning toggle
        let warningToggle = app.switches["warningToggle"]
        XCTAssertTrue(warningToggle.waitForExistence(timeout: 3), "Warning toggle should exist in Settings")
    }

    /// GIVEN: Settings view is open with warning enabled
    /// WHEN: Looking at the warning section
    /// THEN: A picker for timing should exist
    /// EXPECTED TO FAIL: Picker doesn't exist yet
    func testWarningTimingPickerExistsWhenEnabled() throws {
        navigateToSettings()

        // Wait for settings to appear
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")

        // Look for the timing picker
        let timingPicker = app.buttons["warningTimingPicker"]
        XCTAssertTrue(timingPicker.waitForExistence(timeout: 3), "Warning timing picker should exist in Settings")
    }
}
