//
//  MatrixContextMenuUITests.swift
//  FocusBloxUITests
//
//  Tests for Bug 49: Context Menu in Eisenhower Matrix View
//  Verifies long-press context menu works on tasks in QuadrantCards
//

import XCTest

final class MatrixContextMenuUITests: XCTestCase {

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

    private func navigateToMatrixView() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(1)

        // Switch to Matrix view mode
        let matrixButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Matrix' OR identifier CONTAINS 'matrix'")
        ).firstMatch
        if matrixButton.waitForExistence(timeout: 3) {
            matrixButton.tap()
        } else {
            let gridButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'square.grid' OR identifier CONTAINS 'grid'")
            ).firstMatch
            if gridButton.exists {
                gridButton.tap()
            }
        }
        sleep(1)
    }

    // MARK: - Context Menu Tests

    /// EXPECTED TO FAIL: Context menu does not exist on QuadrantCard rows yet
    func testLongPressOnMatrixTaskShowsContextMenu() throws {
        navigateToMatrixView()

        // Find any task row in the matrix quadrants
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            XCTFail("Matrix scroll view should exist")
            return
        }

        // Look for any task cell/row in the quadrants
        let firstTaskRow = scrollView.buttons.firstMatch
        guard firstTaskRow.waitForExistence(timeout: 3) else {
            // No tasks in matrix - skip gracefully
            return
        }

        // Long press to trigger context menu
        firstTaskRow.press(forDuration: 1.5)
        sleep(1)

        // Context menu should appear with these actions
        let nextUpAction = app.buttons["Next Up"]
        let editAction = app.buttons["Bearbeiten"]
        let deleteAction = app.buttons["Löschen"]

        let anyActionExists = nextUpAction.exists || editAction.exists || deleteAction.exists
        XCTAssertTrue(anyActionExists, "Context menu should show Next Up, Bearbeiten, or Löschen actions")
    }

    /// EXPECTED TO FAIL: Context menu "Next Up" action does not exist yet
    func testContextMenuHasNextUpAction() throws {
        navigateToMatrixView()

        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else { return }

        let firstTaskRow = scrollView.buttons.firstMatch
        guard firstTaskRow.waitForExistence(timeout: 3) else { return }

        firstTaskRow.press(forDuration: 1.5)
        sleep(1)

        let nextUpAction = app.buttons["Next Up"]
        XCTAssertTrue(nextUpAction.waitForExistence(timeout: 2), "Context menu should have 'Next Up' action")
    }

    /// EXPECTED TO FAIL: Context menu "Bearbeiten" action does not exist yet
    func testContextMenuHasEditAction() throws {
        navigateToMatrixView()

        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else { return }

        let firstTaskRow = scrollView.buttons.firstMatch
        guard firstTaskRow.waitForExistence(timeout: 3) else { return }

        firstTaskRow.press(forDuration: 1.5)
        sleep(1)

        let editAction = app.buttons["Bearbeiten"]
        XCTAssertTrue(editAction.waitForExistence(timeout: 2), "Context menu should have 'Bearbeiten' action")
    }

    /// EXPECTED TO FAIL: Context menu "Löschen" action does not exist yet
    func testContextMenuHasDeleteAction() throws {
        navigateToMatrixView()

        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else { return }

        let firstTaskRow = scrollView.buttons.firstMatch
        guard firstTaskRow.waitForExistence(timeout: 3) else { return }

        firstTaskRow.press(forDuration: 1.5)
        sleep(1)

        let deleteAction = app.buttons["Löschen"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 2), "Context menu should have 'Löschen' action")
    }
}
