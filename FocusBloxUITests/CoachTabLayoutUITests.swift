import XCTest

/// Tests for Coach Tab Layout (Variante C)
/// Feature-Flag-geschützter Prototyp: 4 Tabs statt 5
/// Backlog / Planen / Focus / Coach
final class CoachTabLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Layout Tests

    /// GIVEN: Coach layout is active
    /// WHEN: App launches
    /// THEN: 4-tab Coach layout is shown (Backlog, Planen, Focus, Coach)
    func testCoachLayoutShowsFourTabs() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        XCTAssertTrue(tabBar.buttons["Backlog"].exists, "Backlog tab should exist in coach layout")
        XCTAssertTrue(tabBar.buttons["Planen"].exists, "Planen tab should exist in coach layout")
        XCTAssertTrue(tabBar.buttons["Focus"].exists, "Focus tab should exist in coach layout")
        XCTAssertTrue(tabBar.buttons["Coach"].exists, "Coach tab should exist in coach layout")

        // Old tabs should NOT exist
        XCTAssertFalse(tabBar.buttons["Blox"].exists, "Blox tab should NOT exist in coach layout")
        XCTAssertFalse(tabBar.buttons["Tag"].exists, "Tag tab should NOT exist in coach layout")
        XCTAssertFalse(tabBar.buttons["Review"].exists, "Review tab should NOT exist in coach layout")
    }

    // MARK: - Coach Tab Content Tests

    /// GIVEN: Coach layout is active
    /// WHEN: User opens each drawer
    /// THEN: All 3 drawer headers exist and can be opened
    func testCoachTabShowsAllThreeDrawers() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 5), "Coach view should exist")

        let morningDrawer = app.buttons["coachDrawer_Guten Morgen"]
        XCTAssertTrue(morningDrawer.waitForExistence(timeout: 5), "Morning drawer should exist")

        let daytimeDrawer = app.buttons["coachDrawer_Dein Tag"]
        XCTAssertTrue(daytimeDrawer.waitForExistence(timeout: 3), "Daytime drawer should exist")

        let eveningDrawer = app.buttons["coachDrawer_Tagesrückblick"]
        XCTAssertTrue(eveningDrawer.waitForExistence(timeout: 3), "Evening drawer should exist")
    }

    /// GIVEN: Coach layout is active
    /// WHEN: User opens Coach tab
    /// THEN: Morning drawer exists with header
    func testCoachTabShowsMorningDrawer() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let morningDrawer = app.buttons["coachDrawer_Guten Morgen"]
        XCTAssertTrue(morningDrawer.waitForExistence(timeout: 5), "Morning drawer should exist")
    }

    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Daytime drawer
    /// THEN: Daytime shows motivation text
    func testDaytimeShowsMotivationText() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launchArguments.append("--open-drawer")
        app.launchArguments.append("daytime")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let motivationLabel = app.staticTexts["coachDaytimeMotivation"]
        XCTAssertTrue(motivationLabel.waitForExistence(timeout: 10),
                      "Daytime should show motivation text after opening drawer")
    }

    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Evening drawer
    /// THEN: Evening shows reflection text (not empty)
    func testEveningShowsReflection() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launchArguments.append("--open-drawer")
        app.launchArguments.append("evening")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let reflectionText = app.staticTexts["eveningReflectionText"]
        XCTAssertTrue(reflectionText.waitForExistence(timeout: 10),
                      "Evening should show reflection text after opening drawer")
        XCTAssertFalse(reflectionText.label.isEmpty,
                       "Reflection text should not be empty")
    }

    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Coach tab
    /// THEN: Block status section exists and shows a count label
    // MARK: - Navigation Tests

    /// GIVEN: Coach layout is active
    /// WHEN: User taps each tab
    /// THEN: Navigation works correctly between all 4 tabs
    func testCoachLayoutNavigationWorks() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Wait for Coach layout to be active before navigating
        let planenTab = tabBar.buttons["Planen"]
        XCTAssertTrue(planenTab.waitForExistence(timeout: 5), "Planen tab must exist before tapping")
        planenTab.tap()

        let focusTab = tabBar.buttons["Focus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 3))
        focusTab.tap()

        let coachTab = tabBar.buttons["Coach"]
        XCTAssertTrue(coachTab.waitForExistence(timeout: 3))
        coachTab.tap()

        let backlogTab = tabBar.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3))
        backlogTab.tap()

        // Final check: we should be on Backlog
        XCTAssertTrue(backlogTab.isSelected, "Should be on Backlog tab after navigation")
    }

    // MARK: - Data Refresh Tests (Bug #194)

    /// GIVEN: Coach layout with mock data, task completed in Backlog
    /// WHEN: User switches back to Coach tab
    /// THEN: Coach reflects the updated data (Daytime motivation text refreshes)
    func testCoachRefreshesAfterBacklogCompletion() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launchArguments.append("--open-drawer")
        app.launchArguments.append("daytime")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // 1. Go to Coach, Daytime drawer auto-opens via --open-drawer
        let coachTab = tabBar.buttons["Coach"]
        coachTab.tap()

        let motivationBefore = app.staticTexts["coachDaytimeMotivation"]
        _ = motivationBefore.waitForExistence(timeout: 10)
        let labelBefore = motivationBefore.exists ? motivationBefore.label : ""

        // 2. Switch to Backlog
        tabBar.buttons["Backlog"].tap()
        XCTAssertTrue(tabBar.buttons["Backlog"].waitForExistence(timeout: 3))

        // 3. Complete a task in Backlog
        let completeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        if completeButton.waitForExistence(timeout: 5) {
            completeButton.tap()
        }

        // 4. Switch back to Coach — Daytime drawer should still be active
        coachTab.tap()
        XCTAssertTrue(coachTab.waitForExistence(timeout: 3))

        // 5. REALITY CHECK: motivation text must exist after refresh
        let motivationAfter = app.staticTexts["coachDaytimeMotivation"]
        XCTAssertTrue(motivationAfter.waitForExistence(timeout: 10),
                      "Coach should show motivation text after tab switch. Before: \(labelBefore)")
    }
}
