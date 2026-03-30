import XCTest

/// UI Tests für FEATURE_031: iOS App Icon Quick Actions
/// Testet das SprintPickerSheet, das via Quick Action "Sprint starten" geöffnet wird.
final class QuickActionUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Launches app with sprint picker sheet open (simulates Quick Action)
    private func launchWithSprintPicker(emptyData: Bool = false) {
        app.launchArguments = ["-UITesting", "--show-sprint-picker"]
        if emptyData {
            app.launchArguments.append("--empty-morning")
        }
        app.launch()
    }

    // MARK: - Sprint Picker Sheet

    /// Verhalten: Sprint-Picker Sheet öffnet via Launch-Argument (simuliert Quick Action URL)
    /// Bricht wenn: FocusBloxApp.swift — --show-sprint-picker Handling oder showSprintPicker nicht gesetzt
    func test_sprintPickerSheet_showsNextUpTasks() throws {
        launchWithSprintPicker()

        let sheet = app.otherElements["sprintPickerSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "SprintPickerSheet muss existieren")
    }

    /// Verhalten: Sprint-Picker Sheet zeigt mindestens einen Next-Up Task als Row
    /// Bricht wenn: SprintPickerSheet.swift — Query filtert nicht nach isNextUp oder Row-Identifier fehlt
    func test_sprintPickerSheet_displaysTaskRows() throws {
        launchWithSprintPicker()

        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'sprintPickerRow_'")
        ).firstMatch

        XCTAssertTrue(row.waitForExistence(timeout: 5), "Mindestens eine Task-Row muss im SprintPicker sichtbar sein")
    }

    /// Verhalten: Sprint-Picker zeigt Empty State wenn keine Next-Up Tasks vorhanden
    /// Bricht wenn: SprintPickerSheet.swift — Empty-State-View entfernt oder falsche Bedingung
    func test_sprintPickerSheet_showsEmptyState_whenNoNextUpTasks() throws {
        launchWithSprintPicker(emptyData: true)

        let emptyState = app.staticTexts["sprintPickerEmpty"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Empty State muss angezeigt werden wenn keine Next-Up Tasks")
    }
}
