import XCTest

/// UI Tests for EditTaskSheet - Full Editability for all Tasks
///
/// Tests verify that EditTaskSheet shows ALL editable fields,
/// regardless of whether the task is native or imported from Reminders.
///
/// TDD RED: These tests WILL FAIL because the fields don't exist yet.
final class EditTaskSheetUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Helper: Open edit sheet for first task in backlog
    private func openEditSheet() {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()

        // Wait for tasks to load
        sleep(2)

        // Find a backlog task by looking for the specific text
        // The backlog tasks have isNextUp = false and appear in the list
        let backlogTask = app.staticTexts["Backlog Task 1"]
        if backlogTask.waitForExistence(timeout: 5) {
            backlogTask.tap()
        } else {
            // Fallback: tap on first cell
            let firstTask = app.cells.firstMatch
            if firstTask.waitForExistence(timeout: 3) {
                firstTask.tap()
            }
        }

        // Wait for detail sheet to appear
        sleep(1)

        // Look for edit button in the detail sheet
        let editButton = app.buttons["Bearbeiten"]
        if editButton.waitForExistence(timeout: 3) {
            editButton.tap()
        }

        // Wait for edit sheet to appear
        sleep(1)
    }

    // MARK: - TDD RED Tests

    /// Test: EditTaskSheet shows Tags input field
    /// EXPECTED TO FAIL: Tags field does not exist yet
    func testEditSheetShowsTagsField() throws {
        openEditSheet()

        // Look for Tags section or input
        let tagsField = app.textFields["Tags"]
        let tagsSection = app.staticTexts["Tags"]

        let hasTagsUI = tagsField.waitForExistence(timeout: 3) || tagsSection.exists

        XCTAssertTrue(hasTagsUI, "EditTaskSheet should show Tags field")
    }

    /// Test: EditTaskSheet shows Urgency picker
    /// EXPECTED TO FAIL: Urgency picker does not exist yet
    func testEditSheetShowsUrgencyPicker() throws {
        openEditSheet()

        // Look for Urgency/Dringlichkeit picker
        let urgencyPicker = app.buttons["Dringlichkeit"]
        let urgencySection = app.staticTexts["Dringlichkeit"]

        let hasUrgencyUI = urgencyPicker.waitForExistence(timeout: 3) || urgencySection.exists

        XCTAssertTrue(hasUrgencyUI, "EditTaskSheet should show Urgency picker")
    }

    /// Test: EditTaskSheet shows TaskType picker
    /// EXPECTED TO FAIL: TaskType picker does not exist yet
    func testEditSheetShowsTaskTypePicker() throws {
        openEditSheet()

        // Look for TaskType/Typ picker
        let typePicker = app.buttons["Typ"]
        let typeSection = app.staticTexts["Typ"]

        let hasTypeUI = typePicker.waitForExistence(timeout: 3) || typeSection.exists

        XCTAssertTrue(hasTypeUI, "EditTaskSheet should show TaskType picker")
    }

    /// Test: EditTaskSheet shows DueDate toggle and picker
    /// EXPECTED TO FAIL: DueDate UI does not exist yet
    func testEditSheetShowsDueDatePicker() throws {
        openEditSheet()

        // Look for DueDate/Fälligkeitsdatum toggle or picker
        let dueDateToggle = app.switches["Fälligkeitsdatum"]
        let dueDateSection = app.staticTexts["Fälligkeitsdatum"]
        let dueDatePicker = app.datePickers.firstMatch

        let hasDueDateUI = dueDateToggle.waitForExistence(timeout: 3) ||
                           dueDateSection.exists ||
                           dueDatePicker.exists

        XCTAssertTrue(hasDueDateUI, "EditTaskSheet should show DueDate picker")
    }

    /// Test: EditTaskSheet shows Description text editor
    /// EXPECTED TO FAIL: Description field does not exist yet
    func testEditSheetShowsDescriptionField() throws {
        openEditSheet()

        // Look for Description/Beschreibung text field or editor
        let descriptionField = app.textViews["Beschreibung"]
        let descriptionSection = app.staticTexts["Beschreibung"]
        let notesField = app.textViews["Notizen"]

        let hasDescriptionUI = descriptionField.waitForExistence(timeout: 3) ||
                               descriptionSection.exists ||
                               notesField.exists

        XCTAssertTrue(hasDescriptionUI, "EditTaskSheet should show Description field")
    }
}
