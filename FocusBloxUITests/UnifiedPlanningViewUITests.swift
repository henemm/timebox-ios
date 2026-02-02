import XCTest

/// UI Tests for Unified Planning View (iOS/macOS)
///
/// Tests verify:
/// 1. FocusBlocks appear in timeline (not as list)
/// 2. Tap on block opens tasks sheet
/// 3. Tap on [...] button opens edit sheet
/// 4. Free slots visible in timeline
///
/// TDD RED: All tests should FAIL until implementation is complete
final class UnifiedPlanningViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToBlox() {
        let bloxTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blöcke tab should exist")
        bloxTab.tap()
        sleep(2)
    }

    // MARK: - Test 1: Timeline exists with identifier

    /// Test: Planning view should have a timeline ScrollView with accessibility identifier
    /// TDD RED: Tests FAIL because timeline identifier doesn't exist yet
    func testTimelineHasAccessibilityIdentifier() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-Timeline-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Timeline MUST have identifier "planningTimeline"
        // This is a NEW identifier that doesn't exist in current implementation
        let timeline = app.scrollViews["planningTimeline"]
        let exists = timeline.waitForExistence(timeout: 3)


        XCTAssertTrue(
            exists,
            "TDD RED: Planning view MUST have ScrollView with identifier 'planningTimeline' - current implementation uses list-based smartGapsContent instead of timeline. Found scrollViews: \(app.scrollViews.count)"
        )
    }

    // MARK: - Test 2: FocusBlock appears in timeline (not as list)

    /// Test: Focus blocks should appear in timeline with proper identifiers
    /// TDD RED: Tests FAIL because blocks are in list format, not timeline
    func testFocusBlockAppearsInTimeline() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-FocusBlockInTimeline"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for a FocusBlock with timeline-style identifier
        // Format: focusBlock_{blockID}
        let focusBlockInTimeline = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockInTimeline.waitForExistence(timeout: 5),
            "TDD RED: Focus Block MUST appear in timeline with identifier 'focusBlock_{id}'"
        )
    }

    // MARK: - Test 3: Tap on block opens tasks sheet

    /// Test: Tapping on a Focus Block should open the tasks sheet (not edit sheet)
    /// TDD RED: Tests FAIL because tap currently opens edit sheet
    func testTapBlockOpensTasksSheet() throws {
        navigateToBlox()

        // Find and tap a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlock.waitForExistence(timeout: 5),
            "TDD RED: Cannot tap block - identifier 'focusBlock_' not found"
        )

        focusBlock.tap()
        sleep(1)

        // Take screenshot after tap
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-AfterBlockTap"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify TASKS sheet opened (not edit sheet)
        // Tasks sheet has identifier "focusBlockTasksSheet"
        let tasksSheet = app.otherElements["focusBlockTasksSheet"]
        let tasksSheetTitle = app.staticTexts["Tasks im Block"]

        let tasksSheetOpened = tasksSheet.waitForExistence(timeout: 3) || tasksSheetTitle.exists

        // Also verify it's NOT the edit sheet
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let isEditSheet = editSheetTitle.exists

        XCTAssertTrue(tasksSheetOpened, "TDD RED: Tapping block MUST open tasks sheet, not edit sheet")
        XCTAssertFalse(isEditSheet, "TDD RED: Tapping block should NOT open edit sheet directly")
    }

    // MARK: - Test 4: [...] button exists on FocusBlock

    /// Test: Focus Block should have an ellipsis button for editing
    /// TDD RED: Tests FAIL because ellipsis button doesn't exist yet
    func testFocusBlockHasEllipsisButton() throws {
        navigateToBlox()

        // Find FocusBlock first
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlock.waitForExistence(timeout: 5),
            "TDD RED: Focus Block not found"
        )

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-EllipsisButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for ellipsis/edit button with identifier pattern
        // Format: focusBlockEditButton_{blockID}
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        XCTAssertTrue(
            editButton.waitForExistence(timeout: 3),
            "TDD RED: Focus Block MUST have edit button with identifier 'focusBlockEditButton_{id}'"
        )
    }

    // MARK: - Test 5: Tap ellipsis opens edit sheet

    /// Test: Tapping the [...] button should open the edit sheet
    /// TDD RED: Tests FAIL because ellipsis button doesn't exist yet
    func testTapEllipsisOpensEditSheet() throws {
        navigateToBlox()

        // Find ellipsis button
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "TDD RED: Cannot tap ellipsis - button not found"
        )

        editButton.tap()
        sleep(1)

        // Take screenshot after tap
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-AfterEllipsisTap"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify EDIT sheet opened
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let saveButton = app.buttons["Speichern"]

        let editSheetOpened = editSheetTitle.waitForExistence(timeout: 3) || saveButton.exists

        XCTAssertTrue(editSheetOpened, "TDD RED: Tapping ellipsis MUST open edit sheet")
    }

    // MARK: - Test 6: Free slots visible in timeline

    /// Test: Free time slots should be visible in the timeline
    /// TDD RED: Tests FAIL if slots are in list format instead of timeline
    func testFreeSlotsVisibleInTimeline() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-FreeSlots"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for free slot with identifier pattern
        // Format: freeSlot_{startTime} e.g., freeSlot_10:00
        let freeSlot = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch

        XCTAssertTrue(
            freeSlot.waitForExistence(timeout: 5),
            "TDD RED: Free slots MUST appear in timeline with identifier 'freeSlot_{time}'"
        )
    }

    // MARK: - Test 7: Tasks sheet has task list

    /// Test: Tasks sheet should show list of tasks in the block
    /// TDD RED: Tests FAIL because tasks sheet doesn't exist yet
    func testTasksSheetShowsTaskList() throws {
        navigateToBlox()

        // Find and tap a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Focus Block not found")
            return
        }

        focusBlock.tap()
        sleep(1)

        // Take screenshot of tasks sheet
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-TasksSheet"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify tasks list exists in the sheet
        let tasksList = app.tables.firstMatch

        // Or look for task rows with identifier
        let taskRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'blockTask_'")
        ).firstMatch

        let hasTaskList = tasksList.waitForExistence(timeout: 3) || taskRow.exists

        XCTAssertTrue(hasTaskList, "TDD RED: Tasks sheet MUST contain a list of tasks")
    }

    // MARK: - Test 8: Tasks sheet has add task button

    /// Test: Tasks sheet should have button to add tasks
    /// TDD RED: Tests FAIL because tasks sheet doesn't exist yet
    func testTasksSheetHasAddTaskButton() throws {
        navigateToBlox()

        // Find and tap a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Focus Block not found")
            return
        }

        focusBlock.tap()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-AddTaskButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for "Task hinzufügen" or "+ Task" button
        let addTaskButton = app.buttons["addTaskToBlockButton"]
        let addTaskLabel = app.buttons["+ Task"]
        let addTaskLabelDE = app.buttons["Task hinzufügen"]

        let hasAddButton = addTaskButton.waitForExistence(timeout: 3)
            || addTaskLabel.exists
            || addTaskLabelDE.exists

        XCTAssertTrue(hasAddButton, "TDD RED: Tasks sheet MUST have 'Add Task' button")
    }

    // MARK: - Test 9: Tasks sheet has done button

    /// Test: Tasks sheet should have done/close button
    /// TDD RED: Tests FAIL because tasks sheet doesn't exist yet
    func testTasksSheetHasDoneButton() throws {
        navigateToBlox()

        // Find and tap a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Focus Block not found")
            return
        }

        focusBlock.tap()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-DoneButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for "Fertig" button
        let doneButton = app.buttons["Fertig"]
        let doneButtonEN = app.buttons["Done"]

        let hasDoneButton = doneButton.waitForExistence(timeout: 3) || doneButtonEN.exists

        XCTAssertTrue(hasDoneButton, "TDD RED: Tasks sheet MUST have 'Fertig' button")
    }

    // MARK: - Test 10: Timeline shows hour markers

    /// Test: Timeline should show hour markers (06:00, 07:00, etc.)
    func testTimelineShowsHourMarkers() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-HourMarkers"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for hour labels (format: HH:00)
        let hourLabel = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '\\\\d{2}:00'")
        ).firstMatch

        XCTAssertTrue(
            hourLabel.waitForExistence(timeout: 5),
            "TDD RED: Timeline MUST show hour markers"
        )
    }
}
