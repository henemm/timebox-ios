import XCTest

/// UI Tests für FEATURE_031: iOS App Icon Quick Actions
///
/// Zwei Test-Strategien:
/// 1. --quick-action Launch-Argument → testet ob die Actions korrekt reagieren (zuverlässig)
/// 2. Springboard Long Press → testet ob Quick Actions im Menü erscheinen (E2E)
final class QuickActionUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Quick Action via Launch-Argument (zuverlässig + schnell)

    /// Verhalten: "Task notieren" Quick Action öffnet Quick-Capture-Sheet
    /// Bricht wenn: FocusBloxApp.swift — --quick-action create-task Handler fehlt
    func test_quickAction_taskNotieren_opensQuickCapture() throws {
        app.launchArguments = ["-UITesting", "--quick-action", "create-task"]
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Quick-Capture TextField muss nach 'Task notieren' Quick Action erscheinen")
    }

    /// Verhalten: "Sprint starten" Quick Action öffnet Sprint-Picker-Sheet
    /// Bricht wenn: FocusBloxApp.swift — --quick-action sprint-picker Handler fehlt
    func test_quickAction_sprintStarten_opensSprintPicker() throws {
        app.launchArguments = ["-UITesting", "--quick-action", "sprint-picker"]
        app.launch()

        let sheet = app.otherElements["sprintPickerSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5),
                      "SprintPickerSheet muss nach 'Sprint starten' Quick Action erscheinen")
    }

    /// Verhalten: "Heute" Quick Action navigiert zum Tag-Tab
    /// Bricht wenn: FocusBloxApp.swift — --quick-action day-view Handler fehlt
    func test_quickAction_heute_navigatesToDayTab() throws {
        app.launchArguments = ["-UITesting", "--quick-action", "day-view"]
        app.launch()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tab-Bar muss sichtbar sein")
        XCTAssertTrue(tagTab.isSelected, "Tag-Tab muss nach 'Heute' Quick Action ausgewählt sein")
    }

    // MARK: - Springboard E2E (Long Press auf App-Icon)

    /// Verhalten: Long Press auf App-Icon zeigt Quick Actions Menü mit 3 Einträgen
    /// Bricht wenn: Info.plist — UIApplicationShortcutItems fehlen oder falsch konfiguriert
    func test_longPress_showsQuickActionMenu() throws {
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCUIDevice.shared.press(.home)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let appIcon = springboard.icons["FocusBlox"]
        XCTAssertTrue(appIcon.waitForExistence(timeout: 10),
                      "FocusBlox App-Icon muss auf dem Home Screen sichtbar sein")
        appIcon.press(forDuration: 2.0)

        let taskNotieren = springboard.buttons["Task notieren"]
        let sprintStarten = springboard.buttons["Sprint starten"]
        let heute = springboard.buttons["Heute"]

        XCTAssertTrue(taskNotieren.waitForExistence(timeout: 5),
                      "Quick Action 'Task notieren' muss im Menü erscheinen")
        XCTAssertTrue(sprintStarten.exists,
                      "Quick Action 'Sprint starten' muss im Menü erscheinen")
        XCTAssertTrue(heute.exists,
                      "Quick Action 'Heute' muss im Menü erscheinen")
    }
}
