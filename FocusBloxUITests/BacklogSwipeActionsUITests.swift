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

    /// Find a backlog task (not Next Up) by looking for mock backlog task titles.
    /// Scrolls down if needed since backlog tasks appear below the Next Up section.
    private func findBacklogTaskRow() -> XCUIElement? {
        // Try without scrolling first
        let backlogTitles = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Backlog' OR label CONTAINS 'TBD'")
        )
        if backlogTitles.count > 0, backlogTitles.element(boundBy: 0).isHittable {
            return backlogTitles.element(boundBy: 0)
        }

        // Scroll down to reveal backlog tasks below Next Up section
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        for _ in 0..<3 {
            list.swipeUp()
            sleep(1)
            let found = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Backlog' OR label CONTAINS 'TBD'")
            )
            if found.count > 0, found.element(boundBy: 0).isHittable {
                return found.element(boundBy: 0)
            }
        }

        return nil
    }

    // MARK: - Swipe Right → Next Up Tests (leading edge)

    /// GIVEN: Backlog with non-Next-Up tasks
    /// WHEN: User swipes right and taps "Next Up"
    /// THEN: The "Next Up" action button appears and is tappable (leading edge)
    func testSwipeRightShowsAndTapsNextUpAction() throws {
        navigateToBacklog()
        sleep(2)

        // Must find a non-Next-Up task
        guard let taskRow = findBacklogTaskRow() else {
            throw XCTSkip("Could not find backlog task row")
        }

        // Swipe right and tap Next Up (leading edge)
        taskRow.swipeRight()

        let nextUpButton = app.buttons["Next Up"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 2),
                      "Next Up button should appear after swipe right")

        // Tapping should not crash
        nextUpButton.tap()
        sleep(1)

        // After tapping, the swipe action row should dismiss (button disappears)
        XCTAssertFalse(nextUpButton.exists,
                       "Next Up button should disappear after tapping")
    }

    // MARK: - Swipe Left → Edit/Delete Tests (trailing edge)

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes left on a task (reveals trailing edge)
    /// THEN: "Bearbeiten" (Edit) action button appears
    func testSwipeLeftShowsEditAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Swipe left to reveal trailing actions (Edit + Delete)
        taskRow.swipeLeft()

        // Look for the Edit button (German: "Bearbeiten")
        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                      "Swipe left should reveal 'Bearbeiten' (Edit) action button (trailing edge)")
    }

    /// GIVEN: Backlog with tasks
    /// WHEN: User swipes left and taps "Bearbeiten"
    /// THEN: Edit sheet opens
    func testSwipeLeftEditOpensSheet() throws {
        navigateToBacklog()
        sleep(2)

        guard let taskRow = findFirstTaskRow() else {
            throw XCTSkip("No tasks available for swipe test")
        }

        // Swipe left and tap Edit (trailing edge)
        taskRow.swipeLeft()

        let editButton = app.buttons["Bearbeiten"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
        }

        // Edit sheet should appear — look for any sheet/navigation content
        let sheetAppeared = app.textFields.firstMatch.waitForExistence(timeout: 3)
            || app.buttons["Speichern"].waitForExistence(timeout: 3)
            || app.navigationBars.firstMatch.waitForExistence(timeout: 3)
            || app.sheets.firstMatch.waitForExistence(timeout: 3)
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
