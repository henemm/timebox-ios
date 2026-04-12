import XCTest

/// Tests for Bug #207: Kategorie-Statistiken im Coach Evening-Drawer
/// Prüft ob Tages-Stats, Wochen-Stats und Planungsgenauigkeit im Evening-Drawer sichtbar sind.
final class CoachEveningStatsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "--coach-tab-layout", "--open-drawer", "evening"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Navigiert zum Coach-Tab und öffnet den Evening-Drawer
    private func openEveningDrawer() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        // Evening-Drawer per Header-Button öffnen (falls nicht schon offen via --open-drawer)
        let eveningDrawer = app.buttons["coachDrawer_Tagesrückblick"]
        if eveningDrawer.waitForExistence(timeout: 5) {
            eveningDrawer.tap()
        }
    }

    // MARK: - Kategorie-Statistik Existenz

    /// GIVEN: Coach layout mit Evening-Drawer geöffnet
    /// WHEN: User sieht den Tagesrückblick
    /// THEN: Kategorie-Statistik-Section für heute ist sichtbar
    func testEveningDrawerShowsDailyCategoryStats() throws {
        app.launch()
        openEveningDrawer()

        // Scroll nach unten um Stats-Section zu sehen
        app.swipeUp()

        let dailyStatsSection = app.otherElements["coachDailyCategoryStats"]
        XCTAssertTrue(dailyStatsSection.waitForExistence(timeout: 5),
                      "Tages-Kategorie-Statistik sollte im Evening-Drawer sichtbar sein")
    }

    /// GIVEN: Coach layout mit Evening-Drawer geöffnet
    /// WHEN: User scrollt im Tagesrückblick
    /// THEN: Wochen-Kategorie-Statistik (letzte 7 Tage) ist sichtbar
    func testEveningDrawerShowsWeeklyCategoryStats() throws {
        app.launch()
        openEveningDrawer()

        app.swipeUp()
        app.swipeUp()

        let weeklyStatsSection = app.otherElements["coachWeeklyCategoryStats"]
        XCTAssertTrue(weeklyStatsSection.waitForExistence(timeout: 5),
                      "Wochen-Kategorie-Statistik (letzte 7 Tage) sollte im Evening-Drawer sichtbar sein")
    }

    /// GIVEN: Coach layout mit Evening-Drawer geöffnet
    /// WHEN: User scrollt im Tagesrückblick
    /// THEN: Planungsgenauigkeit-Section ist sichtbar
    func testEveningDrawerShowsPlanningAccuracy() throws {
        app.launch()
        openEveningDrawer()

        app.swipeUp()
        app.swipeUp()

        let accuracySection = app.otherElements["coachPlanningAccuracy"]
        XCTAssertTrue(accuracySection.waitForExistence(timeout: 5),
                      "Planungsgenauigkeit sollte im Evening-Drawer sichtbar sein")
    }
}
