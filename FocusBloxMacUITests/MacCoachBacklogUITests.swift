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

    // MARK: - FEATURE_004: Coach-Backlog Search TDD RED Tests

    /// FEATURE_004 TDD RED Test T1:
    /// Verhalten: Coach-Backlog zeigt ein Suchfeld (.searchable).
    /// Bricht wenn: MacCoachBacklogView.swift — .searchable(text: $searchText, ...) entfernt wird
    /// RED-Grund: MacCoachBacklogView hat aktuell keinen .searchable Modifier → SearchField existiert nicht.
    func test_coachBacklog_searchFieldExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field should exist in Coach backlog. "
                      + "RED: MacCoachBacklogView has no .searchable modifier yet.")
    }

    /// FEATURE_004 TDD RED Test T2:
    /// Verhalten: Tippen in Suchfeld filtert Tasks nach Titel — nur Treffer bleiben sichtbar.
    /// Bricht wenn: MacCoachBacklogView.swift — searchFilteredItems computed property entfernt wird
    /// RED-Grund: Kein .searchable → Kein SearchField → typeText schlaegt fehl.
    func test_coachBacklog_searchFiltersByTitle() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field must exist before typing")

        // Count tasks before search
        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5))

        // Type a search term that matches only one mock task
        searchField.click()
        searchField.typeText("[MOCK]")

        // After search: tasks with "[MOCK]" in title should still be visible
        // The mock data tasks all have "[MOCK]" prefix, so they should appear
        let mockTask = app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] '[MOCK]'")
        ).firstMatch
        XCTAssertTrue(mockTask.waitForExistence(timeout: 5),
                      "Tasks matching search term '[MOCK]' should remain visible. "
                      + "RED: No search implemented yet.")
    }

    /// FEATURE_004 TDD RED Test T3:
    /// Verhalten: Suche mit nicht-existierendem Text zeigt keine Tasks (oder Empty-State).
    /// Bricht wenn: MacCoachBacklogView.swift — searchFilteredItems Filter-Logik entfernt wird
    /// RED-Grund: Kein .searchable → SearchField existiert nicht → Test scheitert.
    func test_coachBacklog_searchNoMatch_showsNoTasks() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field must exist before typing")

        searchField.click()
        searchField.typeText("ZZZZNONEXISTENT12345")

        // After typing nonsense, no tasks should match
        // NextUp section should disappear (or be empty)
        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        // Give UI time to filter
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(nextUpSection.exists,
                       "NextUp section should not exist when search has no matches. "
                       + "RED: No search filtering implemented yet.")
    }

    /// FEATURE_004 TDD RED Test T4:
    /// Verhalten: Leeres Suchfeld zeigt alle Tasks (kein Filter aktiv).
    /// Bricht wenn: MacCoachBacklogView.swift — guard !searchText.isEmpty else { return planItems } entfernt wird
    /// RED-Grund: Kein .searchable → SearchField existiert nicht.
    func test_coachBacklog_searchClear_showsAllTasks() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field must exist")

        // Type something
        searchField.click()
        searchField.typeText("test")

        // Clear search field
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey(.delete, modifierFlags: [])

        // After clearing: tasks should reappear
        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5),
                      "Task list should show all tasks after clearing search. "
                      + "RED: No search field exists yet.")

        // NextUp section should reappear (mock data has NextUp tasks)
        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        XCTAssertTrue(nextUpSection.waitForExistence(timeout: 5),
                      "NextUp section should reappear after clearing search. "
                      + "RED: No search implemented.")
    }

}
