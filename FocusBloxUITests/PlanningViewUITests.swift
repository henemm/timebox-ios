import XCTest

final class PlanningViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    func testTabNavigationExists() throws {
        // Verify tabs exist
        let backlogTab = app.tabBars.buttons["Backlog"]
        let bloxTab = app.tabBars.buttons["Blox"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(bloxTab.exists, "Blox tab should exist")
    }

    func testCanSwitchToBloeckeTab() throws {
        // Tap on Blox tab
        let bloxTab = app.tabBars.buttons["Blox"]
        bloxTab.tap()

        // Wait for navigation
        let bloxTitle = app.navigationBars["Blox"]
        let exists = bloxTitle.waitForExistence(timeout: 5)

        XCTAssertTrue(exists, "Blox navigation bar should appear after tapping tab")
    }

    func testTimelineShowsHours() throws {
        // Switch to Blöcke tab
        app.tabBars.buttons["Blox"].tap()

        // Wait for content to load
        sleep(2)

        // Smart Gaps design shows "Freie Slots" or "Tag ist frei!" instead of hour labels
        let freeSlotsHeader = app.staticTexts["Freie Slots"]
        let freeDayHeader = app.staticTexts["Tag ist frei!"]
        let hasSmartGaps = freeSlotsHeader.exists || freeDayHeader.exists

        XCTAssertTrue(hasSmartGaps, "Smart Gaps section should show 'Freie Slots' or 'Tag ist frei!'")
    }

    func testBloeckeTabScreenshot() throws {
        // Switch to Blöcke tab
        app.tabBars.buttons["Blox"].tap()
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Blox Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Unified Planning View Tests (TDD RED)
    // These tests verify the timeline-based unified planning view

    /// Test: Planning view should have a timeline ScrollView with accessibility identifier
    func testTimelineHasAccessibilityIdentifier() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-Timeline-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Timeline MUST have identifier "planningTimeline"
        let timeline = app.scrollViews["planningTimeline"]
        let exists = timeline.waitForExistence(timeout: 3)

        XCTAssertTrue(
            exists,
            "TDD RED: Planning view MUST have ScrollView with identifier 'planningTimeline'"
        )
    }

    /// Test: Focus blocks should appear in timeline with proper identifiers
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

    /// Test: Tapping on a Focus Block should open the tasks sheet (not edit sheet)
    func testTapBlockOpensTasksSheet() throws {
        navigateToBlox()

        // Find and tap a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Cannot tap block - identifier 'focusBlock_' not found")
            return
        }

        focusBlock.tap()
        sleep(1)

        // Take screenshot after tap
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-AfterBlockTap"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify TASKS sheet opened (not edit sheet)
        let tasksSheet = app.otherElements["focusBlockTasksSheet"]
        let tasksSheetTitle = app.staticTexts["Tasks im Block"]

        let tasksSheetOpened = tasksSheet.waitForExistence(timeout: 3) || tasksSheetTitle.exists

        XCTAssertTrue(tasksSheetOpened, "TDD RED: Tapping block MUST open tasks sheet")
    }

    /// Test: Focus Block should have an ellipsis button for editing
    func testFocusBlockHasEllipsisButton() throws {
        navigateToBlox()

        // Find FocusBlock first
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Focus Block not found")
            return
        }

        // Look for ellipsis/edit button - try multiple approaches
        let editButtonById = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        let editButtonByLabel = app.buttons["Block bearbeiten"]

        // Either approach should work
        let buttonExists = editButtonById.waitForExistence(timeout: 3) || editButtonByLabel.exists

        XCTAssertTrue(
            buttonExists,
            "TDD RED: Focus Block MUST have edit button"
        )
    }

    /// Test: Tapping the [...] button should open the edit sheet
    func testTapEllipsisOpensEditSheet() throws {
        navigateToBlox()

        // Take screenshot before
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "UnifiedPlanning-BeforeEllipsisTap"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Find ellipsis button by identifier (more reliable)
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        guard editButton.waitForExistence(timeout: 5) else {
            // No edit button found - this is acceptable if no blocks exist
            let focusBlock = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
            ).firstMatch

            if !focusBlock.exists {
                // No blocks exist, skip test
                throw XCTSkip("No Focus Blocks exist to test ellipsis button")
            }
            XCTFail("TDD RED: Edit button not found but Focus Block exists")
            return
        }

        // Tap the edit button
        editButton.tap()
        sleep(2) // Longer wait for sheet animation

        // Take screenshot after tap
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "UnifiedPlanning-AfterEllipsisTap"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // Verify EDIT sheet opened - check for title, date picker, or delete button
        let editTitle = app.staticTexts["Block bearbeiten"]
        let saveButton = app.buttons["Speichern"]
        let deleteButton = app.buttons["Block löschen"]

        let editSheetOpened = editTitle.waitForExistence(timeout: 5)
            || saveButton.exists
            || deleteButton.exists

        XCTAssertTrue(editSheetOpened, "TDD RED: Tapping ellipsis MUST open edit sheet")
    }

    /// Test: Free time slots should be visible in the timeline
    func testFreeSlotsVisibleInTimeline() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedPlanning-FreeSlots"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for free slot with identifier pattern
        let freeSlot = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'freeSlot_'")
        ).firstMatch

        XCTAssertTrue(
            freeSlot.waitForExistence(timeout: 5),
            "TDD RED: Free slots MUST appear in timeline with identifier 'freeSlot_{time}'"
        )
    }

    // MARK: - Scheduled Task Tests (RW_3.1b — TDD RED)

    /// Verhalten: Scheduled Tasks erscheinen auf der Timeline mit eigenem Identifier
    /// Bricht wenn: BlockPlanningView scheduled Tasks nicht in positionedItems einfuegt
    func testScheduledTaskAppearsOnTimeline() throws {
        navigateToBlox()

        // Scheduled Tasks MUESSEN als eigener Block auf der Timeline erscheinen
        // Format: scheduledTaskBlock_{taskID}
        let scheduledBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scheduledTaskBlock_'")
        ).firstMatch

        XCTAssertTrue(
            scheduledBlock.waitForExistence(timeout: 5),
            "Scheduled Task MUSS auf Timeline mit Identifier 'scheduledTaskBlock_' erscheinen"
        )
    }

    /// Verhalten: Scheduled Tasks verschwinden aus Backlog nach Scheduling
    /// Bricht wenn: BacklogView scheduled Tasks nicht filtert
    func testScheduledTaskNotInBacklog() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        guard backlogTab.waitForExistence(timeout: 5) else { return }
        backlogTab.tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 3)

        // The mock scheduled task should NOT appear in backlog
        let scheduledTaskInBacklog = app.staticTexts["[MOCK] Scheduled: Bericht schreiben"]
        XCTAssertFalse(
            scheduledTaskInBacklog.waitForExistence(timeout: 3),
            "Scheduled Tasks DUERFEN NICHT im Backlog erscheinen"
        )
    }

    private func navigateToBlox() {
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab should exist")
        bloxTab.tap()
        _ = app.scrollViews["planningTimeline"].waitForExistence(timeout: 5)
    }
}
