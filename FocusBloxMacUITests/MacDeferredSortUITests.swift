//
//  MacDeferredSortUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for Deferred List Sorting on macOS.
//  Mirrors iOS DeferredSortUITests for cross-platform parity.
//

import XCTest

/// UI Tests for macOS deferred sort feature.
///
/// Tests verify:
/// 1. Pending resort border appears after importance badge tap
/// 2. Border disappears after the 3-second timeout
/// 3. Urgency cycle reaches nil (Bug 2 regression)
final class MacDeferredSortUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Find the first importance badge in the backlog list.
    private func findFirstImportanceBadge() -> XCUIElement {
        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch
    }

    /// Extract the task ID from an importance badge's accessibility identifier.
    private func extractTaskID(from badge: XCUIElement) -> String? {
        let identifier = badge.identifier
        guard identifier.hasPrefix("importanceBadge_") else { return nil }
        return String(identifier.dropFirst("importanceBadge_".count))
    }

    // MARK: - Test 1: Pending border appears after importance badge tap

    /// Verhalten: After clicking an importance badge on macOS, a visual border
    /// should appear on the row indicating it's pending re-sort.
    ///
    /// Bricht wenn: MacBacklogRow doesn't have the isPendingResort overlay
    /// with accessibilityIdentifier "pendingResortBorder_<id>".
    func test_pendingBorderAppearsAfterImportanceTap() throws {
        let badge = findFirstImportanceBadge()
        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found — need at least one task in backlog")
            return
        }

        guard let taskID = extractTaskID(from: badge) else {
            XCTFail("Could not extract task ID from badge identifier: \(badge.identifier)")
            return
        }

        // Click the importance badge
        badge.click()

        // The pending-resort border should now be visible
        let pendingBorder = app.otherElements["pendingResortBorder_\(taskID)"]
        XCTAssertTrue(
            pendingBorder.waitForExistence(timeout: 2),
            "After clicking importance badge, a pending-resort border should appear on the row. "
            + "Expected element 'pendingResortBorder_\(taskID)' to exist."
        )
    }

    // MARK: - Test 2: Border disappears after timeout

    /// Verhalten: After clicking a badge, the border should disappear after ~3 seconds
    /// (timer timeout + fade animation).
    ///
    /// Bricht wenn: scheduleDeferredResort timer doesn't clear pendingResortIDs.
    func test_borderDisappearsAfterTimeout() throws {
        let badge = findFirstImportanceBadge()
        guard badge.waitForExistence(timeout: 5) else {
            XCTFail("No importance badge found")
            return
        }

        guard let taskID = extractTaskID(from: badge) else {
            XCTFail("Could not extract task ID from badge")
            return
        }

        badge.click()

        let pendingBorder = app.otherElements["pendingResortBorder_\(taskID)"]

        XCTAssertTrue(
            pendingBorder.waitForExistence(timeout: 2),
            "Pending border should appear after badge click"
        )

        // Wait for timeout (3s timer + 0.3s fade + 0.2s pause + margin)
        let borderGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: pendingBorder
        )
        let result = XCTWaiter.wait(for: [borderGone], timeout: 6)
        XCTAssertEqual(result, .completed,
            "Pending border should disappear after the 3-second timeout"
        )
    }

    // MARK: - Test 3: Urgency cycle reaches nil (Bug 2 regression)

    /// Verhalten: Clicking urgency badge 3 times should cycle through all states:
    /// nil -> not_urgent -> urgent -> nil.
    ///
    /// Bricht wenn: urgency nil assignment doesn't persist.
    ///
    /// Note: macOS MacBacklogRow has no custom accessibilityLabel on the urgency badge,
    /// so the label defaults to the SF Symbol name:
    ///   nil = "questionmark", not_urgent = "flame", urgent = "flame.fill"
    func test_urgencyCycleReachesNil() throws {
        let firstBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        ).firstMatch

        guard firstBadge.waitForExistence(timeout: 5) else {
            XCTFail("No urgency badge found — need at least one task in backlog")
            return
        }

        // Pin to this specific badge by its full identifier
        let badgeID = firstBadge.identifier
        let badge = app.buttons[badgeID]

        // Read initial state — macOS uses SF Symbol names as labels
        let initialLabel = badge.label.lowercased()

        // Determine taps needed for full cycle back to nil (questionmark)
        // Cycle: nil("questionmark") → not_urgent("flame") → urgent("flame.fill") → nil("questionmark")
        let tapCount: Int
        if initialLabel.contains("flame") && initialLabel.contains("fill") {
            tapCount = 1  // urgent → nil
        } else if initialLabel.contains("flame") {
            tapCount = 2  // not_urgent → urgent → nil
        } else {
            tapCount = 3  // nil → not_urgent → urgent → nil
        }

        // Click quickly — each click resets the 3s deferred sort timer
        for _ in 0..<tapCount {
            badge.click()
            usleep(500_000) // 0.5s
        }

        usleep(500_000)

        // After full cycle, should be back to "questionmark" (nil state)
        let finalLabel = badge.label.lowercased()
        XCTAssertTrue(
            finalLabel.contains("question"),
            "After cycling through all urgency states, badge should show 'questionmark' (nil). "
            + "Got: '\(badge.label)'. If stuck at 'flame.fill', nil assignment is not persisted."
        )
    }
}
