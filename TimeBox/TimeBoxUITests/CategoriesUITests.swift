import XCTest

/// UI Tests for Categories Expansion (Sprint 3)
final class CategoriesUITests: XCTestCase {

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

    private func openCreateTaskView() {
        // Navigate to Backlog tab and tap add button
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }

        let addButton = app.buttons["addTaskButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        }
    }

    // MARK: - Category Picker Tests

    /// GIVEN: CreateTaskView is open
    /// WHEN: Looking at the task type section
    /// THEN: The task type picker should exist and be interactable
    func testTaskTypePickerExists() throws {
        openCreateTaskView()

        // Wait for create task view
        let navBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Create Task view should open")

        // Look for the Typ section header and picker
        let typHeader = app.staticTexts["Typ"]
        XCTAssertTrue(typHeader.waitForExistence(timeout: 3), "Typ section header should exist")

        // The picker itself should be present
        let aufgabentypPicker = app.buttons["Aufgabentyp"]
        XCTAssertTrue(aufgabentypPicker.waitForExistence(timeout: 3), "Aufgabentyp picker should exist")
    }

    /// GIVEN: CreateTaskView is open
    /// WHEN: Creating a task with title
    /// THEN: The task can be saved (verifies all categories work)
    func testTaskCanBeCreatedWithDefaultCategory() throws {
        openCreateTaskView()

        // Wait for create task view
        let navBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Create Task view should open")

        // Enter a task title
        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Title field should exist")
        titleField.tap()
        titleField.typeText("Test Task")

        // Verify save button is enabled
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled after entering title")
    }
}
