import XCTest

/// UI Tests for Bug 15: Skip Task Loop Bug
///
/// Problem: When Focus Block has only 1 remaining task and user taps "Überspringen",
/// the same task restarts instead of ending the block.
///
/// TDD RED: This test FAILS because the bug exists
/// TDD GREEN: This test PASSES after the fix
final class SkipTaskLoopUITests: XCTestCase {

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

    private func navigateToFocus() {
        let focusTab = app.buttons["tab-focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 5), "Focus tab should exist")
        focusTab.tap()
        sleep(2)
    }

    private func findSkipButton() -> XCUIElement {
        app.buttons["Überspringen"]
    }

    private func findCurrentTaskLabel() -> XCUIElement {
        let aktuellerTask = app.staticTexts["Aktueller Task"]
        if aktuellerTask.exists { return aktuellerTask }
        return app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Zeit abgelaufen'")
        ).firstMatch
    }

    // MARK: - Bug 15 Test

    /// GIVEN: Focus Block with 3 tasks, 2 already COMPLETED (1 remaining)
    /// WHEN: User taps "Überspringen" on the last task
    /// THEN: "Alle Tasks erledigt!" should appear (block ends)
    ///
    /// This tests Bug 15: Skip the only remaining task should end the block
    func testSkipLastTaskEndsBlock() throws {
        navigateToFocus()

        let skipButton = findSkipButton()
        let completeButton = app.buttons["Erledigt"]

        guard skipButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block with skip button")
        }

        // Screenshot: Initial state (Task 1 of 3)
        let initialScreenshot = XCTAttachment(screenshot: app.screenshot())
        initialScreenshot.name = "Bug15-01-InitialState"
        initialScreenshot.lifetime = .keepAlways
        add(initialScreenshot)

        // COMPLETE Task 1 → Task 2 should appear
        guard completeButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Complete button not found")
        }
        completeButton.tap()
        sleep(2)

        let afterComplete1 = XCTAttachment(screenshot: app.screenshot())
        afterComplete1.name = "Bug15-02-AfterComplete1"
        afterComplete1.lifetime = .keepAlways
        add(afterComplete1)

        // COMPLETE Task 2 → Task 3 should appear (last remaining task)
        guard completeButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Complete button not found after first complete")
        }
        completeButton.tap()
        sleep(2)

        let afterComplete2 = XCTAttachment(screenshot: app.screenshot())
        afterComplete2.name = "Bug15-03-AfterComplete2-LastTask"
        afterComplete2.lifetime = .keepAlways
        add(afterComplete2)

        // Now SKIP the last remaining task → Should show "Alle Tasks erledigt!"
        guard skipButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Skip button not found for last task")
        }
        skipButton.tap()
        sleep(2)

        let afterSkipLast = XCTAttachment(screenshot: app.screenshot())
        afterSkipLast.name = "Bug15-04-AfterSkipLast-EXPECTED-AllDone"
        afterSkipLast.lifetime = .keepAlways
        add(afterSkipLast)

        // ASSERTION: "Alle Tasks erledigt!" should appear
        let allDoneText = app.staticTexts["Alle Tasks erledigt!"]

        XCTAssertTrue(
            allDoneText.waitForExistence(timeout: 5),
            "After skipping the last remaining task, 'Alle Tasks erledigt!' should appear. " +
            "BUG: The same task restarted instead of ending the block."
        )

        // Additional check: Skip button should NOT exist when all tasks are done
        XCTAssertFalse(
            skipButton.exists,
            "Skip button should not exist after block ends"
        )
    }

    /// Alternative test with visual evidence: Complete 2 tasks, then skip last
    /// Captures screenshots to document the fix
    func testSkipLoopVisualEvidence() throws {
        navigateToFocus()

        let skipButton = findSkipButton()
        let completeButton = app.buttons["Erledigt"]

        guard skipButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block")
        }

        // Complete first two tasks (reducing remaining to 1)
        guard completeButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Complete button not found")
        }
        completeButton.tap()
        sleep(1)

        guard completeButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Complete button not found after first complete")
        }
        completeButton.tap()
        sleep(1)

        // Screenshot before final skip (last task visible)
        let beforeFinalSkip = XCTAttachment(screenshot: app.screenshot())
        beforeFinalSkip.name = "Bug15-VisualEvidence-BeforeFinalSkip"
        beforeFinalSkip.lifetime = .keepAlways
        add(beforeFinalSkip)

        // Skip the last task
        guard skipButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Skip button not found for last task")
        }
        skipButton.tap()
        sleep(2)

        // Screenshot after final skip
        let afterFinalSkip = XCTAttachment(screenshot: app.screenshot())
        afterFinalSkip.name = "Bug15-VisualEvidence-AfterFinalSkip"
        afterFinalSkip.lifetime = .keepAlways
        add(afterFinalSkip)

        // Assert: "Alle Tasks erledigt!" should appear
        let allDone = app.staticTexts["Alle Tasks erledigt!"]
        XCTAssertTrue(
            allDone.waitForExistence(timeout: 5),
            "After skipping the last remaining task, 'Alle Tasks erledigt!' should appear."
        )
    }
}
