import XCTest

/// TDD RED Tests for FEATURE_027: Erledigt-View Kontextmenue & Swipe-Aktionen (macOS)
///
/// Tests verify:
/// 1. Context menu on completed task has "Wiederherstellen"
/// 2. Context menu on completed task has "Loeschen"
/// 3. Context menu does NOT have "Als erledigt markieren" (already completed)
/// 4. Context menu does NOT have "Next Up" (irrelevant for completed tasks)
final class MacErledigtViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    /// Navigates to Erledigt sidebar filter and waits for mock completed task
    private func navigateToErledigtFilter() throws {
        let erledigtFilter = app.staticTexts["sidebarFilter_completed"]
        if !erledigtFilter.waitForExistence(timeout: 3) {
            // Fallback: look for Erledigt label in sidebar
            let erledigtLabel = app.staticTexts["Erledigt"]
            XCTAssertTrue(erledigtLabel.waitForExistence(timeout: 3), "Erledigt sidebar filter should exist")
            erledigtLabel.tap()
        } else {
            erledigtFilter.tap()
        }

        let completedTask = app.staticTexts["[MOCK] Erledigte Aufgabe"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 5), "Mock completed task should be visible")
    }

    // MARK: - Context Menu Tests

    /// Verhalten: Rechtsklick auf erledigten Task zeigt "Wiederherstellen" im Kontextmenue
    /// Bricht wenn: ContentView.swift kein completedContextMenu mit "Wiederherstellen" hat
    func test_completedTask_contextMenu_hasWiederherstellen() throws {
        try navigateToErledigtFilter()

        // Select the row first (click), then right-click for context menu
        let completedTask = app.staticTexts["[MOCK] Erledigte Aufgabe"]
        completedTask.click()
        Thread.sleep(forTimeInterval: 0.3)
        completedTask.rightClick()
        Thread.sleep(forTimeInterval: 0.5)

        let restoreMenuItem = app.menuItems["Wiederherstellen"]
        XCTAssertTrue(
            restoreMenuItem.waitForExistence(timeout: 5),
            "Context menu should have 'Wiederherstellen' action"
        )
    }

    /// Verhalten: Rechtsklick auf erledigten Task zeigt "Loeschen" im Kontextmenue
    /// Bricht wenn: ContentView.swift kein completedContextMenu mit "Loeschen" hat
    func test_completedTask_contextMenu_hasLoeschen() throws {
        try navigateToErledigtFilter()

        // Select the row first (click), then right-click for context menu
        let completedTask = app.staticTexts["[MOCK] Erledigte Aufgabe"]
        completedTask.click()
        Thread.sleep(forTimeInterval: 0.3)
        completedTask.rightClick()
        Thread.sleep(forTimeInterval: 0.5)

        let deleteMenuItem = app.menuItems["Löschen"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 5),
            "Context menu should have 'Löschen' action"
        )
    }

    /// Verhalten: Kontextmenue fuer erledigte Tasks hat NICHT "Als erledigt markieren"
    /// Bricht wenn: backlogContextMenu statt completedContextMenu verwendet wird
    func test_completedTask_contextMenu_noMarkCompleted() throws {
        try navigateToErledigtFilter()

        let completedTask = app.staticTexts["[MOCK] Erledigte Aufgabe"]
        completedTask.rightClick()

        // Wait briefly for menu to appear
        let anyMenuItem = app.menuItems.firstMatch
        _ = anyMenuItem.waitForExistence(timeout: 2)

        let markCompletedItem = app.menuItems["Als erledigt markieren"]
        XCTAssertFalse(
            markCompletedItem.exists,
            "Context menu should NOT have 'Als erledigt markieren' for already-completed tasks"
        )
    }

    /// Verhalten: Kontextmenue fuer erledigte Tasks hat NICHT "Next Up"
    /// Bricht wenn: backlogContextMenu statt completedContextMenu verwendet wird
    func test_completedTask_contextMenu_noNextUp() throws {
        try navigateToErledigtFilter()

        let completedTask = app.staticTexts["[MOCK] Erledigte Aufgabe"]
        completedTask.rightClick()

        let anyMenuItem = app.menuItems.firstMatch
        _ = anyMenuItem.waitForExistence(timeout: 2)

        let nextUpItem = app.menuItems["Zu Next Up hinzufügen"]
        XCTAssertFalse(
            nextUpItem.exists,
            "Context menu should NOT have 'Next Up' for completed tasks"
        )
    }
}
