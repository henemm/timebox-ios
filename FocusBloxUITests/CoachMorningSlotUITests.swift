import XCTest

/// UI Tests for Coach Morning — Zeitbudget-Anzeige (Bug #252 Redesign)
///
/// Die alten Slot-Karten (Task-Toggles, "Block erstellen") wurden entfernt.
/// Stattdessen zeigt der Morning View nur noch eine Zeitbudget-Anzeige.
final class CoachMorningSlotUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "--coach-tab-layout", "--open-drawer", "morning"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func navigateToCoachMorning() {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 8), "Coach view should exist")
    }

    // MARK: - Slot-Karten sind entfernt

    /// GIVEN: Coach Morning is open
    /// WHEN: User looks at morning content
    /// THEN: No slot cards exist (removed by Bug #252 redesign)
    func testSlotCardsAreRemoved() throws {
        navigateToCoachMorning()

        // Old slot section should NOT exist
        let slotsSection = app.otherElements["coachMorningSlotsSection"]
        XCTAssertFalse(slotsSection.waitForExistence(timeout: 3),
                       "Slot section should be removed — replaced by time budget")

        // Old slot task toggles should NOT exist
        let slotToggles = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'slotTaskToggle_'")
        )
        XCTAssertEqual(slotToggles.count, 0,
                       "Slot task toggles should be removed")

        // Old "Block erstellen" buttons should NOT exist
        let createButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createBlockButton_'")
        )
        XCTAssertEqual(createButtons.count, 0,
                       "Create block buttons should be removed")
    }

    // MARK: - Zeitbudget-Anzeige

    /// GIVEN: Coach Morning is open
    /// WHEN: User has free time today
    /// THEN: Time budget indicator is shown
    func testTimeBudgetIsShown() throws {
        navigateToCoachMorning()

        let timeBudget = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'coachTimeBudget'")
        ).firstMatch

        // With mock data (some events), time budget should appear
        XCTAssertTrue(timeBudget.waitForExistence(timeout: 8),
                      "Time budget indicator should be visible in morning content")
    }

    // MARK: - Task-Vorschläge bleiben

    /// GIVEN: Coach Morning is open
    /// WHEN: Tasks exist in backlog
    /// THEN: Task suggestions ("Vorschläge für heute") still appear
    func testTaskSuggestionsStillExist() throws {
        navigateToCoachMorning()

        // Task suggestions should still exist (they're independent of slots)
        let taskTitles = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        )
        // Wait for data to load
        let first = taskTitles.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 8),
                      "Task suggestions should still appear in morning content")
    }
}
