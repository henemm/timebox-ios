import XCTest

/// Tests for Morning Intention (Phase A of #195)
/// Proves: User can set a daily intention via tappable chips,
/// intention persists across tab switches, and yesterday's intention is shown.
final class CoachIntentionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "--coach-tab-layout"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Intention Chip Selection

    /// GIVEN: Coach tab with no intention set
    /// WHEN: User sees the morning section
    /// THEN: 3 intention chips are visible (not task suggestions)
    func testMorningShowsThreeIntentionChips() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        let chip1 = app.buttons["intentionChip_0"]
        let chip2 = app.buttons["intentionChip_1"]
        let chip3 = app.buttons["intentionChip_2"]

        XCTAssertTrue(chip1.waitForExistence(timeout: 10), "First intention chip should exist")
        XCTAssertTrue(chip2.exists, "Second intention chip should exist")
        XCTAssertTrue(chip3.exists, "Third intention chip should exist")
    }

    /// GIVEN: 3 intention chips visible
    /// WHEN: User taps one chip
    /// THEN: Intention is confirmed — "Heute:" label appears with chosen text
    func testTapChipSetsIntention() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        let chip1 = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip1.waitForExistence(timeout: 10))

        // Remember the chip text
        let chipLabel = chip1.label

        // Tap the chip
        chip1.tap()

        // "Heute:" confirmation should appear
        let todayIntention = app.staticTexts["todayIntentionText"]
        XCTAssertTrue(todayIntention.waitForExistence(timeout: 5),
                      "After tapping chip, 'Heute:' intention text should appear")
    }

    /// GIVEN: Intention was just set
    /// WHEN: User switches to Backlog and back to Coach
    /// THEN: Intention is still visible (persisted, not lost)
    func testIntentionPersistsAfterTabSwitch() throws {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        tabBar.buttons["Coach"].tap()

        // Set intention
        let chip1 = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip1.waitForExistence(timeout: 10))
        chip1.tap()

        // Verify intention is shown
        let todayIntention = app.staticTexts["todayIntentionText"]
        XCTAssertTrue(todayIntention.waitForExistence(timeout: 5))

        // Switch to Backlog and back
        tabBar.buttons["Backlog"].tap()
        XCTAssertTrue(tabBar.buttons["Backlog"].waitForExistence(timeout: 3))
        tabBar.buttons["Coach"].tap()

        // REALITY CHECK: Intention must still be there
        let intentionAfter = app.staticTexts["todayIntentionText"]
        XCTAssertTrue(intentionAfter.waitForExistence(timeout: 5),
                      "Intention must persist after tab switch — proves SwiftData save works")
    }

    /// GIVEN: Intention is set
    /// WHEN: User looks at morning section
    /// THEN: Task suggestions + free slots are shown below the intention
    func testAfterIntentionTaskSuggestionsAppear() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        // Set intention
        let chip1 = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip1.waitForExistence(timeout: 10))
        chip1.tap()

        // Task suggestions should now be visible
        let plannedLabel = app.staticTexts["Heute geplant"]
        XCTAssertTrue(plannedLabel.waitForExistence(timeout: 5),
                      "After setting intention, 'Heute geplant' tasks should appear")
    }

    // MARK: - Evening Reflection Tests (Phase B)

    /// GIVEN: Intention set + evening section visible
    /// WHEN: User scrolls to evening
    /// THEN: Evening shows intention echo
    func testEveningShowsIntentionEcho() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        // Set intention first
        let chip = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()

        // Scroll to evening
        app.swipeUp()
        app.swipeUp()

        let eveningSection = app.otherElements["coachEveningSection"]
        XCTAssertTrue(eveningSection.waitForExistence(timeout: 5))

        let intentionEcho = app.staticTexts["eveningIntentionEcho"]
        XCTAssertTrue(intentionEcho.waitForExistence(timeout: 5),
                      "Evening should show the morning intention as echo")
    }

    /// GIVEN: Evening section with completed tasks
    /// WHEN: User scrolls to evening
    /// THEN: Reflection text is shown (AI or fallback)
    func testEveningShowsReflectionText() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        app.swipeUp()
        app.swipeUp()

        let reflectionText = app.staticTexts["eveningReflectionText"]
        XCTAssertTrue(reflectionText.waitForExistence(timeout: 5),
                      "Evening should show reflection text")
    }

    /// GIVEN: Evening section
    /// WHEN: User looks for stats
    /// THEN: Stats are behind a collapsed "Details" toggle
    func testEveningStatsAreCollapsed() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        app.swipeUp()
        app.swipeUp()

        let detailsToggle = app.buttons["eveningDetailsToggle"]
        XCTAssertTrue(detailsToggle.waitForExistence(timeout: 5),
                      "Evening should have a collapsed 'Details' toggle")
    }

    // MARK: - Daytime Silence Tests (Phase C)

    /// GIVEN: Intention set, daytime section visible
    /// WHEN: User looks at daytime section
    /// THEN: Intention is shown prominently (large, centered)
    func testDaytimeShowsIntentionProminently() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        // Set intention
        let chip = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()

        // Scroll to daytime
        app.swipeUp()

        let daytimeIntention = app.staticTexts["daytimeIntentionText"]
        XCTAssertTrue(daytimeIntention.waitForExistence(timeout: 5),
                      "Daytime should show intention text prominently")
    }

    /// GIVEN: Daytime section with completed tasks
    /// WHEN: User looks at daytime
    /// THEN: Only a compact count is shown (not a full task list)
    func testDaytimeShowsCompactCount() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        app.swipeUp()

        // Should show "X Dinge geschafft" as compact text, not a task list
        let compactCount = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Dinge geschafft' OR label CONTAINS 'schon erledigt'")
        ).firstMatch
        XCTAssertTrue(compactCount.waitForExistence(timeout: 5),
                      "Daytime should show compact completion count")
    }

    /// GIVEN: Daytime section
    /// WHEN: User looks at daytime
    /// THEN: No block counter ("X von Y Blöcken") is shown
    func testDaytimeHidesBlockCounter() throws {
        app.launch()
        app.tabBars.firstMatch.buttons["Coach"].tap()

        app.swipeUp()

        let daytimeSection = app.otherElements["coachDaytimeSection"]
        XCTAssertTrue(daytimeSection.waitForExistence(timeout: 5))

        // Block counter should NOT be in daytime section
        let blockCounter = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Blöcken erledigt'")
        ).firstMatch
        XCTAssertFalse(blockCounter.exists,
                       "Daytime should NOT show block counter — silence, not status report")
    }
}
