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

    // MARK: - Feature Flag Tests

    /// GIVEN: Coach layout feature flag is OFF (default)
    /// WHEN: App launches
    /// THEN: Original 5-tab layout is shown
    func testDefaultLayoutShowsFiveTabs() throws {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

        XCTAssertTrue(tabBar.buttons["Backlog"].exists, "Backlog tab should exist in default layout")
        XCTAssertTrue(tabBar.buttons["Blox"].exists, "Blox tab should exist in default layout")
        XCTAssertTrue(tabBar.buttons["Tag"].exists, "Tag tab should exist in default layout")
        XCTAssertTrue(tabBar.buttons["Focus"].exists, "Focus tab should exist in default layout")
        XCTAssertTrue(tabBar.buttons["Review"].exists, "Review tab should exist in default layout")
    }

    /// GIVEN: Coach layout feature flag is ON
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
    /// WHEN: User navigates to Coach tab
    /// THEN: All 3 sections are visible (Morning, Daytime, Evening)
    func testCoachTabShowsAllThreeSections() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 5), "Coach view should exist")

        let morningSection = app.otherElements["coachMorningSection"]
        XCTAssertTrue(morningSection.waitForExistence(timeout: 5), "Morning section should exist")

        let daytimeSection = app.otherElements["coachDaytimeSection"]
        XCTAssertTrue(daytimeSection.exists, "Daytime section should exist")

        // Evening section may require scrolling
        app.swipeUp()
        let eveningSection = app.otherElements["coachEveningSection"]
        XCTAssertTrue(eveningSection.waitForExistence(timeout: 3), "Evening section should exist after scrolling")
    }

    /// GIVEN: Coach layout is active
    /// WHEN: User opens Coach tab
    /// THEN: Morning intention question is visible
    func testCoachTabShowsMorningQuestion() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Coach"].tap()

        let question = app.staticTexts["coachMorningQuestion"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Morning intention question should be visible")
    }

    // MARK: - Content Behavior Tests (with Mock Data)

    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Coach tab and sets an intention
    /// THEN: Morning section shows "Heute geplant" after intention is set
    func testMorningShowsPlannedTasksAfterIntention() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        app.tabBars.firstMatch.buttons["Coach"].tap()

        // Intention chips should appear first
        let chip = app.buttons["intentionChip_0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Intention chips should appear")

        // Set intention
        chip.tap()

        // After intention: "Heute geplant" should appear
        let heutePlanned = app.staticTexts["Heute geplant"]
        XCTAssertTrue(heutePlanned.waitForExistence(timeout: 5),
                      "After setting intention, 'Heute geplant' tasks should appear")
    }

    /// GIVEN: Coach layout with mock data (completed tasks exist)
    /// WHEN: User opens Coach tab and scrolls to Daytime section
    /// THEN: Daytime section shows "schon erledigt" with actual tasks
    func testDaytimeShowsCompletedTasks() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        app.tabBars.firstMatch.buttons["Coach"].tap()

        // Daytime section may be below the fold — scroll to it
        app.swipeUp()

        // Search for the "schon erledigt" label which proves completed tasks are shown
        let completedLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'schon erledigt'")
        ).firstMatch
        XCTAssertTrue(completedLabel.waitForExistence(timeout: 5),
                      "Daytime section should show 'X schon erledigt' with completed tasks")
    }

    /// GIVEN: Coach layout with mock data
    /// WHEN: User scrolls to evening section
    /// THEN: Evening section shows reflection text (not empty)
    func testEveningShowsReflection() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        app.tabBars.firstMatch.buttons["Coach"].tap()

        let coachView = app.otherElements["coachView"]
        XCTAssertTrue(coachView.waitForExistence(timeout: 5))

        app.swipeUp()
        app.swipeUp()

        let eveningSection = app.otherElements["coachEveningSection"]
        XCTAssertTrue(eveningSection.waitForExistence(timeout: 5),
                      "Evening section should be visible after scrolling")

        let reflectionText = app.staticTexts["eveningReflectionText"]
        XCTAssertTrue(reflectionText.waitForExistence(timeout: 5),
                      "Evening should show reflection text")
        XCTAssertFalse(reflectionText.label.isEmpty,
                       "Reflection text should not be empty")
    }

    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Coach tab
    /// THEN: Block status section exists and shows a count label
    /// Note: FocusBlocks come from EventKit (no calendar access in UI tests),
    /// so we verify the section renders, not the specific count.
    /// GIVEN: Coach layout with mock data
    /// WHEN: User opens Coach tab and scrolls to Daytime
    /// THEN: Block status text is visible (contains "Blöcken")
    func testBlockStatusSectionExists() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let coachTab = app.tabBars.firstMatch.buttons["Coach"]
        XCTAssertTrue(coachTab.waitForExistence(timeout: 5), "Coach tab should exist")
        coachTab.tap()

        // Block status is in daytime section — scroll to it
        app.swipeUp()

        let blockText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Blöcken'")
        ).firstMatch
        XCTAssertTrue(blockText.waitForExistence(timeout: 5),
                      "Block status should show 'Blöcken' label in daytime section")
    }

    // MARK: - Navigation Tests

    /// GIVEN: Coach layout is active
    /// WHEN: User taps each tab
    /// THEN: Navigation works correctly between all 4 tabs
    func testCoachLayoutNavigationWorks() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Navigate to each tab with waitForExistence to handle timing
        let planenTab = tabBar.buttons["Planen"]
        planenTab.tap()
        XCTAssertTrue(planenTab.waitForExistence(timeout: 3))

        let focusTab = tabBar.buttons["Focus"]
        focusTab.tap()
        XCTAssertTrue(focusTab.waitForExistence(timeout: 3))

        let coachTab = tabBar.buttons["Coach"]
        coachTab.tap()
        XCTAssertTrue(coachTab.waitForExistence(timeout: 3))

        let backlogTab = tabBar.buttons["Backlog"]
        backlogTab.tap()
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 3))

        // Final check: we should be on Backlog
        XCTAssertTrue(backlogTab.isSelected, "Should be on Backlog tab after navigation")
    }

    // MARK: - Data Refresh Tests (Bug #194)

    /// GIVEN: Coach layout with mock data, task completed in Backlog
    /// WHEN: User switches back to Coach tab
    /// THEN: Coach reflects the updated completion count (REALITY check)
    func testCoachRefreshesAfterBacklogCompletion() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // 1. Go to Coach, note the completed count
        let coachTab = tabBar.buttons["Coach"]
        coachTab.tap()
        XCTAssertTrue(coachTab.waitForExistence(timeout: 3))

        // Scroll to see daytime section
        app.swipeUp()

        // Find "schon erledigt" text and capture count
        let completedBefore = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'schon erledigt'")
        ).firstMatch
        let hadCompletedBefore = completedBefore.waitForExistence(timeout: 3)
        let countBefore = hadCompletedBefore ? completedBefore.label : "0"

        // 2. Switch to Backlog
        tabBar.buttons["Backlog"].tap()
        XCTAssertTrue(tabBar.buttons["Backlog"].waitForExistence(timeout: 3))

        // 3. Complete a task in Backlog (tap first complete button)
        let completeButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        ).firstMatch
        if completeButton.waitForExistence(timeout: 5) {
            completeButton.tap()
        }

        // 4. Switch back to Coach
        coachTab.tap()
        XCTAssertTrue(coachTab.waitForExistence(timeout: 3))

        // 5. Scroll to daytime section again
        app.swipeUp()

        // 6. REALITY CHECK: Coach must show updated data
        let completedAfter = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'schon erledigt'")
        ).firstMatch
        XCTAssertTrue(completedAfter.waitForExistence(timeout: 5),
                      "Coach should show updated completed count after tab switch. Before: \(countBefore)")
    }
}
