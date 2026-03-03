import XCTest

/// UI Tests for Deferred List Sorting feature.
///
/// When a user taps a badge (importance, urgency) in the Backlog list,
/// the item should NOT immediately re-sort. Instead, a visual border
/// ("pending resort") should appear, and sorting should be deferred
/// until 3 seconds after the last badge tap.
///
/// These tests verify:
/// 1. Badge tap shows a pending-resort border (feature doesn't exist yet → FAIL)
/// 2. The border disappears after the timeout (deferred sort completes)
/// 3. Multiple items can be pending simultaneously
final class DeferredSortUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    /// Navigate to the Backlog tab
    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(2) // Wait for tasks to load
    }

    /// Find the first importance badge in the backlog list.
    /// Returns the badge button element.
    private func findFirstImportanceBadge() -> XCUIElement {
        let badge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch
        return badge
    }

    /// Find a second (different) importance badge in the backlog list.
    private func findSecondImportanceBadge() -> XCUIElement? {
        let badges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        )
        guard badges.count >= 2 else { return nil }
        return badges.element(boundBy: 1)
    }

    /// Extract the task ID from an importance badge's accessibility identifier.
    /// Format: "importanceBadge_<taskID>"
    private func extractTaskID(from badge: XCUIElement) -> String? {
        let identifier = badge.identifier
        guard identifier.hasPrefix("importanceBadge_") else { return nil }
        return String(identifier.dropFirst("importanceBadge_".count))
    }

    /// Tap a badge using coordinate-based tapping.
    /// FlowLayout causes hit point {-1, -1} for direct .tap() — use coordinates instead.
    private func tapBadge(_ badge: XCUIElement) {
        badge.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // MARK: - Test 1: Pending border appears after importance badge tap

    /// EXPECTED TO FAIL (RED): The `pendingResortBorder_<id>` element does not
    /// exist because BacklogRow has no `isPendingResort` overlay yet.
    ///
    /// Verhalten: After tapping an importance badge, a visual border should
    /// appear on the row indicating it's pending re-sort.
    ///
    /// Bricht wenn: BacklogRow.swift doesn't have the `isPendingResort` overlay
    /// with accessibilityIdentifier "pendingResortBorder_<id>".
    func testPendingBorderAppearsAfterImportanceTap() throws {
        navigateToBacklog()

        let badge = findFirstImportanceBadge()
        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found — need at least one task in backlog")
            return
        }

        // Extract task ID to find the pending border element
        guard let taskID = extractTaskID(from: badge) else {
            XCTFail("Could not extract task ID from badge identifier: \(badge.identifier)")
            return
        }

        // Tap the importance badge (cycles importance value)
        tapBadge(badge)

        // The pending-resort border should now be visible on this row.
        // We look for an element with identifier "pendingResortBorder_<taskID>"
        let pendingBorder = app.otherElements["pendingResortBorder_\(taskID)"]
        XCTAssertTrue(
            pendingBorder.waitForExistence(timeout: 2),
            "After tapping importance badge, a pending-resort border should appear on the row. "
            + "Expected element 'pendingResortBorder_\(taskID)' to exist."
        )
    }

    // MARK: - Test 2: Border disappears after timeout (deferred sort completes)

    /// EXPECTED TO FAIL (RED): No pending border exists at all (feature not implemented).
    ///
    /// Verhalten: After tapping a badge, the border should disappear after ~3 seconds
    /// (timer timeout + fade animation), indicating the deferred sort has completed.
    ///
    /// Bricht wenn: BacklogView.scheduleDeferred() timer logic is missing or wrong,
    /// or if pendingResortIDs is never cleared.
    func testBorderDisappearsAfterTimeout() throws {
        navigateToBacklog()

        let badge = findFirstImportanceBadge()
        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found")
            return
        }

        guard let taskID = extractTaskID(from: badge) else {
            XCTFail("Could not extract task ID from badge")
            return
        }

        // Tap badge to trigger deferred sort
        tapBadge(badge)

        let pendingBorder = app.otherElements["pendingResortBorder_\(taskID)"]

        // Border should appear immediately
        XCTAssertTrue(
            pendingBorder.waitForExistence(timeout: 2),
            "Pending border should appear after badge tap"
        )

        // Wait for timeout (3s timer + 0.3s fade + 0.2s pause + margin)
        // After ~4 seconds total, the border should be gone
        let borderGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: pendingBorder
        )
        let result = XCTWaiter.wait(for: [borderGone], timeout: 6)
        XCTAssertEqual(result, .completed,
            "Pending border should disappear after the 3-second timeout + fade animation"
        )
    }

    // MARK: - Test 3: Multiple pending items show borders simultaneously

    /// EXPECTED TO FAIL (RED): No pending borders exist (feature not implemented).
    ///
    /// Verhalten: When tapping badges on two different tasks, both should show
    /// pending-resort borders simultaneously.
    ///
    /// Bricht wenn: BacklogView.pendingResortIDs only tracks a single item
    /// instead of using a Set<String>.
    func testMultiplePendingItemsShowBorders() throws {
        navigateToBacklog()

        let firstBadge = findFirstImportanceBadge()
        guard firstBadge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found — need at least two tasks in backlog")
            return
        }

        guard let firstTaskID = extractTaskID(from: firstBadge) else {
            XCTFail("Could not extract task ID from first badge")
            return
        }

        // Tap first badge
        tapBadge(firstBadge)
        sleep(1)

        // Find second badge (different task)
        guard let secondBadge = findSecondImportanceBadge() else {
            XCTFail("Need at least 2 tasks in backlog to test multiple pending items")
            return
        }

        guard let secondTaskID = extractTaskID(from: secondBadge) else {
            XCTFail("Could not extract task ID from second badge")
            return
        }

        // Tap second badge
        tapBadge(secondBadge)
        sleep(1)

        // Both borders should be visible simultaneously
        let firstBorder = app.otherElements["pendingResortBorder_\(firstTaskID)"]
        let secondBorder = app.otherElements["pendingResortBorder_\(secondTaskID)"]

        XCTAssertTrue(firstBorder.exists,
            "First task should still have pending border after second task's badge was tapped"
        )
        XCTAssertTrue(secondBorder.exists,
            "Second task should have pending border after its badge was tapped"
        )
    }

    // MARK: - Test 4: Timer resets on subsequent badge tap

    /// EXPECTED TO FAIL (RED): No pending borders exist (feature not implemented).
    ///
    /// Verhalten: If user taps a badge, waits 2 seconds, then taps again,
    /// the timer should reset. The border should still be visible at 4 seconds
    /// (because the second tap reset the 3-second timer).
    ///
    /// Bricht wenn: BacklogView.scheduleDeferred() doesn't cancel and relaunch
    /// the resortTimer Task on each new badge tap.
    func testTimerResetsOnSubsequentTap() throws {
        navigateToBacklog()

        let badge = findFirstImportanceBadge()
        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found")
            return
        }

        guard let taskID = extractTaskID(from: badge) else {
            XCTFail("Could not extract task ID from badge")
            return
        }

        // First tap
        tapBadge(badge)

        let pendingBorder = app.otherElements["pendingResortBorder_\(taskID)"]
        XCTAssertTrue(
            pendingBorder.waitForExistence(timeout: 2),
            "Pending border should appear after first tap"
        )

        // Wait 2 seconds (within the 3-second window)
        sleep(2)

        // Second tap — should reset the timer
        tapBadge(badge)

        // At this point: 2 seconds elapsed since first tap, 0 since second tap.
        // Wait 2 more seconds (total: 4s from first tap, 2s from second tap).
        // Border should STILL be visible because second tap reset the timer.
        sleep(2)

        XCTAssertTrue(
            pendingBorder.exists,
            "Border should still be visible 2 seconds after the SECOND tap "
            + "(timer was reset). If gone, the timer wasn't reset on the second tap."
        )
    }
}
