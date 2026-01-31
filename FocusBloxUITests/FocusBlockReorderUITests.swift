import XCTest

/// UI Tests for Focus Block Task Reordering
/// Tests drag-and-drop functionality to reorder tasks within a Focus Block
final class FocusBlockReorderUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helper Methods

    private func navigateToAssignTab() {
        let assignTab = app.buttons["tab-assign"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Assign tab should exist")
        assignTab.tap()
    }

    private func createTestTasksAndBlock() {
        // Navigate to Backlog and create tasks
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Create first task
        let quickCaptureField = app.textFields["quickCaptureField"]
        if quickCaptureField.waitForExistence(timeout: 3) {
            quickCaptureField.tap()
            quickCaptureField.typeText("Reorder Task A")
            app.buttons["quickCaptureSubmit"].tap()
        }

        // Create second task
        if quickCaptureField.waitForExistence(timeout: 3) {
            quickCaptureField.tap()
            quickCaptureField.typeText("Reorder Task B")
            app.buttons["quickCaptureSubmit"].tap()
        }

        // Create third task
        if quickCaptureField.waitForExistence(timeout: 3) {
            quickCaptureField.tap()
            quickCaptureField.typeText("Reorder Task C")
            app.buttons["quickCaptureSubmit"].tap()
        }
    }

    // MARK: - Test: Drag Handle Exists

    /// Test: Drag handle should be visible for each task in a Focus Block
    /// EXPECTED TO FAIL: dragHandle element doesn't exist yet
    func testDragHandleExistsForTasksInBlock() throws {
        navigateToAssignTab()

        // Wait for assign tab content
        let scrollView = app.scrollViews["assignTabScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Assign scroll view should exist")

        // Look for any focus block card
        let focusBlockCard = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        if focusBlockCard.waitForExistence(timeout: 3) {
            // Look for drag handle within the block
            // The drag handle should have identifier "dragHandle_[taskID]"
            let dragHandle = focusBlockCard.images.matching(
                NSPredicate(format: "identifier BEGINSWITH 'dragHandle_'")
            ).firstMatch

            XCTAssertTrue(
                dragHandle.waitForExistence(timeout: 3),
                "Drag handle should exist for tasks in Focus Block"
            )
        } else {
            // No blocks exist - still check that the element pattern would work
            // by verifying the accessibility infrastructure
            XCTFail("No Focus Block found - create a block with tasks first to test drag handles")
        }
    }

    /// Test: Drag handle should be accessible via accessibility identifier
    /// EXPECTED TO FAIL: dragHandle accessibility identifier not implemented
    func testDragHandleAccessibilityIdentifier() throws {
        navigateToAssignTab()

        let scrollView = app.scrollViews["assignTabScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Assign scroll view should exist")

        // Search for any drag handle element globally
        let anyDragHandle = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dragHandle_'")
        ).firstMatch

        // This should fail because drag handles don't exist yet
        XCTAssertTrue(
            anyDragHandle.exists,
            "At least one drag handle should exist when blocks have tasks"
        )
    }

    // MARK: - Test: Reorder Functionality

    /// Test: Dragging a task should change its position in the block
    /// Requires: Focus Block with at least 2 tasks assigned
    func testReorderTaskByDrag() throws {
        navigateToAssignTab()

        let scrollView = app.scrollViews["assignTabScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Assign scroll view should exist")

        // Find a focus block with multiple tasks
        let focusBlockCard = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        guard focusBlockCard.waitForExistence(timeout: 3) else {
            // Skip test if no Focus Block exists - this is expected in clean test environment
            throw XCTSkip("No Focus Block found - test requires pre-existing block with 2+ tasks")
        }

        // Find tasks in block
        let tasksInBlock = focusBlockCard.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskInBlock_'")
        )

        guard tasksInBlock.count >= 2 else {
            // Skip test if not enough tasks - test requires 2+ tasks to test reordering
            throw XCTSkip("Need at least 2 tasks in block to test reordering")
        }

        let firstTask = tasksInBlock.element(boundBy: 0)
        let secondTask = tasksInBlock.element(boundBy: 1)

        // Get initial positions
        let firstTaskFrame = firstTask.frame
        let secondTaskFrame = secondTask.frame

        // Find drag handle of first task
        let firstDragHandle = firstTask.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dragHandle_'")
        ).firstMatch

        XCTAssertTrue(
            firstDragHandle.waitForExistence(timeout: 3),
            "First task should have a drag handle"
        )

        // Perform drag from first task to below second task
        firstDragHandle.press(forDuration: 0.5, thenDragTo: secondTask)

        // After reorder, first task should now be in second position
        // Verify by checking that positions have swapped
        let updatedFirstTask = tasksInBlock.element(boundBy: 0)
        let updatedSecondTask = tasksInBlock.element(boundBy: 1)

        // The original first task should now be second
        XCTAssertNotEqual(
            firstTaskFrame.minY,
            updatedFirstTask.frame.minY,
            "Task positions should have changed after reorder"
        )
    }

    // MARK: - Test: Reorder Persistence

    /// Test: Reordered tasks should persist after navigating away and back
    /// Requires: Focus Block with at least 2 tasks assigned
    func testReorderPersistsAfterNavigation() throws {
        navigateToAssignTab()

        let scrollView = app.scrollViews["assignTabScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Assign scroll view should exist")

        // Find focus block
        let focusBlockCard = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        guard focusBlockCard.waitForExistence(timeout: 3) else {
            // Skip test if no Focus Block exists - this is expected in clean test environment
            throw XCTSkip("No Focus Block found - test requires pre-existing block with 2+ tasks")
        }

        // Find tasks and their titles before reorder
        let tasksInBlock = focusBlockCard.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskInBlock_'")
        )

        guard tasksInBlock.count >= 2 else {
            // Skip test if not enough tasks - test requires 2+ tasks to test reordering
            throw XCTSkip("Need at least 2 tasks to test persistence")
        }

        // Get first task's title element
        let firstTaskTitle = tasksInBlock.element(boundBy: 0).staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        guard firstTaskTitle.exists else {
            XCTFail("First task should have a title")
            return
        }

        let originalFirstTitle = firstTaskTitle.label

        // Find and use drag handle to reorder
        let firstDragHandle = tasksInBlock.element(boundBy: 0).images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dragHandle_'")
        ).firstMatch

        XCTAssertTrue(
            firstDragHandle.waitForExistence(timeout: 3),
            "Drag handle must exist for reorder test"
        )

        // Drag first task to second position
        let secondTask = tasksInBlock.element(boundBy: 1)
        firstDragHandle.press(forDuration: 0.5, thenDragTo: secondTask)

        // Navigate away to another tab
        let backlogTab = app.buttons["tab-backlog"]
        backlogTab.tap()

        // Wait a moment for state to settle
        Thread.sleep(forTimeInterval: 1.0)

        // Navigate back to Assign tab
        let assignTab = app.buttons["tab-assign"]
        assignTab.tap()

        // Verify the new order persisted
        let updatedScrollView = app.scrollViews["assignTabScrollView"]
        XCTAssertTrue(updatedScrollView.waitForExistence(timeout: 5), "Assign scroll view should exist after navigation")

        let updatedFocusBlockCard = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        guard updatedFocusBlockCard.waitForExistence(timeout: 3) else {
            XCTFail("Focus Block should still exist after navigation")
            return
        }

        let updatedTasksInBlock = updatedFocusBlockCard.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskInBlock_'")
        )

        // The original first task should now be second
        let newSecondTaskTitle = updatedTasksInBlock.element(boundBy: 1).staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertEqual(
            newSecondTaskTitle.label,
            originalFirstTitle,
            "Original first task should now be in second position after reorder"
        )
    }
}
