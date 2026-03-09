import XCTest

/// UI Tests for Sheet Dismiss Bug
///
/// Bug: Sheets don't dismiss after tapping "Speichern" on iOS.
/// Affects at least Create and Edit sheets.
///
/// TDD RED: These tests verify that sheets CLOSE after saving.
/// They should FAIL if the dismiss bug exists.
final class SheetDismissUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        addUIInterruptionMonitor(withDescription: "System Permission") { alert in
            for label in ["Erlauben", "Allow", "Allow Full Access", "OK",
                          "Beim Verwenden der App erlauben"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launchArguments = ["-UITesting"]
        app.launch()
        app.tap() // Activate interruption monitor
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        // Wait for content to load
        let loading = app.activityIndicators["loadingIndicator"]
        if loading.exists {
            XCTAssertTrue(loading.waitForNonExistence(timeout: 10))
        }
    }

    private func openCreateTaskSheet() {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button must exist")
        addButton.tap()
        // Wait for sheet animation
        let sheetNav = app.navigationBars["Neuer Task"]
        XCTAssertTrue(sheetNav.waitForExistence(timeout: 3), "Create sheet must appear")
    }

    // MARK: - Create Task Sheet Dismiss

    /// Bricht wenn: dismiss() in TaskFormSheet.saveTask() (Zeile 450) nicht das Sheet schliesst.
    /// Create mode uses async Task { await MainActor.run { dismiss() } } — different from edit mode.
    func testCreateTaskSheet_dismissesAfterSave() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Find the title field — try placeholder first, then identifier, then any
        let titleField = app.textFields["Task-Titel"]
        let titleFieldAlt = app.textFields["taskTitle"]
        let titleFieldAny = app.textFields.firstMatch

        let field: XCUIElement
        if titleField.waitForExistence(timeout: 3) {
            field = titleField
        } else if titleFieldAlt.waitForExistence(timeout: 2) {
            field = titleFieldAlt
        } else {
            XCTAssertTrue(titleFieldAny.waitForExistence(timeout: 2), "Title field must exist")
            field = titleFieldAny
        }
        field.tap()
        field.typeText("Test Task Dismiss")

        // Tap "Speichern"
        let saveButton = app.navigationBars.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button must exist")
        XCTAssertTrue(saveButton.isEnabled, "Save button must be enabled after entering title")
        saveButton.tap()

        // CRITICAL: Sheet nav bar must DISAPPEAR after save
        // Uses waitForNonExistence (Xcode 26.2) — no sleep() needed
        let sheetNavBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(sheetNavBar.waitForNonExistence(timeout: 5),
                      "BUG: Create Task sheet is still visible after tapping Speichern. Sheet must dismiss after save.")
    }

    /// Control test: Cancel button should always dismiss the sheet (synchronous dismiss)
    func testCreateTaskSheet_dismissesAfterCancel() throws {
        navigateToBacklog()
        openCreateTaskSheet()

        // Tap "Abbrechen"
        let cancelButton = app.navigationBars.buttons["Abbrechen"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Cancel button must exist")
        cancelButton.tap()

        // Sheet must disappear
        let sheetNavBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(sheetNavBar.waitForNonExistence(timeout: 3),
                      "Create Task sheet should dismiss after tapping Abbrechen")
    }

    // MARK: - Edit Task Sheet Dismiss

    /// Bricht wenn: dismiss() in TaskFormSheet.saveTask() (Zeile 477) nicht das Sheet schliesst.
    /// Edit mode uses synchronous onSave?() then dismiss().
    func testEditTaskSheet_dismissesAfterSave() throws {
        navigateToBacklog()

        // Find "Backlog Task 1" from mock data
        let taskCell = app.staticTexts["Backlog Task 1"]
        XCTAssertTrue(taskCell.waitForExistence(timeout: 5),
                      "Mock task 'Backlog Task 1' must exist in backlog")

        // Swipe left to reveal edit action
        taskCell.swipeLeft()

        // Tap "Bearbeiten"
        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit swipe action must exist")
        editButton.tap()

        // Verify edit sheet is open
        let editSheetNav = app.navigationBars["Task bearbeiten"]
        XCTAssertTrue(editSheetNav.waitForExistence(timeout: 3),
                      "Edit Task sheet must be open")

        // Tap "Speichern" (no changes needed)
        let saveButton = app.navigationBars.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button must exist")
        saveButton.tap()

        // Sheet must disappear
        XCTAssertTrue(editSheetNav.waitForNonExistence(timeout: 5),
                      "BUG: Edit Task sheet is still visible after tapping Speichern. Sheet must dismiss after save.")
    }

    // MARK: - EditFocusBlockSheet Dismiss (via Blox tab)

    /// Bricht wenn: dismiss() in EditFocusBlockSheet (Zeile 63) nicht das Sheet schliesst
    func testEditFocusBlockSheet_dismissesAfterSave() throws {
        // Navigate to Blox tab
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab must exist")
        bloxTab.tap()

        // Wait for loading
        let loading = app.activityIndicators["loadingIndicator"]
        if loading.exists {
            XCTAssertTrue(loading.waitForNonExistence(timeout: 10))
        }

        // Find a FocusBlock edit button
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        guard editButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No FocusBlock edit buttons found — EventKit mock may not provide blocks")
        }

        editButton.tap()

        // Verify edit sheet is open
        let editSheetNav = app.navigationBars["Block bearbeiten"]
        XCTAssertTrue(editSheetNav.waitForExistence(timeout: 3),
                      "Edit FocusBlock sheet must be open")

        // Tap "Speichern"
        let saveButton = app.navigationBars.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button must exist")
        saveButton.tap()

        // Sheet must disappear
        XCTAssertTrue(editSheetNav.waitForNonExistence(timeout: 5),
                      "BUG: Edit FocusBlock sheet is still visible after tapping Speichern. Sheet must dismiss after save.")
    }

    // MARK: - CreateFocusBlockSheet Dismiss (via free slot tap)

    /// Bricht wenn: dismiss() in CreateFocusBlockSheet (Zeile 126) nicht das Sheet schliesst
    func testCreateFocusBlockSheet_dismissesAfterCreate() throws {
        // Navigate to Blox tab
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab must exist")
        bloxTab.tap()

        // Wait for loading
        let loading = app.activityIndicators["loadingIndicator"]
        if loading.exists {
            XCTAssertTrue(loading.waitForNonExistence(timeout: 10))
        }

        // Find a free slot
        let freeSlot = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch

        guard freeSlot.waitForExistence(timeout: 5) else {
            throw XCTSkip("No free time slots found — calendar may be fully booked in mock")
        }

        freeSlot.tap()

        // Verify create sheet is open
        let createButton = app.buttons["Erstellen"]
        guard createButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Create FocusBlock sheet did not open")
        }

        // Tap "Erstellen"
        createButton.tap()

        // Sheet must disappear — check nav bar
        let navBar = app.navigationBars["FocusBlox erstellen"]
        if navBar.exists {
            XCTAssertTrue(navBar.waitForNonExistence(timeout: 5),
                          "BUG: Create FocusBlock sheet is still visible after tapping Erstellen.")
        }
        // Also verify "Erstellen" button is gone
        XCTAssertTrue(createButton.waitForNonExistence(timeout: 3),
                      "BUG: Create FocusBlock sheet is still visible after tapping Erstellen.")
    }
}
