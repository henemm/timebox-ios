import XCTest

/// Bug 93: Blocked tasks (indented dependents) must support swipe actions.
/// Currently blockedRow() has NO swipeActions — these tests verify the fix.
///
/// TDD RED: All tests should FAIL before implementation.
@MainActor
final class BlockedTaskSwipeUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to the Backlog tab
    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab must exist")
        backlogTab.tap()
    }

    /// Find a blocked mock task by scrolling through the backlog.
    /// Mock blocked tasks contain "Abhaengig" in their title.
    private func findBlockedTaskRow() -> XCUIElement? {
        // Blocked tasks have titles containing "Abhaengig" in mock data
        let predicate = NSPredicate(format: "label CONTAINS 'Abhaengig'")

        // Try without scrolling first
        let found = app.staticTexts.matching(predicate)
        if found.count > 0, found.element(boundBy: 0).isHittable {
            return found.element(boundBy: 0)
        }

        // Scroll down to find blocked tasks (they appear indented below their blocker)
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        for _ in 0..<5 {
            list.swipeUp()

            let scrolled = app.staticTexts.matching(predicate)
            if scrolled.count > 0, scrolled.element(boundBy: 0).isHittable {
                return scrolled.element(boundBy: 0)
            }
        }

        return nil
    }

    // MARK: - Swipe Left → Bearbeiten + Loeschen (trailing edge)

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User swipes left on the blocked task
    /// THEN: "Bearbeiten" (Edit) action button appears
    func test_blockedTask_swipeLeft_showsEditAction() throws {
        navigateToBacklog()

        guard let blockedRow = findBlockedTaskRow() else {
            throw XCTSkip("No blocked mock task found — ensure mock data includes blocked tasks")
        }

        blockedRow.swipeLeft()

        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                      "Swipe left on blocked task should reveal 'Bearbeiten' action")
    }

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User swipes left on the blocked task
    /// THEN: "Loeschen" (Delete) action button appears
    func test_blockedTask_swipeLeft_showsDeleteAction() throws {
        navigateToBacklog()

        guard let blockedRow = findBlockedTaskRow() else {
            throw XCTSkip("No blocked mock task found — ensure mock data includes blocked tasks")
        }

        blockedRow.swipeLeft()

        let deleteButton = app.buttons["Löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2),
                      "Swipe left on blocked task should reveal 'Löschen' action")
    }

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User swipes right on the blocked task
    /// THEN: "Freigeben" (Release) action button appears
    func test_blockedTask_swipeRight_showsFreigebenAction() throws {
        navigateToBacklog()

        guard let blockedRow = findBlockedTaskRow() else {
            throw XCTSkip("No blocked mock task found — ensure mock data includes blocked tasks")
        }

        blockedRow.swipeRight()

        let releaseButton = app.buttons["Freigeben"]
        XCTAssertTrue(releaseButton.waitForExistence(timeout: 2),
                      "Swipe right on blocked task should reveal 'Freigeben' action to remove dependency")
    }

    /// GIVEN: A blocked task in the backlog
    /// WHEN: User swipes right and taps "Freigeben"
    /// THEN: The task is no longer blocked (fewer lock icons visible)
    func test_blockedTask_freigeben_removesDependency() throws {
        navigateToBacklog()

        guard let blockedRow = findBlockedTaskRow() else {
            throw XCTSkip("No blocked mock task found — ensure mock data includes blocked tasks")
        }

        // Count lock buttons AFTER scrolling to blocked tasks (they're now visible)
        let lockButtonsBefore = app.buttons.matching(
            NSPredicate(format: "label == 'Blockiert'")
        ).count
        XCTAssertTrue(lockButtonsBefore > 0,
                      "Should have at least 1 blocked task visible before Freigeben")

        blockedRow.swipeRight()

        let releaseButton = app.buttons["Freigeben"]
        guard releaseButton.waitForExistence(timeout: 2) else {
            XCTFail("Freigeben button should appear after swipe right")
            return
        }
        releaseButton.tap()

        // Wait for the released task to change from "Blockiert" to "Als erledigt markieren"
        // The lock button for that task should disappear
        let expectedCount = lockButtonsBefore - 1
        let predicate = NSPredicate(format: "count == %d", expectedCount)
        let lockQuery = app.buttons.matching(NSPredicate(format: "label == 'Blockiert'"))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: lockQuery)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertTrue(result == .completed,
                      "After Freigeben, lock count should decrease from \(lockButtonsBefore) to \(expectedCount)")
    }
}
