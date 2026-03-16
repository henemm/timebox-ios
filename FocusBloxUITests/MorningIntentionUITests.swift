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

    // MARK: - Coach Selection Tests

    func test_coachSelection_togglesOnTap() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let euleCard = app.buttons["coachSelectionCard_eule"]
        XCTAssertTrue(euleCard.waitForExistence(timeout: 5), "Eule coach card should exist")
        euleCard.tap()

        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3), "Set button should exist")
        XCTAssertTrue(setButton.isEnabled, "Set button should be enabled after selecting a coach")
    }

    func test_setButton_disabled_withoutSelection() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 5), "Set button should exist")
        XCTAssertFalse(setButton.isEnabled, "Set button should be disabled without selection")
    }

    // MARK: - Vertical Layout Tests (feature-coach-vertical-layout)

    /// Verhalten: Empfohlener Coach zeigt "Empfohlen"-Text als Capsule statt nur Star-Icon
    /// Bricht wenn: MorningIntentionView.coachCard — Star-Icon statt Text("Empfohlen") Capsule
    func test_recommendedCoach_showsEmpfohlenText() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let intentionCard = app.otherElements["morningIntentionCard"]
        XCTAssertTrue(intentionCard.waitForExistence(timeout: 5), "Intention card should exist")

        // The new layout should show "Empfohlen" as text capsule, not just a star icon
        let empfohlenText = app.staticTexts["Empfohlen"]
        XCTAssertTrue(empfohlenText.waitForExistence(timeout: 3),
                       "Recommended coach should show 'Empfohlen' text capsule (not just star icon)")
    }

    /// Verhalten: Coach-Karte zeigt Subtitle (z.B. "Der Aufräumer") im neuen horizontalen Layout
    /// Bricht wenn: MorningIntentionView.coachCard — nur displayName ohne subtitle
    func test_coachCard_showsSubtitle() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        let intentionCard = app.otherElements["morningIntentionCard"]
        XCTAssertTrue(intentionCard.waitForExistence(timeout: 5), "Intention card should exist")

        // The new horizontal card layout shows "DisplayName — Subtitle" as combined text
        let subtitleText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Der Aufräumer'")
        ).firstMatch
        XCTAssertTrue(subtitleText.waitForExistence(timeout: 3),
                       "Coach card should show subtitle 'Der Aufräumer' in horizontal layout")
    }

    // MARK: - Set + Edit Flow

    func test_setCoach_showsCompactView_withEditButton() {
        app.launchArguments.append("-CoachModeEnabled")
        app.launch()

        app.tabBars.firstMatch.buttons["Mein Tag"].tap()

        // Select a coach card
        let trollCard = app.buttons["coachSelectionCard_troll"]
        XCTAssertTrue(trollCard.waitForExistence(timeout: 5))
        trollCard.tap()

        // Tap "Coach wählen"
        let setButton = app.buttons["setIntentionButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 3))
        setButton.tap()

        // App auto-navigates to Backlog tab after setting coach — navigate back
        let meinTagTab = app.tabBars.firstMatch.buttons["Mein Tag"]
        XCTAssertTrue(meinTagTab.waitForExistence(timeout: 5))
        meinTagTab.tap()

        // After setting, compact view with "Ändern" button should appear
        let editButton = app.buttons["editIntentionButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5),
                       "Edit button should appear after setting coach")
    }
}
