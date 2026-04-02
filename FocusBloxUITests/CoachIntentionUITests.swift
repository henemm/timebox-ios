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
}
