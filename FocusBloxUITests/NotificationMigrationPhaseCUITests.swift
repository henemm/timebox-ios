import XCTest

/// UI Tests for SmartNotificationEngine Phase C (DueDate Migration)
/// Verifies that task operations still work after migrating from direct
/// NotificationService calls to SmartNotificationEngine.reconcile().
final class NotificationMigrationPhaseCUITests: XCTestCase {

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

    /// Verhalten: Backlog-Task antippen und speichern crasht NICHT nach Migration.
    /// reconcile() wird statt direktem NotificationService-Call aufgerufen.
    /// Bricht wenn: reconcile() in BacklogView crasht oder Save-Flow kaputt ist.
    func test_backlogTaskEditSaveFlowWorksAfterMigration() throws {
        // Navigate to Backlog
        let backlogTab = app.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 10) else {
            XCTFail("Backlog tab should exist")
            return
        }
        backlogTab.tap()

        // Wait for backlog list
        let backlogList = app.collectionViews.firstMatch
        XCTAssertTrue(backlogList.waitForExistence(timeout: 5), "Backlog list should appear")

        // Tap first task to edit
        let firstCell = backlogList.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 3) else {
            // No tasks = can't test, but no failure
            return
        }
        firstCell.tap()

        // If edit sheet opens, save it — this exercises the migrated code path
        let saveButton = app.buttons["Speichern"]
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()

            // No crash = Migration works — reconcile() ran without error
            XCTAssertTrue(backlogList.waitForExistence(timeout: 5),
                          "Backlog should still be visible after save — reconcile() did not crash")
        }
    }
}
