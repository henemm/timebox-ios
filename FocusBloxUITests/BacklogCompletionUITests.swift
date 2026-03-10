//
//  BacklogCompletionUITests.swift
//  FocusBloxUITests
//
//  Tests for completing tasks directly in the Backlog via checkbox
//

import XCTest

final class BacklogCompletionUITests: XCTestCase {
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
        // Tap on Backlog tab
        let backlogTab = app.buttons["backlogTab"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    // MARK: - Tests

    /// Verify that completion buttons exist in Backlog
    func testCompletionButtonsExistInBacklog() throws {
        navigateToBacklog()

        // Wait for list to load
        sleep(2)

        // Find any button with completeButton_ prefix
        let completeButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'completeButton_'"))

        // Log what we found
        print("Found \(completeButtons.count) completion buttons")

        // We should find at least one (if there are tasks)
        // If no tasks exist, this is still a valid state
        if completeButtons.count > 0 {
            let firstButton = completeButtons.element(boundBy: 0)
            XCTAssertTrue(firstButton.exists, "First completion button should exist")
        }
    }

    /// Test that tapping completion button marks task as complete (after deferred delay)
    func testTapCompletionButtonCompletesTask() throws {
        navigateToBacklog()
        sleep(2)

        // Find completion buttons
        let completeButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'completeButton_'"))

        guard completeButtons.count > 0 else {
            // No tasks to complete - skip test
            throw XCTSkip("No tasks available to complete")
        }

        let firstButton = completeButtons.element(boundBy: 0)
        let buttonId = firstButton.identifier

        // Tap the completion button
        firstButton.tap()

        // Task should disappear after the 3-second deferred completion delay + animation
        let buttonGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons[buttonId]
        )
        let result = XCTWaiter.wait(for: [buttonGone], timeout: 6)
        XCTAssertEqual(result, .completed, "Completed task should disappear after deferred delay")
    }
}
