import XCTest

/// UI Tests for Task Debug Mode Settings (FEATURE_030).
final class TaskDebugModeUITests: XCTestCase {

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

    /// Taps the switch knob on the right side of a SwiftUI Toggle.
    /// Standard `toggle.tap()` hits the label area and doesn't change the value on iOS 26.
    private func tapToggleSwitch(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Scrolls down in Settings to find the debug toggle at the bottom.
    @discardableResult
    private func scrollToDebugToggle() -> XCUIElement {
        let toggle = app.switches["taskDebugModeToggle"]
        if toggle.exists && toggle.isHittable {
            return toggle
        }
        // Scroll down in the settings form
        let form = app.collectionViews.firstMatch
        for _ in 0..<6 {
            form.swipeUp()
            if toggle.exists && toggle.isHittable {
                return toggle
            }
        }
        return toggle
    }

    // MARK: - Settings Toggle

    /// GIVEN: Settings view is open
    /// WHEN: Scrolling to "Entwickler" section at the bottom
    /// THEN: A toggle "Task Debug Mode" should exist
    func testDebugModeToggleExistsInSettings() throws {
        navigateToSettings()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")

        let toggle = scrollToDebugToggle()
        XCTAssertTrue(toggle.exists, "Task Debug Mode toggle should exist in Settings")
    }

    /// GIVEN: Settings view with Debug Mode toggle visible
    /// WHEN: Tapping the toggle switch knob
    /// THEN: The toggle state should change
    func testDebugModeToggleCanBeToggled() throws {
        navigateToSettings()

        let toggle = scrollToDebugToggle()
        guard toggle.exists else {
            XCTFail("Task Debug Mode toggle should exist")
            return
        }

        let initialValue = toggle.value as? String ?? "0"
        tapToggleSwitch(toggle)

        // Poll for value change (iOS 26 needs a moment after coordinate tap)
        var newValue = toggle.value as? String ?? "0"
        for _ in 0..<10 where newValue == initialValue {
            Thread.sleep(forTimeInterval: 0.3)
            newValue = toggle.value as? String ?? "0"
        }

        XCTAssertNotEqual(initialValue, newValue, "Toggle state should change after tap")
    }

    /// GIVEN: Debug Mode is enabled
    /// WHEN: Looking at the Entwickler section
    /// THEN: A "Lifecycle Log anzeigen" button should appear
    func testLifecycleLogButtonExistsWhenEnabled() throws {
        navigateToSettings()

        let toggle = scrollToDebugToggle()
        guard toggle.exists else {
            XCTFail("Task Debug Mode toggle should exist")
            return
        }

        // Enable debug mode via coordinate tap on switch knob
        if toggle.value as? String == "0" {
            tapToggleSwitch(toggle)
        }

        let logButton = app.buttons["showLifecycleLogButton"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Lifecycle Log button should appear when debug mode is on")
    }

    /// GIVEN: Debug Mode is enabled
    /// WHEN: Tapping "Lifecycle Log anzeigen"
    /// THEN: A sheet with log content should open
    func testLogSheetOpens() throws {
        navigateToSettings()

        let toggle = scrollToDebugToggle()
        guard toggle.exists else {
            XCTFail("Task Debug Mode toggle should exist")
            return
        }

        // Enable debug mode
        if toggle.value as? String == "0" {
            tapToggleSwitch(toggle)
        }

        let logButton = app.buttons["showLifecycleLogButton"]
        guard logButton.waitForExistence(timeout: 5) else {
            XCTFail("Lifecycle Log button should exist")
            return
        }

        logButton.tap()

        // Sheet should contain log text view
        let logText = app.staticTexts["lifecycleLogContent"].firstMatch
        XCTAssertTrue(logText.waitForExistence(timeout: 3), "Log content should be visible in sheet")
    }
}
