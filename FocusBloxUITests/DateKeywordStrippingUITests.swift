import XCTest

/// UI Tests for BUG_124: Date keywords ("Heute", "Morgen") must be stripped
/// from task titles when creating tasks.
final class DateKeywordStrippingUITests: XCTestCase {

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

    /// Verhalten: Task via + Button erstellen — "Heute" wird aus dem Titel entfernt
    /// Bricht wenn: stripKeywords() keine Datums-Keywords entfernt
    func testTaskForm_heuteKeyword_strippedFromTitle() throws {
        // 1. Open Task Form
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // 2. Enter title with date keyword
        let titleField = app.textFields["taskFormSection_title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Heute Klingel demontieren")

        // 3. Save
        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // 4. Wait for sheet to dismiss
        XCTAssertTrue(addButton.waitForExistence(timeout: 10),
                      "Should return to backlog after save")

        // 5. Task creation is async — use generous wait with intermediate scroll triggers
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Klingel'")
        let taskElement = app.staticTexts.matching(predicate).firstMatch

        // First attempt: direct wait
        if !taskElement.waitForExistence(timeout: 5) {
            // Scroll to trigger list refresh
            let list = app.collectionViews["backlogTaskList"]
            if list.exists {
                list.swipeDown()
            }
        }

        // Second attempt: longer wait after scroll
        XCTAssertTrue(taskElement.waitForExistence(timeout: 15),
                      "Task containing 'Klingel' should appear in backlog after save")

        // 6. Verify: Title must NOT contain "Heute"
        let allTaskTitles = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        )
        for i in 0..<allTaskTitles.count {
            let title = allTaskTitles.element(boundBy: i)
            if title.exists && title.label.localizedCaseInsensitiveContains("Klingel") {
                XCTAssertFalse(
                    title.label.localizedCaseInsensitiveContains("Heute"),
                    "BUG_124: Task title '\(title.label)' contains 'Heute' — must be stripped"
                )
            }
        }
    }
}
