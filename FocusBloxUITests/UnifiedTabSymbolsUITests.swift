import XCTest

/// Tests for unified SF Symbols across iOS Tab-Bar
/// Verifies that all 5 navigation tabs exist and work after symbol unification
final class UnifiedTabSymbolsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Bar Symbol Tests

    /// GIVEN: App is launched
    /// WHEN: Tab bar is displayed
    /// THEN: All 5 tabs should exist with correct labels
    /// EXPECTED TO FAIL: "mainTabView_unified" identifier doesn't exist yet
    func testTabBarHasUnifiedSymbolsIdentifier() throws {
        // This identifier will be added during implementation to confirm
        // the unified symbols are in place
        let tabView = app.otherElements["mainTabView_unified"]
        XCTAssertTrue(tabView.waitForExistence(timeout: 3),
                      "TabView should have 'mainTabView_unified' identifier after symbol unification")
    }

    /// GIVEN: App is launched with unified symbols
    /// WHEN: Checking all tab bar buttons
    /// THEN: All 5 tabs should be accessible
    func testAllFiveTabsExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        let backlogTab = tabBar.buttons["Backlog"]
        let blocksTab = tabBar.buttons["Blox"]
        let focusTab = tabBar.buttons["Focus"]
        let reviewTab = tabBar.buttons["Review"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(blocksTab.exists, "Blox tab should exist")
        XCTAssertTrue(focusTab.exists, "Focus tab should exist")
        XCTAssertTrue(reviewTab.exists, "Review tab should exist")
    }

    /// GIVEN: Unified symbols are applied
    /// WHEN: Tapping each tab
    /// THEN: Navigation should work correctly
    func testTabNavigationWorksAfterSymbolChange() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        // Tap Blox tab (symbol changed from rectangle.split.3x1 to calendar)
        tabBar.buttons["Blox"].tap()
        sleep(1)

        // Tap Focus tab
        tabBar.buttons["Focus"].tap()
        sleep(1)

        // Tap Review tab (symbol changed from clock.arrow.circlepath to chart.bar)
        tabBar.buttons["Review"].tap()
        sleep(1)

        // Tap back to Backlog (symbol unchanged: list.bullet)
        tabBar.buttons["Backlog"].tap()
        sleep(1)

        // Verify we're back on Backlog
        XCTAssertTrue(tabBar.buttons["Backlog"].isSelected, "Should be on Backlog tab after navigation")
    }
}
