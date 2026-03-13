import XCTest

final class CoachNotificationSettingsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helper

    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("settingsButton not found")
            return
        }
        settingsButton.tap()
        // Wait for settings sheet to appear
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 5)
    }

    private func relaunchWithCoachMode(nudgesEnabled: Bool = true) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-coachModeEnabled", "1",
            "-coachDailyNudgesEnabled", nudgesEnabled ? "1" : "0",
            "-coachEveningReminderEnabled", "0"
        ]
        app.launch()
    }

    /// Scroll to find a specific element using gentle coordinate-based swipes on the form
    private func scrollToElement(_ element: XCUIElement) {
        for _ in 0..<20 {
            if element.exists && element.isHittable { return }
            // Gentle swipe: drag from center-bottom to center-top of the screen
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    // MARK: - Visibility based on Coach Mode

    /// Verhalten: Tages-Erinnerungen Toggle ist unsichtbar wenn Coach-Modus aus.
    func test_coachNotificationSettings_areHiddenWhenCoachModeOff() throws {
        // Default: coach mode is off
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let nudgesToggle = app.switches["coachDailyNudgesToggle"]
        XCTAssertFalse(nudgesToggle.exists, "Nudges toggle should be hidden when coach mode is off")
    }

    /// Verhalten: Tages-Erinnerungen Toggle ist sichtbar wenn Coach-Modus an.
    func test_coachDailyNudgesToggle_isVisibleWhenCoachModeOn() throws {
        relaunchWithCoachMode()
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])
        // Might need one more swipe to reveal the nudges toggle below the header
        scrollToElement(app.switches["coachDailyNudgesToggle"])

        let nudgesToggle = app.switches["coachDailyNudgesToggle"]
        XCTAssertTrue(nudgesToggle.waitForExistence(timeout: 5), "Nudges toggle should exist when coach mode is on")
    }

    /// Verhalten: Max/Von/Bis Controls sind unsichtbar wenn Nudges deaktiviert.
    func test_coachNudgeSettings_areHiddenWhenNudgesDisabled() throws {
        relaunchWithCoachMode(nudgesEnabled: false)
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let nudgesToggle = app.switches["coachDailyNudgesToggle"]
        scrollToElement(nudgesToggle)
        guard nudgesToggle.waitForExistence(timeout: 5) else {
            XCTFail("coachDailyNudgesToggle not found after enabling coach mode")
            return
        }

        XCTAssertFalse(app.segmentedControls["coachNudgesMaxCountPicker"].exists,
                        "Max count picker should be hidden when nudges disabled")
        XCTAssertFalse(app.datePickers["coachNudgeWindowStartPicker"].exists,
                        "Window start picker should be hidden when nudges disabled")
        XCTAssertFalse(app.datePickers["coachNudgeWindowEndPicker"].exists,
                        "Window end picker should be hidden when nudges disabled")
    }

    /// Verhalten: Max/Von/Bis Controls sind sichtbar wenn Nudges aktiviert.
    func test_coachNudgeSettings_areVisibleWhenNudgesEnabled() throws {
        relaunchWithCoachMode(nudgesEnabled: true)
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let nudgesToggle = app.switches["coachDailyNudgesToggle"]
        scrollToElement(nudgesToggle)
        guard nudgesToggle.waitForExistence(timeout: 5) else {
            XCTFail("coachDailyNudgesToggle not found")
            return
        }

        let picker = app.segmentedControls["coachNudgesMaxCountPicker"]
        scrollToElement(picker)
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                       "Max count picker should be visible when nudges enabled")

        let startPicker = app.datePickers["coachNudgeWindowStartPicker"]
        scrollToElement(startPicker)
        XCTAssertTrue(startPicker.waitForExistence(timeout: 3),
                       "Window start picker should be visible when nudges enabled")

        let endPicker = app.datePickers["coachNudgeWindowEndPicker"]
        scrollToElement(endPicker)
        XCTAssertTrue(endPicker.waitForExistence(timeout: 3),
                       "Window end picker should be visible when nudges enabled")
    }

    // MARK: - Evening Reminder Settings

    private func relaunchWithCoachModeAndEvening(eveningEnabled: Bool = true) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-coachModeEnabled", "1",
            "-coachDailyNudgesEnabled", "0",
            "-coachEveningReminderEnabled", eveningEnabled ? "1" : "0"
        ]
        app.launch()
    }

    /// Verhalten: Abend-Erinnerung Toggle ist sichtbar wenn Coach Mode aktiv.
    /// Bricht wenn: Toggle oder accessibilityIdentifier("coachEveningReminderToggle") nicht in SettingsView.
    func test_eveningReminderToggle_visibleWhenCoachModeOn() throws {
        relaunchWithCoachModeAndEvening()
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let eveningToggle = app.switches["coachEveningReminderToggle"]
        scrollToElement(eveningToggle)
        XCTAssertTrue(eveningToggle.waitForExistence(timeout: 5),
                       "Evening reminder toggle should exist when coach mode is on")
    }

    /// Verhalten: TimePicker ist sichtbar wenn Evening Reminder aktiviert.
    /// Bricht wenn: DatePicker nicht bedingt angezeigt oder Identifier fehlt.
    func test_eveningReminderTimePicker_visibleWhenEnabled() throws {
        relaunchWithCoachModeAndEvening(eveningEnabled: true)
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let eveningToggle = app.switches["coachEveningReminderToggle"]
        scrollToElement(eveningToggle)
        guard eveningToggle.waitForExistence(timeout: 5) else {
            XCTFail("coachEveningReminderToggle not found")
            return
        }

        let timePicker = app.datePickers["coachEveningReminderTimePicker"]
        scrollToElement(timePicker)
        XCTAssertTrue(timePicker.waitForExistence(timeout: 3),
                       "Time picker should be visible when evening reminder is enabled")
    }

    /// Verhalten: TimePicker ist versteckt wenn Evening Reminder deaktiviert.
    /// Bricht wenn: DatePicker immer sichtbar statt bedingt.
    func test_eveningReminderTimePicker_hiddenWhenDisabled() throws {
        relaunchWithCoachModeAndEvening(eveningEnabled: false)
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let eveningToggle = app.switches["coachEveningReminderToggle"]
        scrollToElement(eveningToggle)
        guard eveningToggle.waitForExistence(timeout: 5) else {
            XCTFail("coachEveningReminderToggle not found")
            return
        }

        let timePicker = app.datePickers["coachEveningReminderTimePicker"]
        XCTAssertFalse(timePicker.exists,
                        "Time picker should be hidden when evening reminder is disabled")
    }

    // MARK: - Nudge Max Count Picker

    /// Verhalten: Max-Picker hat drei Optionen: 1, 2, 3.
    func test_coachNudgesMaxCountPicker_hasThreeOptions() throws {
        relaunchWithCoachMode(nudgesEnabled: true)
        navigateToSettings()
        scrollToElement(app.switches["coachModeToggle"])

        let nudgesToggle = app.switches["coachDailyNudgesToggle"]
        scrollToElement(nudgesToggle)
        guard nudgesToggle.waitForExistence(timeout: 5) else {
            XCTFail("coachDailyNudgesToggle not found")
            return
        }

        let picker = app.segmentedControls["coachNudgesMaxCountPicker"]
        scrollToElement(picker)
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Max count picker should exist")

        // Segmented picker should show 1, 2, 3
        XCTAssertTrue(picker.buttons["1"].exists, "Option '1' should exist")
        XCTAssertTrue(picker.buttons["2"].exists, "Option '2' should exist")
        XCTAssertTrue(picker.buttons["3"].exists, "Option '3' should exist")
    }
}
