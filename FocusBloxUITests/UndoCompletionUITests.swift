import XCTest

final class UndoCompletionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Verhalten: Task kann per Checkbox abgehakt werden und verschwindet aus dem Backlog.
    /// Undo-Logik ist durch 8 Unit Tests abgedeckt. Shake-Geste ist in UI Tests nicht simulierbar.
    /// Bricht wenn: Checkbox-Button fehlt oder Completion nicht funktioniert
    func testCheckboxCompleteRemovesTask() throws {
        // Backlog tab is already selected on launch
        let addButton = app.buttons["addTaskButton"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Backlog should be loaded (addTaskButton missing)")
            return
        }

        // Find the first complete checkbox button (at app level, not inside cell)
        let completeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        guard completeButton.waitForExistence(timeout: 5) else {
            XCTFail("Complete checkbox button should exist in backlog")
            return
        }

        // Extract the task ID from the button identifier to verify the right task disappears
        let buttonID = completeButton.identifier
        completeButton.tap()

        // The same complete button should no longer exist (task removed from list)
        let sameButton = app.buttons[buttonID]
        let stillVisible = sameButton.waitForExistence(timeout: 3)
        XCTAssertFalse(stillVisible, "Completed task's checkbox should no longer appear in backlog")
    }
}
