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

    // MARK: - Test 5: ViewMode Switcher (Bug 104: P3)

    /// Verhalten: Coach-Backlog hat einen ViewMode-Switcher mit 5 Modi.
    /// Bricht wenn: MacCoachBacklogView keinen viewModeSwitcher hat
    func test_coachModeOn_viewModeSwitcherExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let switcher = app.descendants(matching: .any)["coachViewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5),
                      "ViewMode switcher should exist in macOS Coach backlog")
    }

    // MARK: - Test 6: Completion Button (Bug 104: P0)

    /// Verhalten: Completion-Checkbox existiert und ist anklickbar.
    /// Bricht wenn: onToggleComplete nicht an MacBacklogRow uebergeben wird
    func test_coachModeOn_completionCheckboxExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let completeButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        )
        XCTAssertGreaterThan(completeButtons.count, 0,
                             "At least one completion checkbox should exist in macOS Coach backlog")
    }

    // MARK: - Test 7: Task List (Bug 104)

    /// Bricht wenn: coachTaskList Identifier fehlt
    func test_coachModeOn_taskListExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5),
                      "Task list should exist in macOS Coach backlog")
    }

    // MARK: - Test 8: Coach-Boost Section (Bug 104: P3)

    /// Bricht wenn: Coach-Boost-Section nicht angezeigt wird bei gesetztem Coach
    func test_coachModeOn_withFeuerCoach_showsBoostSection() throws {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1",
            "-selectedCoach", "feuer"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
        navigateToBacklog()

        let boostSection = app.descendants(matching: .any)["coachBoostSection"]
        XCTAssertTrue(boostSection.waitForExistence(timeout: 5),
                      "Coach-Boost section should appear with Feuer coach (importance=3 tasks)")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "mac-coach-boost-section-feuer"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
