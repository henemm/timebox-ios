import XCTest

/// UI Tests for RW_4.4 DayStatusWidget — verifies deep link navigation
/// and widget registration. Widget content itself cannot be tested via
/// XCUITest (WidgetKit limitation), but app-side behavior can.
final class DayStatusWidgetUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    // MARK: - Deep Link Navigation

    /// Verhalten: Launch argument -DayViewDeepLink navigiert zum "Tag" Tab.
    /// Simuliert den Deep Link focusblox://day-view per Launch Argument.
    /// Bricht wenn: Launch-Argument-Handler in FocusBloxApp fehlt oder
    ///   selectedTab nicht auf .day gesetzt wird.
    func test_dayViewDeepLink_navigatesToTagTab() throws {
        app.launchArguments.append("-DayViewDeepLink")
        app.launch()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5),
                       "Tag tab should exist after deep link")
        XCTAssertTrue(tagTab.isSelected,
                       "Tag tab should be selected after -DayViewDeepLink launch argument")
    }

    // MARK: - DayView Tab Exists

    /// Verhalten: Der "Tag" Tab existiert in der Tab Bar.
    /// Bricht wenn: AppTab.day oder DayView aus MainTabView entfernt wird.
    func test_tagTabExists() throws {
        app.launch()
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5),
                       "Tag tab should exist in tab bar")
    }
}
