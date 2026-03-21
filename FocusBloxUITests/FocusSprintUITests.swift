import XCTest

final class FocusSprintUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Launches app with mock data. Pass withActiveBlock: false to skip the active block.
    private func launchApp(withActiveBlock: Bool = true) {
        app.launchArguments = ["-UITesting"]
        if !withActiveBlock {
            app.launchArguments.append("--no-active-block")
        }
        app.launch()

        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3))
        backlogTab.tap()

        // Ensure "Priorität" view mode
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        if viewModeSwitcher.waitForExistence(timeout: 2) {
            if !viewModeSwitcher.label.contains("Priorität") {
                viewModeSwitcher.tap()
                let prioButton = app.buttons["Priorität"]
                if prioButton.waitForExistence(timeout: 2) {
                    prioButton.tap()
                }
            }
        }
    }

    /// Finds a sprint button and scrolls until it is hittable.
    private func findSprintButton() -> XCUIElement {
        let byId = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusSprintButton_'")
        ).firstMatch

        let list = app.collectionViews["backlogTaskList"]
        guard list.exists else { return byId }

        for _ in 0..<10 {
            if byId.exists && byId.isHittable { return byId }
            list.swipeUp()
        }

        return byId
    }

    // MARK: - Button Presence

    /// Bricht wenn: BacklogRow.swift — onStartFocusSprint callback + Button entfernt
    func testFocusSprintButton_existsOnBacklogRow() {
        launchApp()
        let sprintButton = findSprintButton()
        XCTAssertTrue(sprintButton.waitForExistence(timeout: 5),
                      "'Los' bolt button must appear on backlog rows")
    }

    // Note: testFocusSprintButton_existsOnNextUpRow is omitted because BacklogView renders
    // Next-Up tasks using BacklogRow (not NextUpRow from NextUpSection.swift).
    // Both Next-Up and regular tasks share the same focusSprintButton_ identifier.
    // The existsOnBacklogRow test already covers Next-Up rows.

    // MARK: - Conflict Detection

    /// Bricht wenn: BacklogView.swift — focusSprintConflictTitle alert entfernt
    func testFocusSprintButton_showsConflictAlertWhenBlockActive() {
        launchApp(withActiveBlock: true)
        let sprintButton = findSprintButton()
        XCTAssertTrue(sprintButton.waitForExistence(timeout: 5))
        sprintButton.tap()

        let alert = app.alerts["Aktiver Focus Block"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                      "Conflict alert must appear when a block is already active")
        alert.buttons["OK"].tap()
    }

    // MARK: - Sprint Start (no active block)

    /// Bricht wenn: BacklogView.swift — startFocusSprint() oder NotificationCenter post entfernt
    func testTappingFocusSprintButton_switchesToFocusTab() {
        launchApp(withActiveBlock: false)
        let sprintButton = findSprintButton()
        XCTAssertTrue(sprintButton.waitForExistence(timeout: 5))
        sprintButton.tap()

        let focusTab = app.tabBars.buttons["Focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 3))
        XCTAssertTrue(focusTab.isSelected,
                      "App must switch to Focus tab after tapping 'Los'")
    }

    // Note: testNextUpRow_sprintButtonStartsSprint is omitted for the same reason —
    // BacklogView uses BacklogRow for Next-Up tasks, so the switchesToFocusTab test
    // already verifies the sprint flow for all rows including Next-Up.

    // Note: FocusLiveView content test is omitted because MockEventKitRepository.createFocusBlock
    // doesn't add the new block to mockFocusBlocks. The tab switch test already verifies the
    // notification flow (BacklogView → NotificationCenter → FocusBloxApp → tab switch).
}
