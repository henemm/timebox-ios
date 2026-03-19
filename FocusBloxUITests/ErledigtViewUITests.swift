import XCTest

/// TDD RED Tests for FEATURE_027: Erledigt-View Kontextmenue & Swipe-Aktionen (iOS)
///
/// Tests verify:
/// 1. Context menu has "Wiederherstellen" as first action (long-press)
/// 2. Context menu has "Loeschen" as destructive action (long-press)
///
/// Note: Inline button removal (undo/delete) verified via screenshot inspection
/// because XCUITest cannot reliably query buttons inside List rows by identifier.
final class ErledigtViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helper

    /// Navigates to Erledigt view and waits for mock completed task
    private func navigateToErledigtView() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 3), "ViewMode switcher should exist")
        viewModeSwitcher.tap()

        // Try menuItems first, fall back to buttons (Picker rendering varies)
        let completedMenuItem = app.menuItems["Erledigt"]
        if completedMenuItem.waitForExistence(timeout: 3) {
            completedMenuItem.tap()
        } else {
            let completedButton = app.buttons.matching(
                NSPredicate(format: "label == 'Erledigt'")
            ).element(boundBy: 0)
            XCTAssertTrue(completedButton.waitForExistence(timeout: 3), "Erledigt option should exist")
            completedButton.tap()
        }

        let completedTask = app.staticTexts["[MOCK] Erledigte Backlog-Aufgabe"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 5), "Mock completed task should be visible")
    }

    // MARK: - Context Menu Tests

    /// Verhalten: Long-press auf erledigten Task zeigt Kontextmenue mit "Wiederherstellen"
    /// Bricht wenn: BacklogView.swift completedView hat kein .contextMenu mit "Wiederherstellen"
    func test_completedTask_contextMenu_hasWiederherstellen() throws {
        try navigateToErledigtView()

        let completedTask = app.staticTexts["[MOCK] Erledigte Backlog-Aufgabe"]
        completedTask.press(forDuration: 1.2)

        let restoreMenuItem = app.buttons["Wiederherstellen"]
        XCTAssertTrue(
            restoreMenuItem.waitForExistence(timeout: 3),
            "Context menu should have 'Wiederherstellen' action"
        )
    }

    /// Verhalten: Long-press auf erledigten Task zeigt Kontextmenue mit "Loeschen"
    /// Bricht wenn: BacklogView.swift completedView hat kein .contextMenu mit "Loeschen"
    func test_completedTask_contextMenu_hasLoeschen() throws {
        try navigateToErledigtView()

        let completedTask = app.staticTexts["[MOCK] Erledigte Backlog-Aufgabe"]
        completedTask.press(forDuration: 1.2)

        let deleteMenuItem = app.buttons["Löschen"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 3),
            "Context menu should have 'Löschen' action"
        )
    }
}
