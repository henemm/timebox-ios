import XCTest

/// UI Tests for Deferred Task Completion feature.
///
/// When a user taps the completion checkbox:
/// 1. Checkbox immediately shows filled green checkmark
/// 2. Task stays visible with strikethrough + reduced opacity for ~3 seconds
/// 3. After 3 seconds, the task disappears from the list
///
/// The user can continue working on other tasks during the delay.
final class DeferredCompletionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    private func navigateToBacklog() {
        let backlogTab = app.buttons["backlogTab"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(2) // Wait for tasks to load
    }

    private func findFirstCompleteButton() -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
    }

    private func extractTaskID(from button: XCUIElement) -> String? {
        let id = button.identifier
        guard id.hasPrefix("completeButton_") else { return nil }
        return String(id.dropFirst("completeButton_".count))
    }

    // MARK: - Test 1: Checkbox label changes to "Erledigt" after tap (pending state)

    /// Verhalten: Tapping the complete button should immediately change its
    /// accessibility label to "Erledigt" (indicating the pending completion state).
    ///
    /// Bricht wenn: BacklogRow.swift doesn't set accessibilityLabel based on
    /// isCompletionPending (line 40).
    func testCheckboxShowsPendingStateAfterTap() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // Verify initial state is "Als erledigt markieren"
        XCTAssertEqual(button.label, "Als erledigt markieren",
            "Checkbox should initially show 'Als erledigt markieren'")

        // Tap to complete
        button.tap()

        // Brief wait for animation
        usleep(500_000)

        // The same button should now show "Erledigt" label (pending state)
        let updatedButton = app.buttons[buttonID]
        XCTAssertTrue(updatedButton.waitForExistence(timeout: 2),
            "Button should still exist immediately after tap (deferred completion)")
        XCTAssertEqual(updatedButton.label, "Erledigt",
            "After tapping, checkbox label should change to 'Erledigt' (pending state)")
    }

    // MARK: - Test 2: Task stays visible during 3-second delay

    /// Verhalten: After tapping complete, the task row should still be in the list
    /// at 1.5 seconds (within the 3-second delay window).
    ///
    /// Bricht wenn: DeferredCompletionController doesn't delay the actual
    /// SyncEngine.completeTask() call, or the delay is too short.
    func testTaskStaysVisibleDuringDelay() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // Tap to complete
        button.tap()

        // Wait 1.5 seconds (within the 3-second window)
        usleep(1_500_000)

        // Task should STILL be visible
        let sameButton = app.buttons[buttonID]
        XCTAssertTrue(sameButton.exists,
            "Task should still be visible 1.5 seconds after tapping complete. "
            + "The 3-second deferred completion should keep it in the list.")
    }

    // MARK: - Test 3: Task disappears after the delay

    /// Verhalten: After tapping complete, the task should disappear from the list
    /// after the ~3-second delay + animation.
    ///
    /// Bricht wenn: DeferredCompletionController.scheduleCompletion() never calls
    /// the onCommit callback, or pendingIDs is never cleared.
    func testTaskDisappearsAfterDelay() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // Tap to complete
        button.tap()

        // Wait for the deferred completion to fire (3s) + animation (0.35s) + margin
        let buttonGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons[buttonID]
        )
        let result = XCTWaiter.wait(for: [buttonGone], timeout: 6)
        XCTAssertEqual(result, .completed,
            "Task should disappear from the list after the 3-second deferred completion delay.")
    }

    // MARK: - Test 4: Multiple tasks can be completed independently

    /// Verhalten: Completing two tasks in quick succession should show both
    /// in pending state simultaneously.
    ///
    /// Bricht wenn: DeferredCompletionController uses a single shared timer
    /// instead of per-task timers.
    func testMultipleTasksCanBePendingSimultaneously() throws {
        navigateToBacklog()

        let buttons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        )

        guard buttons.count >= 2 else {
            throw XCTSkip("Need at least 2 tasks in backlog")
        }

        let firstButton = buttons.element(boundBy: 0)
        let secondButton = buttons.element(boundBy: 1)
        let firstID = firstButton.identifier
        let secondID = secondButton.identifier

        // Complete first task
        firstButton.tap()
        usleep(500_000)

        // Complete second task
        secondButton.tap()
        usleep(500_000)

        // Both should still exist (in pending state)
        XCTAssertTrue(app.buttons[firstID].exists,
            "First completed task should still be visible (pending)")
        XCTAssertTrue(app.buttons[secondID].exists,
            "Second completed task should still be visible (pending)")

        // Both should show "Erledigt" label
        XCTAssertEqual(app.buttons[firstID].label, "Erledigt",
            "First task should show 'Erledigt' label")
        XCTAssertEqual(app.buttons[secondID].label, "Erledigt",
            "Second task should show 'Erledigt' label")
    }

    // MARK: - Test 5: Double-tap doesn't trigger completion twice

    /// Verhalten: Tapping the checkbox while already in pending state should
    /// be ignored (button is disabled during pending).
    ///
    /// Bricht wenn: BacklogRow doesn't guard against isCompletionPending
    /// in the button action (line 30).
    func testDoubleTapIsIgnored() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // First tap
        button.tap()
        usleep(300_000)

        // Second tap (should be ignored)
        app.buttons[buttonID].tap()
        usleep(300_000)

        // Task should still be visible and in pending state
        let sameButton = app.buttons[buttonID]
        XCTAssertTrue(sameButton.exists,
            "Task should still be visible after double-tap")
        XCTAssertEqual(sameButton.label, "Erledigt",
            "Task should still show pending state after double-tap")
    }
}
