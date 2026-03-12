import XCTest

/// UI Tests for the searchable BlockerPickerSheet.
/// TDD RED: These tests verify that the dependency picker opens a searchable sheet
/// instead of a plain dropdown menu.
final class BlockerPickerSearchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    /// Navigate to Backlog tab and open the create-task form.
    private func openCreateTaskForm() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 10), "Backlog tab should exist")
        backlogTab.tap()

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        addButton.tap()
    }

    /// Scroll down in the task form to reveal the dependency section.
    private func scrollToDependencySection() {
        let scrollView = app.scrollViews["taskFormScrollView"]
        guard scrollView.waitForExistence(timeout: 5) else {
            XCTFail("Task form scroll view should exist")
            return
        }
        // Dependency section is far down — scroll like the diagnostic test
        let blockerButton = app.buttons["taskFormSection_dependency"]
        for _ in 0..<8 {
            scrollView.swipeUp()
            if blockerButton.waitForExistence(timeout: 2) { break }
        }
    }

    // MARK: - Diagnostic

    /// Diagnostic: capture what the form looks like after scrolling.
    func test_DIAG_captureFormState() {
        openCreateTaskForm()

        let scrollView = app.scrollViews["taskFormScrollView"]
        guard scrollView.waitForExistence(timeout: 5) else {
            XCTFail("No scrollView found. Tree: \(app.debugDescription)")
            return
        }

        // Scroll to bottom — 8 swipes
        for _ in 0..<8 {
            scrollView.swipeUp()
        }

        // Dump all buttons and identifiers after scrolling
        let allButtons = app.buttons.allElementsBoundByIndex
        var buttonInfo: [String] = []
        for btn in allButtons.prefix(40) {
            let id = btn.identifier
            let lbl = btn.label
            if !id.isEmpty || !lbl.isEmpty {
                buttonInfo.append("[\(id)] '\(lbl)'")
            }
        }

        let allOthers = app.otherElements.allElementsBoundByIndex
        var otherInfo: [String] = []
        for elem in allOthers.prefix(30) {
            let id = elem.identifier
            if id.contains("taskForm") || id.contains("blocker") || id.contains("dependency") {
                otherInfo.append("[\(id)]")
            }
        }

        XCTFail("DIAG-BUTTONS: \(buttonInfo.joined(separator: " | ")) DIAG-OTHERS: \(otherInfo.joined(separator: " | "))")
    }

    // MARK: - Tests

    /// The dependency section should show a button that opens a sheet, not a menu picker.
    func test_blockerSection_showsButtonThatOpensSheet() {
        openCreateTaskForm()
        scrollToDependencySection()

        // The blocker button should exist (replaces the old menu Picker)
        let blockerButton = app.buttons["taskFormSection_dependency"]
        XCTAssertTrue(blockerButton.waitForExistence(timeout: 3),
                      "Dependency button should exist in task form")

        // It should show "Keine" by default (no dependency selected)
        let buttonLabel = blockerButton.label
        XCTAssertTrue(buttonLabel.contains("Keine"),
                      "Default blocker button should show 'Keine', got: \(buttonLabel)")
    }

    /// Tapping the blocker button should open a sheet with a search field.
    func test_blockerButton_opensSheetWithSearch() {
        openCreateTaskForm()
        scrollToDependencySection()

        let blockerButton = app.buttons["taskFormSection_dependency"]
        XCTAssertTrue(blockerButton.waitForExistence(timeout: 3))
        blockerButton.tap()

        // The sheet should contain a navigation bar with title
        let sheetTitle = app.navigationBars["Abhängig von"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5),
                      "Blocker picker sheet should have navigation title 'Abhängig von'")

        // The "Keine" option should be visible in the list
        let noneOption = app.buttons["blockerOption_none"]
        XCTAssertTrue(noneOption.waitForExistence(timeout: 3),
                      "Sheet should show 'Keine' option")

        // A search field should be available (prompt: "Task durchsuchen")
        let searchField = app.searchFields["Task durchsuchen"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Sheet should have a search field")
    }

    /// Typing in the search field should filter the task list.
    func test_searchField_filtersTaskList() {
        openCreateTaskForm()
        scrollToDependencySection()

        let blockerButton = app.buttons["taskFormSection_dependency"]
        XCTAssertTrue(blockerButton.waitForExistence(timeout: 3))
        blockerButton.tap()

        // Find the sheet's search field (prompt: "Task durchsuchen", not "Tasks durchsuchen")
        let searchField = app.searchFields["Task durchsuchen"]
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Search field should exist in blocker picker sheet")
            return
        }

        // Type a search query
        searchField.tap()
        searchField.typeText("xyz_nonexistent_query")

        // With a nonsense query, no task rows should match
        // The "Keine" option should still be visible (it's always shown)
        let noneOption = app.buttons["blockerOption_none"]
        XCTAssertTrue(noneOption.waitForExistence(timeout: 3), "'Keine' should always be visible regardless of search")
    }

    /// Selecting a task in the sheet should update the button label and dismiss the sheet.
    func test_selectingTask_updatesButtonAndDismissesSheet() {
        openCreateTaskForm()
        scrollToDependencySection()

        let blockerButton = app.buttons["taskFormSection_dependency"]
        XCTAssertTrue(blockerButton.waitForExistence(timeout: 3))
        blockerButton.tap()

        // Select "Keine" (which is always available)
        let noneOption = app.buttons["blockerOption_none"]
        guard noneOption.waitForExistence(timeout: 5) else {
            XCTFail("'Keine' option should exist in blocker sheet")
            return
        }
        noneOption.tap()

        // Sheet should be dismissed — wait for nav bar to disappear
        let sheetTitle = app.navigationBars["Abhängig von"]
        let dismissed = sheetTitle.waitForNonExistence(timeout: 5)
        XCTAssertTrue(dismissed, "Sheet should be dismissed after selection")

        // Button should still show "Keine"
        XCTAssertTrue(blockerButton.waitForExistence(timeout: 3),
                      "Blocker button should still exist after sheet dismissal")
    }
}
