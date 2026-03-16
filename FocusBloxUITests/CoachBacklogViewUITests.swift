import XCTest

final class CoachBacklogViewUITests: XCTestCase {
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

    private func launchWithoutCoachMode() {
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
    }

    // MARK: - View-Umschaltung

    /// Bricht wenn: MainTabView zeigt CoachBacklogView nicht bei coachModeEnabled
    func test_coachModeOn_showsMonsterHeader() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // Monster header uses accessibilityElement(children: .contain)
        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertTrue(monsterHeader.waitForExistence(timeout: 5),
                      "Monster header should be visible when Coach mode is ON")
    }

    /// Bricht wenn: MainTabView zeigt BacklogView nicht bei coachModeEnabled==false
    func test_coachModeOff_noMonsterHeader() throws {
        launchWithoutCoachMode()
        navigateToBacklog()

        let monsterHeader = app.descendants(matching: .any)["coachMonsterHeader"]
        XCTAssertFalse(monsterHeader.waitForExistence(timeout: 3),
                       "Monster header should NOT be visible when Coach mode is OFF")
    }

    /// Bricht wenn: coachTaskList nicht vorhanden (Priority-Ansicht mit Tier-Sections)
    func test_coachModeOn_showsPriorityTierSections() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // The coachTaskList wraps all tier sections in Priority mode
        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5),
                      "Priority tier sections should be visible in Coach backlog")
    }

    /// Bricht wenn: CoachBacklogView Hinweis-Text fehlt wenn keine Intention gesetzt
    func test_coachModeOn_noIntention_showsHint() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // Without an intention set, the monster header shows a hint
        let hintText = app.staticTexts["Starte deinen Tag unter Mein Tag"]
        XCTAssertTrue(hintText.waitForExistence(timeout: 5),
                      "Hint text should appear when no intention is set")
    }

    // MARK: - NextUp Section

    /// Bricht wenn: CoachBacklogView keine NextUp-Section zeigt
    func test_coachModeOn_showsNextUpSection() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let nextUpSection = app.descendants(matching: .any)["coachNextUpSection"]
        XCTAssertTrue(nextUpSection.waitForExistence(timeout: 5),
                      "NextUp section should be visible in Coach backlog when NextUp tasks exist")
    }

    /// Bricht wenn: NextUp-Section keinen "Next Up" Header-Text hat
    func test_coachModeOn_nextUpSection_showsHeader() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        XCTAssertTrue(nextUpHeader.waitForExistence(timeout: 5),
                      "NextUp section header should show 'Next Up' text")
    }

    // MARK: - ViewMode Switcher (Bug 104: P2b)

    /// Bricht wenn: CoachBacklogView toolbar keinen ViewMode-Switcher hat
    func test_coachModeOn_viewModeSwitcherExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let switcher = app.descendants(matching: .any)["coachViewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5),
                      "ViewMode switcher should exist in Coach backlog toolbar")
    }

    /// Bricht wenn: Default-ViewMode nicht "Priorität" ist
    func test_coachModeOn_defaultModePrioritaet() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let prioritaetText = app.staticTexts["Priorität"]
        XCTAssertTrue(prioritaetText.waitForExistence(timeout: 5),
                      "Default ViewMode should show 'Priorität' text")
    }

    // MARK: - Coach-Boost Section (Bug 104: P2b)

    /// Bricht wenn: Coach-Boost-Section nicht angezeigt wird bei gesetztem Coach
    func test_coachModeOn_withFeuerCoach_showsBoostSection() throws {
        app.launchArguments = [
            "-UITesting",
            "-coachModeEnabled", "1",
            "-selectedCoach", "feuer"
        ]
        app.launch()
        navigateToBacklog()

        let boostSection = app.descendants(matching: .any)["coachBoostSection"]
        XCTAssertTrue(boostSection.waitForExistence(timeout: 5),
                      "Coach-Boost section should appear with Feuer coach (importance=3 tasks in mock data)")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "coach-boost-section-feuer"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Completion (Bug 104: P2a)

    /// Bricht wenn: coachRow() kein onComplete-Callback an BacklogRow uebergibt
    func test_coachModeOn_completionButtonExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let completeButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        )
        XCTAssertGreaterThan(completeButtons.count, 0,
                             "At least one completion button should exist in Coach backlog")
    }

    /// Bricht wenn: addTaskButton fehlt in Coach-Backlog toolbar
    func test_coachModeOn_addTaskButtonExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Add task button should exist in Coach backlog toolbar")
    }

    // MARK: - Task List (Bug 104)

    /// Bricht wenn: coachTaskList nicht als accessibilityIdentifier gesetzt
    func test_coachModeOn_taskListExists() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let taskList = app.descendants(matching: .any)["coachTaskList"]
        XCTAssertTrue(taskList.waitForExistence(timeout: 5),
                      "Task list should exist in Coach backlog")
    }

    // MARK: - Trailing Swipe (Bug 104: P2a)

    /// Bricht wenn: coachRow() kein .swipeActions(edge: .trailing) hat
    func test_coachModeOn_swipeLeft_showsDeleteAction() throws {
        launchWithCoachMode()
        navigateToBacklog()

        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK]'")
        ).firstMatch
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Mock task should exist")
        taskTitle.swipeLeft()

        let deleteButton = app.buttons["Löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3),
                      "Trailing swipe should show 'Löschen' button in Coach backlog")
    }

    // MARK: - Swipe Actions

    /// Bricht wenn: coachRow() hat kein .swipeActions(edge: .leading) mit Next-Up-Toggle
    func test_coachModeOn_swipeRight_showsNextUpAction() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // Find a task in the NextUp section (mock tasks 1-3 are isNextUp=true)
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] Task 1'")
        ).firstMatch
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "Mock task should exist")

        // Swipe right to reveal leading swipe action
        taskTitle.swipeRight()

        // Task is already NextUp, so button shows "Entfernen"
        let removeButton = app.buttons["Entfernen"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 3),
                      "NextUp swipe action (Entfernen) should exist in Coach backlog")
    }

    // MARK: - Discipline Override Context Menu

    /// Bricht wenn: coachRow() hat kein .contextMenu mit Disziplin-Optionen
    func test_coachModeOn_longPress_showsDisciplineMenu() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // Find a task row
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK]'")
        ).firstMatch
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "At least one mock task should exist")

        // Long-press to show context menu
        taskTitle.press(forDuration: 1.5)

        // Context menu should show all 4 discipline options
        let konsequenzButton = app.buttons["Konsequenz"]
        XCTAssertTrue(konsequenzButton.waitForExistence(timeout: 3),
                      "Context menu should show 'Konsequenz' discipline option")

        let mutButton = app.buttons["Mut"]
        XCTAssertTrue(mutButton.exists, "Context menu should show 'Mut' discipline option")

        let fokusButton = app.buttons["Fokus"]
        XCTAssertTrue(fokusButton.exists, "Context menu should show 'Fokus' discipline option")

        let ausdauerButton = app.buttons["Ausdauer"]
        XCTAssertTrue(ausdauerButton.exists, "Context menu should show 'Ausdauer' discipline option")

        // Capture screenshot with context menu visible for verification
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "discipline-context-menu"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
