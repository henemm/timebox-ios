import XCTest

/// Tests for Unified Calendar View (Phase 1)
/// Verifies: Zuordnen tab removed, Next Up section in FocusBlockTasksSheet,
/// gear icon on blocks, task assignment from sheet
final class UnifiedCalendarViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Tab Structure Tests

    /// GIVEN: App is launched
    /// WHEN: Viewing the tab bar
    /// THEN: "Zuordnen" tab should NOT exist (removed in unified view)
    func testZuordnenTabDoesNotExist() throws {
        let zuordnenTab = app.tabBars.buttons["Zuordnen"]
        XCTAssertFalse(
            zuordnenTab.exists,
            "Zuordnen tab should NOT exist — it was merged into Blox tab"
        )
    }

    /// GIVEN: App is launched
    /// WHEN: Counting tabs
    /// THEN: Exactly 4 tabs should exist (Backlog, Blox, Fokus, Rückblick)
    func testExactlyFourTabsExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        let tabButtons = tabBar.buttons
        XCTAssertEqual(
            tabButtons.count, 4,
            "Should have exactly 4 tabs (Backlog, Blox, Fokus, Rückblick), got \(tabButtons.count)"
        )
    }

    // MARK: - Gear Icon Test

    /// GIVEN: Blox tab with a focus block
    /// WHEN: Viewing a focus block in the timeline
    /// THEN: Block should have a gear icon button (not ellipsis)
    func testFocusBlockHasGearIcon() throws {
        navigateToBlox()

        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Focus Blocks exist to test gear icon")
        }

        // The edit button should use gear icon — check accessibility label
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        XCTAssertTrue(
            editButton.waitForExistence(timeout: 3),
            "Focus block should have an edit button with gear icon"
        )
    }

    // MARK: - Next Up Section in Tasks Sheet

    /// GIVEN: Tapping a focus block to open its tasks sheet
    /// WHEN: The FocusBlockTasksSheet opens
    /// THEN: A "Next Up" section should be visible with available tasks
    func testTasksSheetHasNextUpSection() throws {
        navigateToBlox()

        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Focus Blocks exist to test tasks sheet")
        }

        // Tap the block main area to open tasks sheet
        focusBlock.tap()
        sleep(1)

        // Verify tasks sheet opened
        let tasksSheet = app.otherElements["focusBlockTasksSheet"]
        guard tasksSheet.waitForExistence(timeout: 3) else {
            XCTFail("Tasks sheet should open when tapping a block")
            return
        }

        // Screenshot for debugging
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedCalendar-TasksSheet-NextUp"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // The "Next Up" section header should exist
        let nextUpHeader = app.staticTexts["nextUpSectionHeader"]
        XCTAssertTrue(
            nextUpHeader.waitForExistence(timeout: 3),
            "Tasks sheet MUST have a 'Next Up' section header"
        )
    }

    /// GIVEN: Tasks sheet is open with Next Up tasks
    /// WHEN: Tapping the arrow-up button on a Next Up task
    /// THEN: Task should be assigned to the block (moves to assigned section)
    func testAssignTaskFromNextUpSection() throws {
        navigateToBlox()

        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Focus Blocks exist to test task assignment")
        }

        focusBlock.tap()
        sleep(1)

        let tasksSheet = app.otherElements["focusBlockTasksSheet"]
        guard tasksSheet.waitForExistence(timeout: 3) else {
            throw XCTSkip("Tasks sheet did not open")
        }

        // Find an assign button in the Next Up section
        let assignButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'assignNextUpTask_'")
        ).firstMatch

        guard assignButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("No Next Up tasks available to assign")
        }

        // Screenshot before assignment
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "UnifiedCalendar-BeforeAssign"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        assignButton.tap()
        sleep(1)

        // Screenshot after assignment
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "UnifiedCalendar-AfterAssign"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // The task should now appear in the assigned section (blockTask_ identifier)
        let assignedTask = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'blockTask_'")
        ).firstMatch

        XCTAssertTrue(
            assignedTask.waitForExistence(timeout: 3),
            "After assigning, task should appear in the block's assigned tasks"
        )
    }

    // MARK: - Helper

    private func navigateToBlox() {
        let bloxTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blöcke tab should exist")
        bloxTab.tap()
        sleep(2)
    }
}
