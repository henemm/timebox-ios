import XCTest

/// Tests for Coach View Task Interactions (Bug #248)
/// Verifies that tasks in Coach View support the same interactions as in BacklogView:
/// - Checkbox completion (tap to complete, undo)
/// - Context menu actions (edit, delete)
final class CoachTaskInteractionsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "--coach-tab-layout", "--open-drawer", "daytime"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to Coach tab (daytime drawer auto-opens via launch argument)
    private func navigateToCoach() {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        tabBar.buttons["Coach"].tap()

        // Wait for Coach view to appear and data to load
        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 8), "Coach view should exist")
    }

    /// Find the first complete button visible in the Coach view
    private func findFirstCompleteButton() -> XCUIElement? {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        let buttons = app.buttons.matching(predicate)
        let first = buttons.element(boundBy: 0)
        return first.waitForExistence(timeout: 8) ? first : nil
    }

    /// Find the first task title visible in the Coach view
    private func findFirstTaskTitle() -> XCUIElement? {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        let texts = app.staticTexts.matching(predicate)
        let first = texts.element(boundBy: 0)
        return first.waitForExistence(timeout: 8) ? first : nil
    }

    // MARK: - Checkbox Completion Tests

    /// GIVEN: Tasks are shown in Coach View with Daytime drawer open
    /// WHEN: User taps the checkbox of a task
    /// THEN: Task shows completion pending state (filled checkbox, label changes)
    func testCheckboxCompletionInCoachView() throws {
        navigateToCoach()

        guard let completeButton = findFirstCompleteButton() else {
            XCTFail("No complete button found in Coach View — tasks should be visible and interactive")
            return
        }

        // Verify initial state
        XCTAssertEqual(
            completeButton.label, "Als erledigt markieren",
            "Task should initially show 'Als erledigt markieren'"
        )

        // Tap checkbox — the core bug: onComplete was nil, so nothing happened
        completeButton.tap()

        // After fix: should change to completion pending state
        let completedPredicate = NSPredicate(format: "label == 'Erledigt'")
        let expectation = XCTNSPredicateExpectation(predicate: completedPredicate, object: completeButton)
        let result = XCTWaiter.wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "Task should show 'Erledigt' after checkbox tap in Coach View")
    }

    /// GIVEN: A task was just completed in Coach View (pending state)
    /// WHEN: User taps the checkbox again within 3 seconds
    /// THEN: Completion is cancelled (undo)
    func testCheckboxUndoInCoachView() throws {
        navigateToCoach()

        guard let completeButton = findFirstCompleteButton() else {
            XCTFail("No complete button found in Coach View")
            return
        }

        // Complete the task
        completeButton.tap()

        // Wait for pending state
        let completedPredicate = NSPredicate(format: "label == 'Erledigt'")
        let pendingExpectation = XCTNSPredicateExpectation(predicate: completedPredicate, object: completeButton)
        let isPending = XCTWaiter.wait(for: [pendingExpectation], timeout: 3)
        guard isPending == .completed else {
            XCTFail("Task should enter pending state after first tap")
            return
        }

        // Tap again to undo
        completeButton.tap()

        // Should revert to uncompleted
        let undoPredicate = NSPredicate(format: "label == 'Als erledigt markieren'")
        let undoExpectation = XCTNSPredicateExpectation(predicate: undoPredicate, object: completeButton)
        let isUndone = XCTWaiter.wait(for: [undoExpectation], timeout: 3)
        XCTAssertEqual(isUndone, .completed, "Task should revert after undo tap")
    }

    // MARK: - Context Menu Tests

    /// GIVEN: Tasks are shown in Coach View
    /// WHEN: User long-presses a task row
    /// THEN: Context menu with "Bearbeiten" and "Löschen" appears
    func testContextMenuOnCoachTask() throws {
        navigateToCoach()

        guard let taskTitle = findFirstTaskTitle() else {
            XCTFail("No task title found in Coach View — tasks should be visible")
            return
        }

        // Long press to open context menu
        taskTitle.press(forDuration: 1.2)

        // Context menu should have Edit and Delete options
        let editMenuItem = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Bearbeiten'")
        ).firstMatch
        let deleteMenuItem = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Löschen'")
        ).firstMatch

        XCTAssertTrue(
            editMenuItem.waitForExistence(timeout: 3),
            "Context menu should have 'Bearbeiten' option"
        )
        XCTAssertTrue(
            deleteMenuItem.exists,
            "Context menu should have 'Löschen' option"
        )
    }
}
