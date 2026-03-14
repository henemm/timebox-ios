import XCTest

/// UI Tests for Phase 5b: CoachMeinTagView
/// Tests the coach-specific "Mein Tag" view that replaces DailyReviewView when coach mode is enabled.
final class CoachMeinTagUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helper

    private func launchWithCoachMode(extraArgs: [String] = []) {
        app.launchArguments = ["-UITesting", "-coachModeEnabled", "1"] + extraArgs
        app.launch()
    }

    private func launchWithoutCoachMode() {
        app.launchArguments = ["-UITesting", "-coachModeEnabled", "0"]
        app.launch()
    }

    private func navigateToMeinTagTab() {
        let tab = app.tabBars.buttons["Mein Tag"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Mein Tag tab should exist when coach mode is ON")
        tab.tap()
    }

    private func navigateToReviewTab() {
        let tab = app.tabBars.buttons["Review"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Review tab should exist when coach mode is OFF")
        tab.tap()
    }

    // MARK: - Tests

    /// EXPECTED TO FAIL: CoachMeinTagView does not exist yet — MainTabView always shows DailyReviewView.
    /// Verhalten: Coach AN → "Mein Tag"-Tab zeigt CoachMeinTagView mit MorningIntentionView
    /// Bricht wenn: MainTabView.swift — `if coachModeEnabled { CoachMeinTagView() }` fuer Review-Tab fehlt
    func test_coachModeOn_meinTagTab_showsDayProgress() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()

        // coachDayProgress is a NEW element only in CoachMeinTagView — proves we're in the right view
        let progress = app.descendants(matching: .any)["coachDayProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5),
                      "Day progress indicator should be visible in CoachMeinTagView")
    }

    /// EXPECTED TO FAIL: CoachMeinTagView does not exist yet — "Mein Tag" still shows DailyReviewView
    /// which has a segmented picker. CoachMeinTagView should NOT have one.
    /// Verhalten: Coach AN → "Mein Tag"-Tab hat KEINEN Segmented Picker (nur Tagesansicht)
    /// Bricht wenn: MainTabView.swift — Review-Tab Weiche fehlt (DailyReviewView statt CoachMeinTagView)
    func test_coachModeOn_meinTagTab_noSegmentedPicker() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()

        // CoachMeinTagView should NOT have a segmented picker (Heute/Diese Woche)
        // Currently DailyReviewView is shown which HAS one → this test MUST fail
        let picker = app.segmentedControls.firstMatch
        XCTAssertFalse(picker.waitForExistence(timeout: 3),
                       "CoachMeinTagView should NOT have a segmented picker — only DailyReviewView has one")
    }

    /// Verhalten: Coach AN + ForceEveningReflection + Intention pre-set → EveningReflectionCard sichtbar
    /// Bricht wenn: CoachMeinTagView.swift — EveningReflectionCard conditional fehlt
    func test_coachModeOn_eveningReflection_showsCard() throws {
        // Pre-set intention via launch arg (avoids known reactive binding issue)
        launchWithCoachMode(extraArgs: ["-ForceEveningReflection", "-MockIntentionSet"])
        navigateToMeinTagTab()

        // Evening reflection card should appear in CoachMeinTagView
        let eveningCard = app.descendants(matching: .any)["eveningReflectionCard"]
        XCTAssertTrue(eveningCard.waitForExistence(timeout: 5),
                      "EveningReflectionCard should be visible in CoachMeinTagView when evening is forced")
    }
}
