import XCTest

/// Bug 81: FocusBlock Edit Sheet — Task zuweisen, Sheet schliessen, erster Task verschwunden.
/// Root Cause: Stale value-type FocusBlock captured in .sheet(item:) closure.
/// Second assignment overwrites first because block snapshot is never updated.
final class Bug81StaleBlockAssignmentUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers (same pattern as Bug68)

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
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Tasks sheet should open on block tap")
        return sheet
    }

    /// Expand "Alle Tasks" section (same pattern as Bug68)
    private func expandAlleTasksSection() -> Bool {
        let disclosure = app.descendants(matching: .any)["allTasksDisclosure"].firstMatch
        guard disclosure.waitForExistence(timeout: 3) else {
            return false
        }
        if !disclosure.isHittable {
            app.swipeUp()
            sleep(1)
        }
        disclosure.tap()
        sleep(1)
        return true
    }

    // MARK: - Bug 81: Two assignments — first task disappears

    /// GIVEN: A FocusBlock with tasks sheet open
    /// WHEN: User assigns two tasks sequentially from "Alle Tasks"
    /// THEN: BOTH tasks should appear in the assigned section
    func testAssignTwoTasks_bothShouldAppearInBlock_Bug81() throws {
        _ = try openFocusBlockSheet()

        // Count initially assigned tasks
        let initialAssigned = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'blockTask_'")
        ).count

        // Expand "Alle Tasks" to get assignable backlog tasks
        XCTAssertTrue(expandAlleTasksSection(), "'Alle Tasks' section must exist")

        // Scroll to reveal expanded content
        app.swipeUp()
        sleep(1)

        // Find the assign "+" buttons by their accessibility label
        // SheetNextUpRow sets .accessibilityLabel("Task zum Block hinzufügen") on the button
        let assignButtons = app.buttons.matching(
            NSPredicate(format: "label == 'Task zum Block hinzufügen'")
        )

        guard assignButtons.count >= 2 else {
            // Debug: what buttons are visible?
            let allBtns = app.buttons.allElementsBoundByIndex
            var debugInfo: [String] = []
            for i in 0..<min(allBtns.count, 20) {
                let btn = allBtns[i]
                let info = "id=\(btn.identifier),label=\(btn.label)"
                debugInfo.append(info)
            }
            XCTFail("Bug 81: Need >= 2 assign buttons (by label). Found: \(assignButtons.count). Buttons: \(debugInfo)")
            return
        }

        // ASSIGN FIRST TASK
        assignButtons.element(boundBy: 0).tap()
        sleep(2)

        // ASSIGN SECOND TASK — re-query since UI changed
        let remainingButtons = app.buttons.matching(
            NSPredicate(format: "label == 'Task zum Block hinzufügen'")
        )
        guard remainingButtons.count >= 1 else {
            XCTFail("Bug 81: No remaining assign buttons after first assignment")
            return
        }
        remainingButtons.element(boundBy: 0).tap()
        sleep(2)

        // Scroll back up to see assigned section
        app.swipeDown()
        sleep(1)

        // VERIFY: Both newly assigned tasks should appear in block
        let finalAssigned = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'blockTask_'")
        ).count

        let newlyAssigned = finalAssigned - initialAssigned
        XCTAssertGreaterThanOrEqual(newlyAssigned, 2,
            "Bug 81: Both assigned tasks must appear. Initial: \(initialAssigned), Final: \(finalAssigned), New: \(newlyAssigned)")
    }
}
