import XCTest

/// UI Tests for Discipline History feature (Phase 1).
/// Tests that CoachMeinTagView shows discipline profile breakdown.
/// EXPECTED TO FAIL in TDD RED: DisciplineStatsService, DisciplineBar, and
/// disciplineBreakdownSection do not exist yet.
final class DisciplineHistoryUITests: XCTestCase {
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

    private func navigateToMeinTagTab() {
        let tab = app.tabBars.buttons["Mein Tag"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Mein Tag tab should exist")
        tab.tap()
    }

    private func switchToWeekView() {
        let weekButton = app.segmentedControls.buttons["Diese Woche"]
        XCTAssertTrue(weekButton.waitForExistence(timeout: 5), "Diese Woche segment should exist")
        weekButton.tap()
    }

    // MARK: - Tests

    /// EXPECTED TO FAIL: disciplineProfileHeader element does not exist yet.
    /// Verhalten: Wochenansicht zeigt "Dein Disziplin-Profil" Header
    /// Bricht wenn: CoachMeinTagView.disciplineBreakdownSection fehlt
    func test_coachMeinTag_weekView_showsDisciplineProfileHeader() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToWeekView()

        let header = app.staticTexts["disciplineProfileHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Discipline profile header should be visible in week view")
    }

    /// EXPECTED TO FAIL: DisciplineBar elements do not exist yet.
    /// Verhalten: Alle 4 Disziplin-Balken sind sichtbar
    /// Bricht wenn: DisciplineBar View oder accessibilityIdentifier fehlt
    func test_disciplineProfile_showsFourBars() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToWeekView()

        let konsequenz = app.descendants(matching: .any)["disciplineBar_konsequenz"]
        let ausdauer = app.descendants(matching: .any)["disciplineBar_ausdauer"]
        let mut = app.descendants(matching: .any)["disciplineBar_mut"]
        let fokus = app.descendants(matching: .any)["disciplineBar_fokus"]

        XCTAssertTrue(konsequenz.waitForExistence(timeout: 5), "Konsequenz bar should exist")
        XCTAssertTrue(ausdauer.exists, "Ausdauer bar should exist")
        XCTAssertTrue(mut.exists, "Mut bar should exist")
        XCTAssertTrue(fokus.exists, "Fokus bar should exist")
    }

    /// EXPECTED TO FAIL: disciplineProfileHeader element does not exist yet.
    /// Verhalten: Discipline-Section existiert auch ohne erledigte Tasks
    /// Bricht wenn: disciplineBreakdownSection nur bei count > 0 gerendert wird
    func test_disciplineProfile_sectionAlwaysVisible() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToWeekView()

        let header = app.staticTexts["disciplineProfileHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Discipline profile section should exist even with no completed tasks")
    }
}
