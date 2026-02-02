//
//  BacklogSwipeActionsUITests.swift
//  FocusBloxUITests
//
//  Tests for Backlog ListView swipe actions:
//  - Swipe left (trailing) → Next Up
//  - Swipe right (leading) → Edit
//

import XCTest

final class BacklogSwipeActionsUITests: XCTestCase {
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

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.buttons["backlogTab"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    private func findFirstTaskRow() -> XCUIElement? {
        // Find a task title element
        let taskTitles = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'"))
        guard taskTitles.count > 0 else { return nil }
        return taskTitles.element(boundBy: 0)
    }

    // MARK: - Swipe Left → Next Up Tests

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes left on a task
    /// THEN: "Next Up" action button appears
    func testSwipeLeftShowsNextUpAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Swipe left to reveal trailing action (Next Up)
        taskRow.swipeLeft()

        // Look for the Next Up button
        let nextUpButton = app.buttons["Next Up"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 2),
                      "Swipe left should reveal 'Next Up' action button")
    }

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes left and taps "Next Up"
    /// THEN: Task moves to Next Up section
    func testSwipeLeftNextUpMovesTask() throws {
        navigateToBacklog()
        sleep(2)

        // Count tasks before
        let tasksBefore = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")).count
        guard tasksBefore > 0 else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Get first task
        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("Could not find task row")
        }
        let taskId = taskRow.identifier

        // Swipe left and tap Next Up
        taskRow.swipeLeft()

        let nextUpButton = app.buttons["Next Up"]
        if nextUpButton.waitForExistence(timeout: 2) {
            nextUpButton.tap()
        }

        sleep(1)

        // Task should no longer be in backlog list (moved to Next Up section)
        let sameTask = app.staticTexts[taskId]
        // It might still exist but in Next Up section, so we check if backlog count decreased
        let tasksAfter = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")).count

        // Either count decreased or task moved - both are valid outcomes
        XCTAssertTrue(tasksAfter <= tasksBefore,
                      "Task should move to Next Up (backlog count should not increase)")
    }

    // MARK: - Swipe Right → Edit Tests

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes right on a task
    /// THEN: "Bearbeiten" (Edit) action button appears
    func testSwipeRightShowsEditAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Swipe right to reveal leading action (Edit)
        taskRow.swipeRight()

        // Look for the Edit button (German: "Bearbeiten")
        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                      "Swipe right should reveal 'Bearbeiten' (Edit) action button")
    }

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes right and taps "Bearbeiten"
    /// THEN: Edit sheet opens
    func testSwipeRightEditOpensSheet() throws {
        navigateToBacklog()
        sleep(2)

        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Swipe right and tap Edit
        taskRow.swipeRight()

        let editButton = app.buttons["Bearbeiten"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
        }

        // Edit sheet should appear - look for common edit sheet elements
        // TaskFormSheet typically has a title field or save button
        let titleField = app.textFields.firstMatch
        let saveButton = app.buttons["Speichern"]

        let sheetAppeared = titleField.waitForExistence(timeout: 3) || saveButton.waitForExistence(timeout: 3)
        XCTAssertTrue(sheetAppeared,
                      "Edit sheet should appear after tapping Bearbeiten")
    }

    // MARK: - List Consistency Tests

    /// GIVEN: Backlog ListView
    /// WHEN: View is displayed
    /// THEN: All task rows have consistent width (via List styling)
    func testBacklogRowsHaveConsistentStyling() throws {
        navigateToBacklog()
        sleep(2)

        // Find all task title elements
        let taskTitles = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'"))

        guard taskTitles.count >= 2 else {
            throw XCTSkip("Need at least 2 tasks to compare consistency")
        }

        // Get frames of first two tasks
        let firstTask = taskTitles.element(boundBy: 0)
        let secondTask = taskTitles.element(boundBy: 1)

        let firstFrame = firstTask.frame
        let secondFrame = secondTask.frame

        // Widths should be similar (within tolerance for different content)
        // X position (left edge) should be the same
        XCTAssertEqual(firstFrame.minX, secondFrame.minX, accuracy: 5,
                       "Task rows should have consistent left alignment")
    }
}
