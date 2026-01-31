import XCTest

/// UI Tests for Bug: Assign Tab - Tasks in Focus Blocks not visible/editable
///
/// Bug description:
/// a) After assigning tasks to a Focus Block, the tasks are not visible
/// b) Tasks cannot be reordered or removed from the block
final class AssignTabTaskVisibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // MockData should include Focus Blocks WITH assigned tasks
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToAssign() {
        let assignTab = app.buttons["tab-assign"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Assign tab should exist")
        assignTab.tap()
        sleep(2)
    }

    // MARK: - Tests

    /// Test: Tasks assigned to a Focus Block should be visible
    /// Bug: After assignment, tasks disappear from the block view
    func testAssignedTasksAreVisible() throws {
        navigateToAssign()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AssignTab-TaskVisibility"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Find a Focus Block card
        let focusBlockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockCard.waitForExistence(timeout: 5),
            "Focus Block card should exist"
        )

        // DEBUG: Collect all static texts in the view
        let allTexts = app.staticTexts.allElementsBoundByIndex
        var textLabels = allTexts.prefix(30).map { $0.label }

        // DEBUG: Collect all identifiers
        let allElements = app.descendants(matching: .any).allElementsBoundByIndex
        var identifiers = allElements.compactMap { elem -> String? in
            let id = elem.identifier
            return id.isEmpty ? nil : id
        }.prefix(50).map { String($0) }

        // Look for task title inside the block
        // Tasks should have identifier pattern 'taskTitle_'
        let taskTitle = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertTrue(
            taskTitle.waitForExistence(timeout: 5),
            "BUG: Tasks not found. Texts: \(textLabels.joined(separator: ", ")). Identifiers: \(identifiers.joined(separator: ", "))"
        )
    }

    /// Test: Each task in a block should have a remove button
    func testTaskHasRemoveButton() throws {
        navigateToAssign()

        // Find task in block
        let taskInBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertTrue(
            taskInBlock.waitForExistence(timeout: 5),
            "Task in block should exist"
        )

        // Look for remove button with identifier
        let removeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'removeTaskButton_'")
        ).firstMatch

        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 3),
            "BUG: Remove button should be visible for tasks in block"
        )
    }

    /// Test: Task title should be visible in the block
    func testTaskTitleIsVisible() throws {
        navigateToAssign()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AssignTab-TaskTitles"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Find task title by identifier
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        guard taskTitle.waitForExistence(timeout: 5) else {
            XCTFail("BUG: No tasks visible in Focus Block")
            return
        }

        // The task title element should have a non-empty label
        let titleText = taskTitle.label
        XCTAssertFalse(
            titleText.isEmpty,
            "BUG: Task should have visible title text"
        )
    }

    /// Test: Removing a task from block should work
    func testRemoveTaskFromBlock() throws {
        navigateToAssign()

        // Find remove button
        let removeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'removeTaskButton_'")
        ).firstMatch

        guard removeButton.waitForExistence(timeout: 5) else {
            XCTFail("BUG: Remove button not found - tasks not visible in block")
            return
        }

        // Count tasks before removal
        let tasksBeforeCount = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).count

        // Tap remove button
        removeButton.tap()
        sleep(1)

        // Take screenshot after removal
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AssignTab-AfterRemoval"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Count tasks after removal - should be one less
        let tasksAfterCount = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).count

        XCTAssertLessThan(
            tasksAfterCount, tasksBeforeCount,
            "BUG: Task should be removed from block after tapping remove button"
        )
    }
}
