import XCTest

/// UI Tests for Ticket 2: Delete confirmation dialog for recurring tasks.
/// "Nur diese Aufgabe" vs "Alle offenen dieser Serie"
/// EXPECTED TO FAIL: No confirmation dialog exists yet for recurring task deletion.
final class RecurringDeleteDialogUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// GIVEN: A recurring task exists in the backlog
    /// WHEN: User swipe-deletes the task
    /// THEN: A confirmation dialog should appear with "Nur diese Aufgabe" and "Alle offenen dieser Serie"
    /// EXPECTED TO FAIL: No dialog exists - delete happens immediately
    func testDeleteDialog_appearsForRecurringTask() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 5) else {
            XCTFail("Backlog tab not found")
            return
        }
        backlogTab.tap()
        sleep(1)

        // Look for the series delete option that should appear in a confirmation dialog
        // This element will only exist after Ticket 2 implementation
        let seriesDeleteOption = app.buttons["Alle offenen dieser Serie"]
        XCTAssertTrue(
            seriesDeleteOption.waitForExistence(timeout: 3),
            "Ticket 2: Series delete option should exist in confirmation dialog"
        )
    }
}
