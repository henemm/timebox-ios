import XCTest

/// UI Tests for BUG-126: Completion toggle must stay editable during 3-second window.
///
/// Current behavior (BROKEN): Guard `!isCompletionPending` in BacklogRow.swift:35
/// blocks the second tap on the completion checkbox. User cannot undo completion.
///
/// Desired behavior: Completion is just another edit — tapping again undoes it,
/// and any edit resets all timers to 3 seconds.
final class CompletionToggleUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        // Wait for tasks to load
        let firstButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        _ = firstButton.waitForExistence(timeout: 5)
    }

    private func findFirstCompleteButton() -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
    }

    // MARK: - Test 1: Double-tap on checkbox UNDOES completion

    /// Verhalten: Tapping the checkbox while completion is pending should CANCEL
    /// the completion — checkbox returns to "Als erledigt markieren".
    ///
    /// Bricht wenn: BacklogRow.swift:35 guard `!isCompletionPending` blocks the second tap
    /// instead of calling onCancelCompletion.
    func test_completionUndo_doubleTapReturnsToOpen() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // First tap — mark as done
        button.tap()

        // Wait for pending state label to appear
        let pendingPredicate = NSPredicate(format: "label == 'Erledigt'")
        let pendingExpectation = XCTNSPredicateExpectation(predicate: pendingPredicate, object: app.buttons[buttonID])
        let pendingResult = XCTWaiter.wait(for: [pendingExpectation], timeout: 3)
        XCTAssertEqual(pendingResult, .completed, "After first tap, should show 'Erledigt' (pending state)")

        // Wait for button to become hittable again after animation
        let hittablePredicate = NSPredicate(format: "isHittable == true")
        let hittableExpectation = XCTNSPredicateExpectation(predicate: hittablePredicate, object: app.buttons[buttonID])
        _ = XCTWaiter.wait(for: [hittableExpectation], timeout: 2)

        // Second tap — UNDO completion
        app.buttons[buttonID].tap()

        // Wait for open state label
        let openPredicate = NSPredicate(format: "label == 'Als erledigt markieren'")
        let openExpectation = XCTNSPredicateExpectation(predicate: openPredicate, object: app.buttons[buttonID])
        let openResult = XCTWaiter.wait(for: [openExpectation], timeout: 3)
        XCTAssertEqual(openResult, .completed,
            "After second tap, should return to 'Als erledigt markieren' (undo)")
    }

    // MARK: - Test 2: Task stays visible after undo (no commit happens)

    /// Verhalten: After undoing completion via double-tap, the task must NOT disappear
    /// (the 3-second commit must have been cancelled).
    ///
    /// Bricht wenn: cancelCompletion() is never called from BacklogView, so the timer
    /// still fires and commits the completion.
    func test_completionUndo_taskStaysVisibleAfterUndo() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier

        // Complete
        button.tap()

        // Wait for pending state + hittable
        let pendingPred = NSPredicate(format: "label == 'Erledigt' AND isHittable == true")
        let pendingExp = XCTNSPredicateExpectation(predicate: pendingPred, object: app.buttons[buttonID])
        _ = XCTWaiter.wait(for: [pendingExp], timeout: 3)

        // Undo
        app.buttons[buttonID].tap()

        // Wait for open state
        let openPred = NSPredicate(format: "label == 'Als erledigt markieren'")
        let openExp = XCTNSPredicateExpectation(predicate: openPred, object: app.buttons[buttonID])
        _ = XCTWaiter.wait(for: [openExp], timeout: 3)

        // Wait past the original 3-second window
        sleep(4)

        // Task should STILL be visible (completion was cancelled)
        XCTAssertTrue(app.buttons[buttonID].exists,
            "Task must NOT disappear after undo — cancelCompletion should have stopped the timer")
    }

    // MARK: - Test 3: Re-complete after undo works

    /// Verhalten: After undoing completion, tapping a third time should start
    /// a new completion cycle.
    ///
    /// Bricht wenn: State is corrupted after cancelCompletion — e.g. onComplete
    /// callback is nil or guard still blocks.
    func test_completionReToggle_afterUndoCanCompleteAgain() throws {
        navigateToBacklog()

        let button = findFirstCompleteButton()
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("No tasks available in backlog")
        }

        let buttonID = button.identifier
        let hittablePred = NSPredicate(format: "isHittable == true")

        // Tap 1: complete
        button.tap()

        // Wait for pending state
        let erledigtPred = NSPredicate(format: "label == 'Erledigt'")
        let r1 = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: erledigtPred, object: app.buttons[buttonID])], timeout: 3)
        XCTAssertEqual(r1, .completed, "Tap 1: should show Erledigt")

        // Wait for hittable before undo tap
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittablePred, object: app.buttons[buttonID])], timeout: 2)

        // Tap 2: undo
        app.buttons[buttonID].tap()

        // Wait for open state
        let offenPred = NSPredicate(format: "label == 'Als erledigt markieren'")
        let r2 = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: offenPred, object: app.buttons[buttonID])], timeout: 3)
        XCTAssertEqual(r2, .completed, "Tap 2: should show Als erledigt markieren")

        // Wait for hittable before re-complete tap
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittablePred, object: app.buttons[buttonID])], timeout: 2)

        // Tap 3: complete again
        app.buttons[buttonID].tap()

        // Wait for pending state again
        let r3 = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: erledigtPred, object: app.buttons[buttonID])], timeout: 3)
        XCTAssertEqual(r3, .completed, "Tap 3: should show Erledigt again after re-complete")
    }
}
