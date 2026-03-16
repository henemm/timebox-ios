import XCTest

/// UI Tests for Discipline Trend feature (Phase 2 / FEATURE_023).
/// Tests that CoachMeinTagView shows a "Trend" segment with chart and highlights.
/// EXPECTED TO FAIL in TDD RED: Trend segment, DisciplineTrendChart,
/// and trend highlights do not exist yet.
final class DisciplineTrendUITests: XCTestCase {
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

    private func switchToTrendView() {
        let trendButton = app.segmentedControls.buttons["Trend"]
        XCTAssertTrue(trendButton.waitForExistence(timeout: 5), "Trend segment should exist")
        trendButton.tap()
    }

    // MARK: - Tests

    /// EXPECTED TO FAIL: "Trend" segment does not exist in ReviewMode picker yet.
    /// Verhalten: Segmented Picker zeigt "Trend" als drittes Segment
    /// Bricht wenn: ReviewMode enum kein `.trend` case hat
    func test_trendSegment_visible() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()

        let trendButton = app.segmentedControls.buttons["Trend"]
        XCTAssertTrue(trendButton.waitForExistence(timeout: 5),
                      "Segmented picker should have a 'Trend' segment")
    }

    /// EXPECTED TO FAIL: DisciplineTrendChart does not exist yet.
    /// Verhalten: Nach Tap auf "Trend" ist die Trend-Section mit Chart sichtbar
    /// Bricht wenn: DisciplineTrendChart View oder CoachMeinTagView-Integration fehlt
    func test_trendView_showsChartSection() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToTrendView()

        let section = app.descendants(matching: .any)["disciplineTrendSection"]
        XCTAssertTrue(section.waitForExistence(timeout: 5),
                      "Discipline trend section should be visible after tapping Trend segment")
    }

    /// EXPECTED TO FAIL: disciplineTrendHeader element does not exist yet.
    /// Verhalten: Trend-View zeigt "Disziplin-Trend" Header
    /// Bricht wenn: DisciplineTrendChart den Header-Text nicht rendert
    func test_trendView_showsHeader() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToTrendView()

        let header = app.staticTexts["disciplineTrendHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Discipline trend header should be visible")
    }
}
