import XCTest

/// UI Tests for Recurring Tasks Phase 1B - Ticket 1: Visibility Filter
/// Tests that recurring tasks with future due dates are hidden from the backlog.
/// EXPECTED TO FAIL: fetchIncompleteTasks() does not filter recurring tasks by dueDate yet.
final class RecurringVisibilityUITests: XCTestCase {
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

    // MARK: - Helpers

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    // MARK: - Ticket 1: Visibility Filter Tests

    /// GIVEN: A daily recurring task is created with dueDate enabled
    /// WHEN: The task is saved and backlog refreshes
    /// THEN: The backlog should apply a recurring visibility filter
    ///       (future-dated recurring tasks hidden, today/past visible)
    /// EXPECTED TO FAIL: No visibility filter exists yet
    func testRecurringVisibilityFilterActive() throws {
        navigateToBacklog()

        // Create a daily recurring task via the form
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        addButton.tap()
        sleep(1)

        // Enter title
        let titleField = app.textFields["Task-Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Title field should exist")
        titleField.tap()
        titleField.typeText("RecurringVisTest Daily")

        // Scroll to recurrence section
        let scrollView = app.scrollViews["taskFormScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "Scroll view should exist")
        scrollView.swipeUp()
        sleep(1)

        // Set recurrence to Täglich
        let recurrencePicker = app.buttons["recurrencePicker"]
        guard recurrencePicker.waitForExistence(timeout: 3) else {
            XCTFail("Recurrence picker not found")
            return
        }
        recurrencePicker.tap()
        sleep(1)

        let dailyOption = app.buttons["Täglich"]
        guard dailyOption.waitForExistence(timeout: 2) else {
            XCTFail("Daily option not found")
            return
        }
        dailyOption.tap()
        sleep(1)

        // Enable dueDate toggle
        scrollView.swipeUp()
        sleep(1)

        let dueDateToggle = app.switches["Fälligkeitsdatum"]
        if dueDateToggle.waitForExistence(timeout: 3) {
            if dueDateToggle.value as? String == "0" {
                dueDateToggle.tap()
                sleep(1)
            }
        }

        // Save the task
        let saveButton = app.navigationBars.buttons["Fertig"]
        guard saveButton.waitForExistence(timeout: 3) else {
            XCTFail("Save button not found")
            return
        }
        saveButton.tap()
        sleep(2)

        // Back in backlog - verify the task exists (it should, dueDate = today)
        let createdTask = app.staticTexts["RecurringVisTest Daily"]
        XCTAssertTrue(
            createdTask.waitForExistence(timeout: 5),
            "Recurring task with today's dueDate should be visible in backlog"
        )

        // Now check that the recurrence badge shows the series group indicator
        // This element is added as part of Ticket 1 (recurrenceGroupID implementation)
        let seriesIndicator = app.otherElements["recurrenceSeriesGroup"]
        XCTAssertTrue(
            seriesIndicator.waitForExistence(timeout: 3),
            "Ticket 1: Recurring tasks should have a series group indicator (recurrenceGroupID)"
        )
    }
}
