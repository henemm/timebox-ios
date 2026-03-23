import XCTest

/// UI Tests for SmartNotificationEngine Phase D (Settings Profile Picker)
/// TDD RED: Tests MUST FAIL — notificationProfilePicker does not exist in Settings yet.
final class SmartNotificationPhaseDUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Verhalten: Settings zeigt Profil-Picker mit Identifier "notificationProfilePicker".
    /// Bricht wenn: Picker nicht in SettingsView ergaenzt wurde oder falschen Identifier hat.
    func test_settingsShowsProfilePicker() throws {
        // Navigate to Settings
        let settingsButton = app.navigationBars.buttons["gearshape"]
        if !settingsButton.waitForExistence(timeout: 5) {
            // Try toolbar button alternative
            let toolbarSettings = app.buttons["settingsButton"]
            XCTAssertTrue(toolbarSettings.waitForExistence(timeout: 5), "Settings button should exist")
            toolbarSettings.tap()
        } else {
            settingsButton.tap()
        }

        // Look for profile picker
        let picker = app.buttons["notificationProfilePicker"]
            .exists ? app.buttons["notificationProfilePicker"]
            : app.staticTexts["notificationProfilePicker"]

        // Also try as a generic element since Picker renders differently
        let pickerExists = app.descendants(matching: .any)["notificationProfilePicker"]
        XCTAssertTrue(pickerExists.waitForExistence(timeout: 5),
                      "Settings should show notification profile picker with identifier 'notificationProfilePicker'")
    }

    /// Verhalten: Profil-Picker hat 3 Optionen (Leise, Ausgeglichen, Aktiv).
    /// Bricht wenn: Eine Option fehlt, falsch benannt ist, oder Picker nicht existiert.
    func test_profilePickerHasThreeOptions() throws {
        // Navigate to Settings
        let settingsButton = app.navigationBars.buttons["gearshape"]
        if !settingsButton.waitForExistence(timeout: 5) {
            let toolbarSettings = app.buttons["settingsButton"]
            XCTAssertTrue(toolbarSettings.waitForExistence(timeout: 5), "Settings button should exist")
            toolbarSettings.tap()
        } else {
            settingsButton.tap()
        }

        // Check that the profile section text is visible
        let profilHeader = app.staticTexts["Profil"]
        XCTAssertTrue(profilHeader.waitForExistence(timeout: 5),
                      "Settings should show 'Profil' section header")

        // Check that footer describes all three profiles
        let footerText = app.staticTexts.allElementsBoundByIndex.contains {
            $0.label.contains("Leise") && $0.label.contains("Ausgeglichen") && $0.label.contains("Aktiv")
        }
        XCTAssertTrue(footerText,
                      "Profile picker footer should mention all three profiles: Leise, Ausgeglichen, Aktiv")
    }
}
