import XCTest

final class MorningIntentionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
    }

    // MARK: - Tab Name Tests

    func test_tabName_showsMeinTag_whenCoachEnabled() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Mein Tag"].waitForExistence(timeout: 5),
                       "Tab should show 'Mein Tag' when Coach mode is enabled")
    }

    func test_tabName_showsReview_whenCoachDisabled() {
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Review"].waitForExistence(timeout: 5),
                       "Tab should show 'Review' when Coach mode is disabled")
    }

    // MARK: - Intention Card Tests

    func test_intentionCard_visible_whenCoachEnabled() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let intentionCard = app.otherElements["morningIntentionCard"]
        XCTAssertTrue(intentionCard.waitForExistence(timeout: 5),
                       "Morning Intention card should be visible when Coach mode is enabled")
    }

    // MARK: - Chip Selection Tests

    func test_chipSelection_togglesOnTap() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let fokusChip = app.buttons["intentionChip_fokus"]
        XCTAssertTrue(fokusChip.waitForExistence(timeout: 5), "Fokus chip should exist")
        fokusChip.tap()

        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3), "Set button should exist")
        XCTAssertTrue(setButton.isEnabled, "Set button should be enabled after selecting a chip")
    }

    func test_setButton_disabled_withoutSelection() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 5), "Set button should exist")
        XCTAssertFalse(setButton.isEnabled, "Set button should be disabled without selection")
    }

    // MARK: - Set + Edit Flow

    func test_setIntention_showsCompactView_withEditButton() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        // Select a chip
        let survivalChip = app.buttons["intentionChip_survival"]
        XCTAssertTrue(survivalChip.waitForExistence(timeout: 5))
        survivalChip.tap()

        // Tap "Intention setzen"
        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3))
        setButton.tap()

        // After setting, "Aendern" button should appear
        let editButton = app.buttons["editIntentionButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3),
                       "Edit button should appear after setting intention")
    }
}
