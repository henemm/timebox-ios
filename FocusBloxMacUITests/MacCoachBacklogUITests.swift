//
//  MacCoachBacklogUITests.swift
//  FocusBloxMacUITests
//
//  Tests for Coach Backlog view in macOS.
//  Verified IDs from production code (2026-03-14):
//  - coachMonsterHeader (MonsterIntentionHeader)
//  - coachRelevantSection, coachOtherSection, coachTaskList (CoachBacklogView)
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
        let picker = app.radioGroups["mainNavigationPicker"]
        if picker.waitForExistence(timeout: 3) {
            let backlogButton = picker.radioButtons["list.bullet"]
            if backlogButton.exists {
                backlogButton.tap()
            }
        }
    }

    // MARK: - Test 1: Coach mode ON shows monster header

    /// Verhalten: Bei coachModeEnabled zeigt macOS Backlog einen Monster-Header.
    /// Bricht wenn: ContentView.mainContentView keine Weiche fuer coachModeEnabled hat
    func test_coachModeOn_showsMonsterHeader() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertTrue(monsterHeader.waitForExistence(timeout: 5),
                      "Monster header should be visible when Coach mode is ON in macOS")
    }

    // MARK: - Test 2: Coach mode OFF hides monster header

    /// Verhalten: Ohne coachModeEnabled zeigt macOS die normale Backlog-View.
    func test_coachModeOff_noMonsterHeader() throws {
        launchWithoutCoachMode()
        navigateToBacklog()

        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertFalse(monsterHeader.waitForExistence(timeout: 3),
                       "Monster header should NOT be visible when Coach mode is OFF")
    }

    // MARK: - Test 3: No coach set shows hint text

    /// Verhalten: Ohne gewaehlten Coach zeigt der Monster-Header einen Hinweis-Text.
    func test_coachModeOn_noCoach_showsHint() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let hintText = app.staticTexts["Starte deinen Tag unter Mein Tag"]
        XCTAssertTrue(hintText.waitForExistence(timeout: 5),
                      "Hint text should appear when no coach is set")
    }

    // MARK: - Test 4: NextUp section visible in coach mode

    /// Verhalten: Bei coachModeEnabled zeigt macOS Coach-Backlog eine NextUp-Section.
    /// Bricht wenn: MacCoachBacklogView keine coachNextUpSection hat
    func test_coachModeOn_showsNextUpSection() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        XCTAssertTrue(nextUpSection.waitForExistence(timeout: 5),
                      "NextUp section should be visible in macOS Coach backlog")
    }

    // MARK: - Test 5: Sidebar simplified in coach mode

    /// Verhalten: Bei Coach-Modus zeigt die Sidebar nur "Backlog" ohne Filter-Optionen.
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
