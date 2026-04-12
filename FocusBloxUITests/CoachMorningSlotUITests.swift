import XCTest

/// UI Tests for Feature #206: Coach Morning — Freie Luecken mit Call-to-Action
///
/// WICHTIG: Freie Slots haengen von echten Kalender-Events ab (EventKit).
/// In der UI-Test-Umgebung ohne Kalender-Zugriff gibt es keine Slots.
/// Tests mit Slot-Interaktion nutzen daher guard + XCTSkip.
/// Die Business-Logik (candidatesPerSlot, Duration-Filter) ist durch Unit Tests abgedeckt.
final class CoachMorningSlotUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "--coach-tab-layout"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func openMorningDrawer() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let morningDrawer = app.buttons["coachDrawer_Guten Morgen"]
        XCTAssertTrue(morningDrawer.waitForExistence(timeout: 5),
                      "Morning drawer must exist")
        morningDrawer.tap()
    }

    // MARK: - Coach Morning Structure (always testable)

    /// GIVEN: Coach layout active
    /// WHEN: User opens Coach tab
    /// THEN: Morning drawer button exists and is tappable
    func testMorningDrawerExists() throws {
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let morningDrawer = app.buttons["coachDrawer_Guten Morgen"]
        XCTAssertTrue(morningDrawer.waitForExistence(timeout: 5),
                      "Morning drawer button must exist on Coach tab")
    }

    // MARK: - Slot Section (requires calendar access)

    /// GIVEN: Coach Morning with free time slots (requires calendar)
    /// WHEN: User opens morning drawer
    /// THEN: Free slots section is visible with task toggles
    func testSlotSectionShowsTaskToggles() throws {
        app.launch()
        openMorningDrawer()

        let slotsSection = app.otherElements["coachMorningSlotsSection"]
        guard slotsSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("No free slots available — requires calendar with gaps")
        }

        let slotTasks = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'slotTaskToggle_'")
        )
        XCTAssertTrue(slotTasks.firstMatch.waitForExistence(timeout: 3),
                      "Task toggles must exist under a visible slot")
        XCTAssertGreaterThan(slotTasks.count, 0,
                             "At least one task suggestion must appear")
        XCTAssertLessThanOrEqual(slotTasks.count, 9,
                                 "Max 3 tasks per slot, max 3 slots = 9 toggles max")
    }

    /// GIVEN: Free slot with tasks, user selects a task
    /// WHEN: User taps toggle
    /// THEN: "Block erstellen" button appears
    func testSelectTaskShowsCreateBlockButton() throws {
        app.launch()
        openMorningDrawer()

        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'slotTaskToggle_'")
        ).firstMatch

        guard firstToggle.waitForExistence(timeout: 5) else {
            throw XCTSkip("No free slots available — requires calendar with gaps")
        }

        firstToggle.tap()

        let createButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createBlockButton_'")
        ).firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3),
                      "Create block button must appear after selecting a task")
    }

    /// GIVEN: Free slot, user selects task and creates block
    /// WHEN: User taps "Block erstellen"
    /// THEN: Slot disappears from the list
    func testCreateBlockRemovesSlot() throws {
        app.launch()
        openMorningDrawer()

        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'slotTaskToggle_'")
        ).firstMatch

        guard firstToggle.waitForExistence(timeout: 5) else {
            throw XCTSkip("No free slots available — requires calendar with gaps")
        }

        firstToggle.tap()

        let createButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createBlockButton_'")
        ).firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()

        XCTAssertFalse(createButton.waitForExistence(timeout: 3),
                       "Create block button must disappear after block creation")
    }
}
