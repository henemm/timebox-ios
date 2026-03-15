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

    /// Bricht wenn: CoachBacklogView keine "Weitere Tasks" Sektion zeigt
    /// When no intention is set, all tasks appear in the "other" section.
    func test_coachModeOn_showsOtherSection() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // The coachOtherSection is always present (all tasks when no intention set)
        let otherSection = app.descendants(matching: .any)["coachOtherSection"]
        XCTAssertTrue(otherSection.waitForExistence(timeout: 5),
                      "Other tasks section should be visible in Coach backlog")
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

    // MARK: - Swipe Actions

    /// Bricht wenn: coachRow() hat kein .swipeActions(edge: .leading) mit Next-Up-Button
    func test_coachModeOn_swipeRight_showsNextUpAction() throws {
        launchWithCoachMode()
        navigateToBacklog()

        // Find a task by its title text (mock data contains [MOCK] prefix)
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK]'")
        ).firstMatch
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 5), "At least one mock task should exist")

        // Swipe right to reveal leading swipe action
        taskTitle.swipeRight()

        // The "Next Up" button should appear
        let nextUpButton = app.buttons["Next Up"]
        XCTAssertTrue(nextUpButton.waitForExistence(timeout: 3),
                      "Next Up swipe action should exist in Coach backlog")
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
