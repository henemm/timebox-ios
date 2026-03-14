import XCTest

final class CoachCategoryContextMenuUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helper

    private func launchWithCoachMode() {
        app.launchArguments = [
            "-UITesting",
            "-coachModeEnabled", "1"
        ]
        app.launch()
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
    }

    private func findFirstMockTask() -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK]'")
        ).firstMatch
    }

    // MARK: - Context Menu Tests

    /// Verhalten: Long-Press auf Task zeigt Kontextmenue mit "Kategorie"-Option
    /// Bricht wenn: CoachBacklogView.swift — .contextMenu {} Modifier fehlt auf coachRow()
    func test_longPress_showsCategoryMenu() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let task = findFirstMockTask()
        XCTAssertTrue(task.waitForExistence(timeout: 5), "At least one mock task should exist")

        // Long-press to trigger context menu
        task.press(forDuration: 1.0)

        // "Kategorie" submenu should appear in context menu
        let categoryMenu = app.buttons["Kategorie"]
        XCTAssertTrue(categoryMenu.waitForExistence(timeout: 3),
                      "Context menu should contain 'Kategorie' option")
    }

    /// Verhalten: Kategorie-Submenu zeigt alle 5 TaskCategory-Optionen
    /// Bricht wenn: CoachBacklogView.swift — ForEach(TaskCategory.allCases) im contextMenu fehlt
    func test_categorySubmenu_showsAllCategories() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let task = findFirstMockTask()
        XCTAssertTrue(task.waitForExistence(timeout: 5), "At least one mock task should exist")

        // Long-press to trigger context menu
        task.press(forDuration: 1.0)

        // Tap "Kategorie" to open submenu
        let categoryMenu = app.buttons["Kategorie"]
        XCTAssertTrue(categoryMenu.waitForExistence(timeout: 3),
                      "Context menu should contain 'Kategorie' option")
        categoryMenu.tap()

        // All 5 category options should be visible
        let earn = app.buttons["Earn"]
        let essentials = app.buttons["Essentials"]
        let selfCare = app.buttons["Self Care"]
        let learn = app.buttons["Learn"]
        let social = app.buttons["Social"]

        XCTAssertTrue(earn.waitForExistence(timeout: 3), "Earn category should be in submenu")
        XCTAssertTrue(essentials.exists, "Essentials category should be in submenu")
        XCTAssertTrue(selfCare.exists, "Self Care category should be in submenu")
        XCTAssertTrue(learn.exists, "Learn category should be in submenu")
        XCTAssertTrue(social.exists, "Social category should be in submenu")
    }
}
