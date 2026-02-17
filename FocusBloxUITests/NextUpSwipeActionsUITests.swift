import XCTest

/// Tests for NextUp swipe actions (Edit + Delete)
/// Verifies that NextUp tasks support trailing swipe gestures
/// Mock data seeds 3 NextUp tasks (Mock Task 1-3)
final class NextUpSwipeActionsUITests: XCTestCase {

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

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.firstMatch.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    private func findNextUpRow() -> XCUIElement? {
        // NextUpRow has accessibilityIdentifier "nextUpRow" inside a List
        // Try multiple element types since SwiftUI may render differently
        let cells = app.cells.matching(identifier: "nextUpRow")
        if cells.count > 0 { return cells.firstMatch }

        let others = app.otherElements.matching(identifier: "nextUpRow")
        if others.count > 0 { return others.firstMatch }

        // Try finding by the known mock task title within Next Up section
        let mockTitle = app.staticTexts["Mock Task 1 #30min"]
        if mockTitle.exists { return mockTitle }

        return nil
    }

    // MARK: - Swipe Action Tests

    /// GIVEN: NextUp tasks exist (seeded by mock data)
    /// WHEN: User swipes trailing (right-to-left) on a NextUp task
    /// THEN: A "Löschen" button should appear
    func testNextUpSwipeDeleteExists() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist - mock data seeds 3 NextUp tasks")
            return
        }

        nextUpRow.swipeLeft()
        sleep(1)

        let deleteButton = app.buttons["Löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2),
                      "Trailing swipe on NextUp task should reveal 'Löschen' button")
    }

    /// GIVEN: NextUp tasks exist (seeded by mock data)
    /// WHEN: User swipes trailing (right-to-left) on a NextUp task
    /// THEN: A "Bearbeiten" button should appear
    func testNextUpSwipeEditExists() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist - mock data seeds 3 NextUp tasks")
            return
        }

        nextUpRow.swipeLeft()
        sleep(1)

        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2),
                      "Trailing swipe on NextUp task should reveal 'Bearbeiten' button")
    }

    /// GIVEN: NextUp tasks exist (seeded by mock data)
    /// WHEN: User swipes leading (left-to-right) on a NextUp task
    /// THEN: No "Next Up" action should appear (already in Next Up)
    func testNextUpNoLeadingSwipe() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist - mock data seeds 3 NextUp tasks")
            return
        }

        nextUpRow.swipeRight()
        sleep(1)

        // No "Next Up" button should appear on leading swipe
        let nextUpButton = app.buttons["Next Up"]
        XCTAssertFalse(nextUpButton.exists,
                       "Leading swipe on NextUp task should NOT show 'Next Up' button")
    }
}
