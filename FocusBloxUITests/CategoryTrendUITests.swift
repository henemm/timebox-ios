import XCTest

/// UI Tests for Category Trend Chart (BUG_106 fix).
/// Tests that CoachMeinTagView Trend segment shows category-based chart instead of discipline-based.
/// EXPECTED TO FAIL in TDD RED: CategoryTrendChart does not exist yet.
final class CategoryTrendUITests: XCTestCase {
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

    /// Verhalten: Nach Tap auf "Trend" ist die Kategorie-Trend-Section sichtbar
    /// Bricht wenn: CategoryTrendChart oder categoryTrendSection-ID fehlt
    func test_trendView_showsCategoryTrendSection() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToTrendView()

        let section = app.descendants(matching: .any)["categoryTrendSection"]
        XCTAssertTrue(section.waitForExistence(timeout: 5),
                      "Category trend section should be visible after tapping Trend")
    }

    /// Verhalten: Trend-View zeigt "Kategorie-Trend" Header (nicht mehr "Disziplin-Trend")
    /// Bricht wenn: CategoryTrendChart den Header-Text nicht rendert
    func test_trendView_showsCategoryHeader() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToTrendView()

        let header = app.staticTexts["categoryTrendHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "Category trend header should be visible")
    }

    /// Verhalten: Alter Disziplin-Trend-Header ist NICHT mehr vorhanden
    /// Bricht wenn: DisciplineTrendChart noch in CoachMeinTagView verwendet wird
    func test_trendView_noDisciplineTrendHeader() throws {
        launchWithCoachMode()
        navigateToMeinTagTab()
        switchToTrendView()

        let oldHeader = app.staticTexts["disciplineTrendHeader"]
        // Give it a moment to appear (it shouldn't)
        XCTAssertFalse(oldHeader.waitForExistence(timeout: 2),
                       "Old discipline trend header should NOT exist anymore")
    }
}
