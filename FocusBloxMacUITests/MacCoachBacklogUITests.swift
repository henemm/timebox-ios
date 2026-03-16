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

    // MARK: - Test 8: Sync Status Indicator (FEATURE_005)

    /// Verhalten: Coach-Backlog zeigt Sync-Status-Indicator (wie normaler Backlog).
    /// Bricht wenn: MacCoachBacklogView keinen coachSyncStatusIndicator im HStack hat
    func test_coachModeOn_syncStatusIndicatorExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let syncStatus = app.descendants(matching: .any)["coachSyncStatusIndicator"]
        XCTAssertTrue(syncStatus.waitForExistence(timeout: 5),
                      "Sync status indicator should be visible in Coach backlog toolbar")
    }

    // MARK: - Test 9: Sync Button (FEATURE_005)

    /// Verhalten: Coach-Backlog zeigt Sync-Button zum manuellen Sync-Trigger.
    /// Bricht wenn: MacCoachBacklogView keinen coachSyncButton im HStack hat
    func test_coachModeOn_syncButtonExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let syncButton = app.buttons["coachSyncButton"]
        XCTAssertTrue(syncButton.waitForExistence(timeout: 5),
                      "Sync button should be visible in Coach backlog toolbar")
    }

    // MARK: - Test 10: Import Reminders Button (FEATURE_005)

    /// Verhalten: Coach-Backlog zeigt Import-Button wenn remindersSyncEnabled=true.
    /// Bricht wenn: MacCoachBacklogView keinen coachImportRemindersButton im HStack hat
    func test_coachModeOn_importRemindersButtonExists() throws {
        app.launchArguments = [
            "-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES",
            "-coachModeEnabled", "1",
            "-remindersSyncEnabled", "1"
        ]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
        navigateToBacklog()

        let importButton = app.buttons["coachImportRemindersButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5),
                      "Import Reminders button should be visible when remindersSyncEnabled is true")
    }

    // MARK: - Test 11: Coach-Boost Section (Bug 104: P3)

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

    // MARK: - FEATURE_012: effectiveScore/Tier/dependentCount TDD RED Tests

    /// Fixed UUID fuer den DEP-Blocker-Task (in seedUITestData gesetzt).
    /// Task: importance=2, urgency=not_urgent, dur=30, shallow_work, kein dueDate
    /// Erwarteter Score OHNE Fix: 25 (dep=0)
    /// Erwarteter Score MIT Fix:  28 (dep=1 → +3 Blocker-Bonus)
    private let depBlockerTaskID = "00000000-0000-0000-0000-000000000011"

    /// FEATURE_012 TDD RED Test 12:
    /// Verhalten: Coach-Backlog zeigt Priority-Score-Badge fuer DEP-Blocker-Task.
    /// Bricht wenn: MacCoachBacklogView.coachRow() keinen MacBacklogRow mit diesem Task rendert.
    /// RED-Grund: "[MOCK] DEP-Blocker Task" ist noch NICHT in seedUITestData vorhanden →
    ///            Badge-Element existiert nicht → XCTAssertTrue scheitert.
    @MainActor
    func test_coachBacklog_depBlockerTask_priorityScoreBadgeExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let badgeID = "priorityScoreBadge_\(depBlockerTaskID)"
        let badge = app.otherElements.matching(
            NSPredicate(format: "identifier == '\(badgeID)'")
        ).firstMatch
        let badgeAlt = app.staticTexts.matching(
            NSPredicate(format: "identifier == '\(badgeID)'")
        ).firstMatch

        let found = badge.waitForExistence(timeout: 5) ? badge : badgeAlt
        XCTAssertTrue(found.waitForExistence(timeout: 5),
                      "Priority score badge for DEP-Blocker task must exist in Coach backlog. "
                      + "RED: Task not yet in seedUITestData → badge not found.")
    }

    /// FEATURE_012 TDD RED Test 13:
    /// Verhalten: DEP-Blocker-Task im Coach-Backlog zeigt Score 28 (mit +3 DEP-Boost).
    /// Bricht wenn: MacCoachBacklogView.coachRow() kein dependentCount uebergibt → Score=25.
    /// RED-Grund 1: Task noch nicht in seedUITestData → Element existiert nicht.
    /// RED-Grund 2 (nach Seed-Daten-Fix): Score=25 (kein DEP-Boost) statt 28 → contains("28") scheitert.
    @MainActor
    func test_coachBacklog_depBlockerTask_scoreIncludesDepBoost() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let badgeID = "priorityScoreBadge_\(depBlockerTaskID)"
        let badge = app.otherElements.matching(
            NSPredicate(format: "identifier == '\(badgeID)'")
        ).firstMatch
        let badgeAlt = app.staticTexts.matching(
            NSPredicate(format: "identifier == '\(badgeID)'")
        ).firstMatch

        let found: XCUIElement
        if badge.waitForExistence(timeout: 5) {
            found = badge
        } else if badgeAlt.waitForExistence(timeout: 2) {
            found = badgeAlt
        } else {
            XCTFail("Priority score badge for DEP-Blocker task not found. "
                    + "Task must be in seedUITestData (UUID: \(depBlockerTaskID)).")
            return
        }

        // Score calculation (fresh task, no dueDate, 1 dependent):
        // eisenhower(imp=2, not_urgent) = 20
        // deadline(no dueDate) = 0
        // neglect(fresh) = 0
        // completeness(all 4 set) = 5
        // DEP boost (dependentCount=0 without fix) = 0
        // DEP boost (dependentCount=1 with fix)    = +3
        // TOTAL without fix: 25
        // TOTAL with fix:    28

        // Score calculation (fresh task, no dueDate, 1 dependent):
        // eisenhower(imp=2, not_urgent) = 20
        // deadline(no dueDate) = 0
        // neglect(fresh) = 0
        // completeness(all 4 set) = 5
        // DEP boost (dependentCount=0 without fix) = 0
        // DEP boost (dependentCount=1 with fix)    = +3
        // TOTAL without fix: 25
        // TOTAL with fix:    28
        let label = found.label
        let value = found.value as? String ?? ""
        let title = found.title
        // DEBUG: dump all accessible properties to see what macOS exposes
        let hasScore = label.contains("28") || value.contains("28") || title.contains("28")
        XCTAssertTrue(hasScore,
                      "DEP-Blocker badge should show score 28 (includes +3 DEP boost for 1 dependent). "
                      + "label='\(label)' value='\(value)' title='\(title)'. "
                      + "Without fix: score=25 (dependentCount not passed to MacBacklogRow).")
    }

}
