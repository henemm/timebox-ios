import XCTest

/// Tests for NextUp Long Press Preview
/// Verifies that long-pressing a NextUpRow shows a context menu with preview
/// Mock data seeds 3 NextUp tasks (Mock Task 1-3 with importance/urgency set)
///
/// EXPECTED TO FAIL (TDD RED): .contextMenu not yet added to NextUpRow
final class NextUpLongPressUITests: XCTestCase {

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
        let cells = app.cells.matching(identifier: "nextUpRow")
        if cells.count > 0 { return cells.firstMatch }

        let others = app.otherElements.matching(identifier: "nextUpRow")
        if others.count > 0 { return others.firstMatch }

        // Fallback: find by known mock task title
        let mockTitle = app.staticTexts["Mock Task 1 #30min"]
        if mockTitle.exists { return mockTitle }

        return nil
    }

    // MARK: - Long Press Context Menu Tests

    /// GIVEN: NextUp tasks exist (seeded by mock data)
    /// WHEN: User long-presses a NextUpRow
    /// THEN: Context menu with "Bearbeiten" action appears
    /// Bricht wenn: NextUpSection.swift NextUpRow hat kein .contextMenu modifier
    func testLongPressShowsEditAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist - mock data seeds 3 NextUp tasks")
            return
        }

        // Long press to trigger context menu
        nextUpRow.press(forDuration: 1.5)
        sleep(1)

        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3),
                      "Long press on NextUpRow should show 'Bearbeiten' context menu action")
    }

    /// GIVEN: NextUp tasks exist
    /// WHEN: User long-presses a NextUpRow
    /// THEN: Context menu with "Aus Next Up entfernen" action appears
    /// Bricht wenn: NextUpSection.swift NextUpRow hat kein .contextMenu modifier
    func testLongPressShowsRemoveAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist")
            return
        }

        nextUpRow.press(forDuration: 1.5)
        sleep(1)

        let removeButton = app.buttons["Aus Next Up entfernen"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 3),
                      "Long press should show 'Aus Next Up entfernen' action")
    }

    /// GIVEN: NextUp tasks exist
    /// WHEN: User long-presses a NextUpRow
    /// THEN: Context menu with "Löschen" action appears
    /// Bricht wenn: NextUpSection.swift NextUpRow hat kein .contextMenu modifier
    func testLongPressShowsDeleteAction() throws {
        navigateToBacklog()
        sleep(2)

        guard let nextUpRow = findNextUpRow() else {
            XCTFail("nextUpRow should exist")
            return
        }

        nextUpRow.press(forDuration: 1.5)
        sleep(1)

        let deleteButton = app.buttons["Löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3),
                      "Long press should show 'Löschen' context menu action")
    }
}
