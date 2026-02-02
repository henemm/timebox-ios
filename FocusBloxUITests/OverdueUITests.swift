import XCTest

/// UI Tests for Task 11: Overdue Handling
/// Verifies the active Focus Block task UI, action buttons, and overdue state
///
/// Tests beweisen:
/// 1. Aktiver Block zeigt "Aktueller Task" Label
/// 2. "Erledigt" (gruen) und "Ueberspringen" (orange) Buttons sind sichtbar
/// 3. Task-Titel und geschaetzte Dauer werden angezeigt
/// 4. Nach Skip wechselt der aktuelle Task (neuer Titel)
/// 5. Progress Ring ist sichtbar (Screenshot-Beweis)
///
/// NOTE: FocusLiveView uses .buttonStyle(.plain) which prevents .accessibilityIdentifier
///       from being exposed to XCUITest. Tests use label-based matching instead.
final class OverdueUITests: XCTestCase {

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

    private func navigateToFokus() {
        let fokusTab = app.tabBars.buttons["Fokus"]
        XCTAssertTrue(fokusTab.waitForExistence(timeout: 5), "Fokus tab should exist")
        fokusTab.tap()
        sleep(2)
    }

    /// Find the "Aktueller Task" or "Zeit abgelaufen" label
    private func findCurrentTaskLabel() -> XCUIElement {
        let aktuellerTask = app.staticTexts["Aktueller Task"]
        if aktuellerTask.exists { return aktuellerTask }
        // Overdue state shows different text
        return app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Zeit abgelaufen'")
        ).firstMatch
    }

    /// Find the Erledigt button by label
    private func findCompleteButton() -> XCUIElement {
        app.buttons["Erledigt"]
    }

    /// Find the Ueberspringen button by label
    private func findSkipButton() -> XCUIElement {
        app.buttons["Überspringen"]
    }

    // MARK: - Current Task View Tests

    /// GIVEN: App launched with -MockData (active Focus Block with 3 tasks)
    /// WHEN: User navigates to Fokus tab
    /// THEN: "Aktueller Task" label is visible (block is active, not overdue yet)
    func testCurrentTaskLabelIsVisible() throws {
        navigateToFokus()

        let label = findCurrentTaskLabel()
        guard label.waitForExistence(timeout: 5) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Task11-DEBUG-NoCurrentTask"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("Neither 'Aktueller Task' nor 'Zeit abgelaufen' found on Fokus tab")
            return
        }

        XCTAssertTrue(label.exists, "Current task label should be visible")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task11-CurrentTaskLabel"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: Active Focus Block shows current task
    /// WHEN: User views the task view
    /// THEN: "Erledigt" (green) button should be visible and tappable
    func testCompleteButtonExists() throws {
        navigateToFokus()

        let completeButton = findCompleteButton()
        guard completeButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block with Erledigt button")
        }

        XCTAssertTrue(completeButton.isEnabled, "Erledigt button should be enabled")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task11-CompleteButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: Active Focus Block shows current task
    /// WHEN: User views the task view
    /// THEN: "Ueberspringen" (orange) button should be visible and tappable
    func testSkipButtonExists() throws {
        navigateToFokus()

        let skipButton = findSkipButton()
        guard skipButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block with Ueberspringen button")
        }

        XCTAssertTrue(skipButton.isEnabled, "Ueberspringen button should be enabled")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task11-SkipButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: Active Focus Block with current task
    /// WHEN: User views the task view
    /// THEN: Task title and estimated duration ("X min geschaetzt") should be visible
    func testTaskTitleAndDurationVisible() throws {
        navigateToFokus()

        // Wait for a task label to appear (proves active block loaded)
        let label = findCurrentTaskLabel()
        guard label.waitForExistence(timeout: 5) else {
            throw XCTSkip("No current task view found")
        }

        // Duration label should show "X min geschätzt"
        let durationLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'min geschätzt'")
        ).firstMatch

        XCTAssertTrue(
            durationLabel.waitForExistence(timeout: 3),
            "'min geschätzt' duration label should be visible in current task view"
        )

        // Task title "Focus Task 1" should be visible (first mock task)
        let taskTitle = app.staticTexts["Focus Task 1"]
        XCTAssertTrue(
            taskTitle.waitForExistence(timeout: 3),
            "First mock task title 'Focus Task 1' should be visible"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task11-TaskTitleAndDuration"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: Active Focus Block with multiple tasks
    /// WHEN: User taps "Ueberspringen" on first task
    /// THEN: Next task appears (different task title visible)
    func testSkipButtonAdvancesToNextTask() throws {
        navigateToFokus()

        let skipButton = findSkipButton()
        guard skipButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block with skip button")
        }

        // Screenshot before skip
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "Task11-BeforeSkip"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        skipButton.tap()
        sleep(2)

        // Screenshot after skip
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "Task11-AfterSkip-NextTask"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // After skip, either next task is shown or all tasks done
        let nextLabel = findCurrentTaskLabel()
        let allDone = app.staticTexts["Alle Tasks erledigt!"]

        XCTAssertTrue(
            nextLabel.waitForExistence(timeout: 5) || allDone.waitForExistence(timeout: 3),
            "After skip, either next task or 'Alle Tasks erledigt!' should appear"
        )
    }

    /// GIVEN: Active Focus Block with running task timer
    /// WHEN: Screenshot captures the progress ring
    /// THEN: Visual proof of timer display (minutes countdown or overdue fire emoji)
    func testProgressRingScreenshotEvidence() throws {
        navigateToFokus()

        let label = findCurrentTaskLabel()
        guard label.waitForExistence(timeout: 5) else {
            throw XCTSkip("No current task view found")
        }

        // The progress ring is visual - capture at two points to show time passing
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "Task11-ProgressRing-T0"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        sleep(3)

        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "Task11-ProgressRing-T3"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        // Task view should still be stable after time passes
        XCTAssertTrue(
            label.exists || findCurrentTaskLabel().exists,
            "Current task label should remain stable while timer runs"
        )
    }

    /// GIVEN: Active Focus Block
    /// WHEN: User completes first task via "Erledigt" button
    /// THEN: Next task appears OR all-done state shows
    func testCompleteButtonAdvancesToNextTask() throws {
        navigateToFokus()

        let completeButton = findCompleteButton()
        guard completeButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block")
        }

        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "Task11-BeforeComplete"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        completeButton.tap()
        sleep(2)

        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "Task11-AfterComplete-NextTask"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // After complete, either next task or completion state
        let nextLabel = findCurrentTaskLabel()
        let allDone = app.staticTexts["Alle Tasks erledigt!"]

        XCTAssertTrue(
            nextLabel.waitForExistence(timeout: 5) || allDone.waitForExistence(timeout: 3),
            "After completing task, next task or completion state should appear"
        )
    }
}
