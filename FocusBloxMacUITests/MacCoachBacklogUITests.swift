//
//  MacCoachBacklogUITests.swift
//  FocusBloxMacUITests
//
//  TDD RED: Tests for Coach Backlog view in macOS.
//  These tests MUST FAIL until MacCoachBacklogView is implemented.
//

import XCTest

final class MacCoachBacklogUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func launchWithCoachMode() {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    private func launchWithoutCoachMode() {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    private func navigateToBacklog() {
        // macOS uses segmented picker for navigation; Backlog is default but ensure it
        let picker = app.segmentedControls["mainNavigationPicker"]
        if picker.waitForExistence(timeout: 3) {
            let backlogButton = picker.buttons["Backlog"]
            if backlogButton.exists {
                backlogButton.tap()
            }
        }
    }

    // MARK: - Test 1: Coach mode ON shows monster header

    /// Verhalten: Bei coachModeEnabled zeigt macOS Backlog einen Monster-Header.
    /// Bricht wenn: ContentView.mainContentView keine Weiche fuer coachModeEnabled hat
    /// und weiterhin die normale backlogView zeigt.
    func test_coachModeOn_showsMonsterHeader() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertTrue(monsterHeader.waitForExistence(timeout: 5),
                      "Monster header should be visible when Coach mode is ON in macOS")
    }

    // MARK: - Test 2: Coach mode OFF hides monster header

    /// Verhalten: Ohne coachModeEnabled zeigt macOS die normale Backlog-View.
    /// Bricht wenn: MacCoachBacklogView immer angezeigt wird statt nur bei coachModeEnabled.
    func test_coachModeOff_noMonsterHeader() throws {
        launchWithoutCoachMode()
        navigateToBacklog()

        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertFalse(monsterHeader.waitForExistence(timeout: 3),
                       "Monster header should NOT be visible when Coach mode is OFF")
    }

    // MARK: - Test 3: No intention set shows hint text

    /// Verhalten: Ohne gesetzte Intention zeigt der Monster-Header einen Hinweis-Text.
    /// Bricht wenn: MacCoachBacklogView keinen Fallback-Text bei fehlender Intention hat.
    func test_coachModeOn_noIntention_showsHint() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let hintText = app.staticTexts["Starte deinen Tag unter Mein Tag"]
        XCTAssertTrue(hintText.waitForExistence(timeout: 5),
                      "Hint text should appear when no intention is set")
    }

    // MARK: - Test 4: Sidebar simplified in coach mode

    /// Verhalten: Bei Coach-Modus zeigt die Sidebar nur "Backlog" ohne Filter-Optionen.
    /// Bricht wenn: SidebarView nicht auf coachModeEnabled reagiert und weiterhin
    /// alle Filter (Prioritaet, Zuletzt, Ueberfaellig, etc.) anzeigt.
    func test_coachModeOn_sidebarSimplified() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // The filter labels should NOT exist in coach mode
        let priorityFilter = app.staticTexts["Priorität"]
        let recentFilter = app.staticTexts["Zuletzt"]

        // Give UI time to settle
        _ = app.windows.firstMatch.waitForExistence(timeout: 3)

        XCTAssertFalse(priorityFilter.exists,
                       "Priority filter should be hidden in Coach mode sidebar")
        XCTAssertFalse(recentFilter.exists,
                       "Recent filter should be hidden in Coach mode sidebar")
    }
}
