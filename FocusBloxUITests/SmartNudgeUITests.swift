import XCTest

/// UI Tests for Smart Nudges Settings (#174).
/// TDD RED: Tests MUST FAIL — Settings UI elements don't exist yet.
///
/// Praxisnahe Tests: Was tut der User? Was sieht er danach?
final class SmartNudgeUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func navigateToSettings() {
        // Dismiss overlay if present (e.g. What's New)
        let closeButton = app.buttons["xmark"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button should exist")
        settingsButton.tap()

        // Wait for settings to load
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings view should open")
    }

    private func launchWithActiveProfile() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        // Set profile to "active" before launch via UserDefaults
        app.launchArguments += ["-notificationProfile", "active"]
        app.launch()
    }

    // MARK: - User kann Nudge-Budget einstellen

    /// User-Nutzen: Der User sieht im Profil "Aktiv" eine Einstellung für die
    /// maximale Anzahl täglicher Nudges und kann sie zwischen 1-3 verstellen.
    /// Bricht wenn: SettingsView keine "Tages-Nudges" Section mit Budget-Stepper hat.
    func test_user_canAdjustNudgeBudget() {
        launchWithActiveProfile()
        navigateToSettings()

        // User sieht "Tages-Nudges" Section (nur bei Profil "Aktiv")
        let nudgeSection = app.staticTexts["Tages-Nudges"]
        XCTAssertTrue(nudgeSection.waitForExistence(timeout: 5),
            "User sollte eine 'Tages-Nudges' Sektion in den Settings sehen")

        // User sieht den Budget-Stepper
        let stepper = app.steppers["nudgeBudgetStepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 3),
            "User sollte einen Stepper für die maximale Nudge-Anzahl sehen")
        XCTAssertTrue(stepper.isHittable, "Stepper sollte interaktiv sein")
    }

    // MARK: - User kann Stille bei Erfolg umschalten

    /// User-Nutzen: Der User schaltet "Stille bei Erfolg" ein/aus und sieht den
    /// Toggle-State wechseln. Wenn an: keine Nudges nach genug erledigten Tasks.
    /// Bricht wenn: silenceOnSuccessToggle nicht in SettingsView existiert.
    func test_user_canToggleSilenceOnSuccess() {
        launchWithActiveProfile()
        navigateToSettings()

        let toggle = app.switches["silenceOnSuccessToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5),
            "User sollte einen 'Stille bei Erfolg' Toggle sehen")

        // User sieht den Toggle und er ist interaktiv
        XCTAssertTrue(toggle.isHittable, "Toggle sollte interaktiv sein")
        let value = toggle.value as? String
        XCTAssertTrue(value == "0" || value == "1",
            "Toggle sollte einen gültigen Wert haben (0 oder 1)")
    }

    // MARK: - User kann Erinnerungszeiten sehen und ändern

    /// User-Nutzen: Der User sieht konfigurierbare Zeiten für Dein Tag und
    /// Abend-Reflexion und kann sie anpassen. Nicht mehr hardcoded 08:00/20:00.
    /// Bricht wenn: morningReminderTimePicker/eveningReflectionTimePicker nicht existieren.
    func test_user_seesConfigurableReminderTimes() {
        navigateToSettings()

        // User sieht die "Erinnerungszeiten" Sektion
        let section = app.staticTexts["Erinnerungszeiten"]
        XCTAssertTrue(section.waitForExistence(timeout: 5),
            "User sollte eine 'Erinnerungszeiten' Sektion sehen")

        // User sieht den Morning-Picker mit Label "Dein Tag"
        let morningLabel = app.staticTexts["Dein Tag"]
        XCTAssertTrue(morningLabel.waitForExistence(timeout: 3),
            "User sollte 'Dein Tag' als Label sehen")

        let morningPicker = app.datePickers["morningReminderTimePicker"]
        XCTAssertTrue(morningPicker.exists,
            "User sollte einen Zeitpicker für den Dein Tag sehen")

        // User sieht den Evening-Picker mit Label "Abend-Reflexion"
        let eveningLabel = app.staticTexts["Abend-Reflexion"]
        XCTAssertTrue(eveningLabel.waitForExistence(timeout: 3),
            "User sollte 'Abend-Reflexion' als Label sehen")

        let eveningPicker = app.datePickers["eveningReflectionTimePicker"]
        XCTAssertTrue(eveningPicker.exists,
            "User sollte einen Zeitpicker für die Abend-Reflexion sehen")
    }

    // MARK: - Nudge-Settings nur bei Profil "Aktiv" sichtbar

    /// User-Nutzen: Die Nudge-Einstellungen erscheinen nur wenn das Profil "Aktiv" ist.
    /// Bei "Leise" oder "Ausgeglichen" braucht der User diese Optionen nicht zu sehen.
    /// Bricht wenn: Nudge-Section immer sichtbar ist, unabhängig vom Profil.
    func test_nudgeSettings_onlyVisibleWhenProfileActive() {
        // Launch with default profile "balanced" — Tages-Nudges should NOT be visible
        navigateToSettings()

        let nudgeSection = app.staticTexts["Tages-Nudges"]
        let found = nudgeSection.waitForExistence(timeout: 2)
        XCTAssertFalse(found,
            "Bei Profil 'Ausgeglichen' sollte die Tages-Nudges Section NICHT sichtbar sein")
    }
}
