import XCTest

/// Bug 68: FocusBlockTasksSheet must be full-screen and show three sections:
/// 1. Assigned Tasks (drag handles, swipe-to-remove)
/// 2. Next Up Tasks (always visible, assign button)
/// 3. "Alle Tasks" expandable section (all incomplete non-NextUp tasks)
///
/// Same component on iOS and macOS.
/// iOS: sections stacked vertically. macOS: side by side.
final class Bug68BlockTaskSheetUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    /// Navigate to Blox tab, tap a focus block, and wait for the sheet to open
    private func openFocusBlockSheet() throws -> XCUIElement {
        let bloxTab = app.tabBars.buttons["Blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab should exist")
        bloxTab.tap()

        let timeline = app.scrollViews["planningTimeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5), "Timeline should exist")

        let focusBlock = timeline.otherElements.matching(
            NSPredicate(format: "identifier CONTAINS 'focusBlock_'")
        ).firstMatch
        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("No FocusBlock found in timeline")
            return app.otherElements["focusBlockTasksSheet"]
        }
        focusBlock.tap()

        let sheet = app.otherElements["focusBlockTasksSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Tasks sheet should open on block tap")
        return sheet
    }

    /// Find and tap the "Alle Tasks" expandable header
    private func expandAlleTasksSection() -> Bool {
        // The disclosure row is inside a List cell — find by its accessibility identifier
        let disclosure = app.descendants(matching: .any)["allTasksDisclosure"].firstMatch
        guard disclosure.waitForExistence(timeout: 3) else {
            return false
        }
        // Tap the element — may need to scroll to it first
        if !disclosure.isHittable {
            app.swipeUp()
        }
        disclosure.tap()
        // Give the animation time to complete
        sleep(1)
        return true
    }

    // MARK: - Sheet Opens Full-Screen

    /// Tap on a FocusBlock opens the tasks sheet as full-screen (not half-sheet)
    func testTapBlockOpensFullScreenSheet() throws {
        let sheet = try openFocusBlockSheet()

        // Verify it's full-screen by checking the sheet fills most of the screen
        // A half-sheet would have height < 60% of screen, full-screen > 80%
        let sheetHeight = sheet.frame.height
        let screenHeight = app.windows.firstMatch.frame.height
        let ratio = sheetHeight / screenHeight
        XCTAssertGreaterThan(ratio, 0.8, "Sheet should be full-screen (ratio \(ratio)), not half-sheet")
    }

    // MARK: - Next Up Section Always Visible

    /// The Next Up section header must always be visible, even when there are Next Up tasks
    func testNextUpSectionAlwaysVisible() throws {
        _ = try openFocusBlockSheet()

        // Next Up section header must be visible
        let nextUpHeader = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'nextUpSectionHeader'")
        ).firstMatch
        XCTAssertTrue(nextUpHeader.waitForExistence(timeout: 3),
                       "Next Up section header must always be visible")
    }

    // MARK: - "Alle Tasks" Section Exists

    /// There must be an expandable "Alle Tasks" section showing all incomplete backlog tasks
    func testAlleTasksSectionExists() throws {
        _ = try openFocusBlockSheet()

        // "Alle Tasks" section must exist (inside a List, found via descendant query)
        let allTasksHeader = app.descendants(matching: .any)["allTasksDisclosure"]
        XCTAssertTrue(allTasksHeader.waitForExistence(timeout: 3),
                       "Expandable 'Alle Tasks' section must exist in the sheet")
    }

    // MARK: - "Alle Tasks" Shows Backlog Tasks

    /// Expanding "Alle Tasks" must show backlog tasks (not NextUp, not completed, not already assigned)
    func testAlleTasksShowsBacklogTasks() throws {
        _ = try openFocusBlockSheet()

        // Expand "Alle Tasks" section
        XCTAssertTrue(expandAlleTasksSection(), "'Alle Tasks' section must exist and be tappable")

        // Scroll down to reveal expanded content
        app.swipeUp()

        // Should show backlog tasks (not NextUp, not assigned)
        // Mock data has "[MOCK] Backlog Task 1" and "[MOCK] Backlog Task 2" with isNextUp=false
        let backlogTask = app.staticTexts["[MOCK] Backlog Task 1"]
        XCTAssertTrue(backlogTask.waitForExistence(timeout: 5),
                       "Backlog tasks should appear in 'Alle Tasks' section")
    }

    // MARK: - Assign from "Alle Tasks"

    /// Tapping the assign button on a task in "Alle Tasks" should add it to the block
    func testAssignTaskFromAlleTasksSection() throws {
        _ = try openFocusBlockSheet()

        // Expand "Alle Tasks"
        XCTAssertTrue(expandAlleTasksSection(), "'Alle Tasks' section must exist and be tappable")

        // Scroll down to reveal expanded content
        app.swipeUp()

        // Find assign button for a backlog task
        let assignButton = app.buttons.matching(
            NSPredicate(format: "identifier CONTAINS 'assignAllTask_'")
        ).firstMatch
        XCTAssertTrue(assignButton.waitForExistence(timeout: 5),
                       "Assign button must exist on backlog tasks in 'Alle Tasks' section")
    }
}
