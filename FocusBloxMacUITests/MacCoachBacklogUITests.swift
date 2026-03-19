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

    // Test 5 removed by BUG_110: coachViewModeSwitcher was redundant with sidebar

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

    // Tests 8, 9, 10 removed by BUG_110: coach sync/import buttons were redundant with toolbar

    // MARK: - Test 11: Coach-Boost Section (Bug 104: P3)

    /// FEATURE_026: Coach-Boost Section wurde durch Score-Boost (+15) ersetzt
    func test_coachModeOn_withFeuerCoach_noBoostSection() throws {
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
        XCTAssertFalse(boostSection.waitForExistence(timeout: 2),
                       "Coach-Boost section should NOT exist — FEATURE_026 replaced it with score boost (+15)")
    }

    // MARK: - BUG_110: No duplicate controls in coach mode

    /// BUG_110 TDD RED Test:
    /// Verhalten: Coach-Modus zeigt KEINEN ViewMode-Switcher im Content-Bereich,
    /// weil die Sidebar bereits die Filter-Auswahl bietet.
    /// Bricht wenn: ContentView.backlogView noch den coachViewModeSwitcher HStack rendert
    func test_coachModeOn_noViewModeSwitcherInContent() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let switcher = app.descendants(matching: .any)["coachViewModeSwitcher"]
        XCTAssertFalse(switcher.waitForExistence(timeout: 3),
                       "BUG_110: ViewMode switcher should NOT exist in content area — sidebar handles this")
    }

    /// BUG_110 TDD RED Test:
    /// Verhalten: Coach-Modus zeigt KEINEN separaten Sync-Button im Content-Bereich.
    func test_coachModeOn_noSyncButtonInContent() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let syncButton = app.buttons["coachSyncButton"]
        XCTAssertFalse(syncButton.waitForExistence(timeout: 3),
                       "BUG_110: Sync button should NOT exist in content area — toolbar handles this")
    }

    /// BUG_110 TDD RED Test:
    /// Verhalten: Coach-Modus zeigt KEINEN separaten Sync-Status-Indicator im Content-Bereich.
    func test_coachModeOn_noSyncStatusInContent() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let syncStatus = app.descendants(matching: .any)["coachSyncStatusIndicator"]
        XCTAssertFalse(syncStatus.waitForExistence(timeout: 3),
                       "BUG_110: Sync status indicator should NOT exist in content area")
    }

    /// BUG_110 TDD RED Test:
    /// Verhalten: Coach-Modus zeigt KEINEN separaten Import-Button im Content-Bereich.
    func test_coachModeOn_noImportButtonInContent() throws {
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
        XCTAssertFalse(importButton.waitForExistence(timeout: 3),
                       "BUG_110: Import button should NOT exist in content area")
    }

    // MARK: - FEATURE_003: Quick-Add TextField TDD RED Tests

    /// FEATURE_003 TDD RED Test T1:
    /// Verhalten: Coach-Backlog zeigt Quick-Add TextField zum schnellen Erstellen neuer Tasks.
    /// Bricht wenn: MacCoachBacklogView.swift — TextField(...).accessibilityIdentifier("coachQuickAddTextField") entfernt wird
    /// RED-Grund: MacCoachBacklogView hat aktuell kein Quick-Add TextField → Element existiert nicht.
    func test_coachBacklog_quickAddTextField_exists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let textField = app.textFields["coachQuickAddTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Quick-Add TextField should exist in Coach backlog. "
                      + "RED: MacCoachBacklogView has no Quick-Add TextField yet.")
    }

    /// FEATURE_003 TDD RED Test T2:
    /// Verhalten: Text eingeben + Return erstellt neuen Task der in der Liste erscheint.
    /// Bricht wenn: MacCoachBacklogView.swift — onAddTask?(title) in submitCoachTask() entfernt wird
    /// RED-Grund: Kein Quick-Add implementiert → TextField existiert nicht → typeText schlaegt fehl.
    func test_coachBacklog_quickAdd_createsTask() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let textField = app.textFields["coachQuickAddTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "Quick-Add TextField must exist before we can type into it")

        textField.click()
        let taskTitle = "[TEST] QuickAdd \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        // Task should appear in the list
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(taskInList.waitForExistence(timeout: 10),
                      "Task '\(taskTitle)' should appear in Coach backlog list after Quick-Add. "
                      + "RED: No Quick-Add exists yet → task cannot be created.")
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

    // MARK: - FEATURE_004 / FEATURE_023_v2: Coach-Backlog Search Tests

    /// FEATURE_023_v2 / FEATURE_004 Test T1:
    /// Verhalten: Coach-Backlog zeigt Inline-Suchfeld (backlogSearchField) über der Task-Liste.
    /// Bricht wenn: ContentView.backlogView — .accessibilityIdentifier("backlogSearchField") fehlt
    /// RED-Grund: backlogSearchField existiert noch nicht — ContentView hat nur .searchable()
    func test_coachBacklog_searchFieldExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.textFields["backlogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Inline-Suchfeld 'backlogSearchField' muss in Coach-Backlog existieren. "
                      + "RED: ContentView.backlogView hat noch kein Inline-TextField.")
    }

    /// FEATURE_023_v2 / FEATURE_004 Test T2:
    /// Verhalten: Tippen in Inline-Suchfeld filtert Tasks nach Titel — nur Treffer sichtbar.
    /// Bricht wenn: ContentView.backlogView — .accessibilityIdentifier("backlogSearchField") fehlt
    /// RED-Grund: backlogSearchField existiert nicht → typeText schlaegt fehl.
    func test_coachBacklog_searchFiltersByTitle() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.textFields["backlogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Inline-Suchfeld muss existieren bevor getippt wird")

        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5))

        searchField.click()
        searchField.typeText("[MOCK]")

        let mockTask = app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] '[MOCK]'")
        ).firstMatch
        XCTAssertTrue(mockTask.waitForExistence(timeout: 5),
                      "Tasks mit '[MOCK]' im Titel müssen nach Suche sichtbar bleiben. "
                      + "RED: Inline-Suchfeld fehlt.")
    }

    /// FEATURE_023_v2 / FEATURE_004 Test T3:
    /// Verhalten: Suche ohne Treffer blendet alle Sections aus.
    /// Bricht wenn: ContentView.matchesSearch() — Filterlogik entfernt wird
    /// RED-Grund: backlogSearchField existiert nicht → Test scheitert beim Warten.
    func test_coachBacklog_searchNoMatch_showsNoTasks() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.textFields["backlogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Inline-Suchfeld muss existieren")

        searchField.click()
        searchField.typeText("ZZZZNONEXISTENT12345")

        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(nextUpSection.exists,
                       "NextUp-Section darf nicht sichtbar sein wenn Suche keine Treffer hat. "
                       + "RED: Inline-Suchfeld fehlt.")
    }

    /// FEATURE_023_v2 / FEATURE_004 Test T4:
    /// Verhalten: Geleerteses Suchfeld zeigt alle Tasks wieder.
    /// Bricht wenn: ContentView.searchText nicht an filteredTasks gebunden
    /// RED-Grund: backlogSearchField existiert nicht → Test scheitert beim Warten.
    func test_coachBacklog_searchClear_showsAllTasks() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.textFields["backlogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Inline-Suchfeld muss existieren")

        searchField.click()
        searchField.typeText("test")

        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey(.delete, modifierFlags: [])

        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5),
                      "Task-Liste muss nach Löschen der Suche wieder alle Tasks zeigen. "
                      + "RED: Inline-Suchfeld fehlt.")

        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        XCTAssertTrue(nextUpSection.waitForExistence(timeout: 5),
                      "NextUp-Section muss nach Löschen der Suche wieder erscheinen. "
                      + "RED: Inline-Suchfeld fehlt.")
    }

}
