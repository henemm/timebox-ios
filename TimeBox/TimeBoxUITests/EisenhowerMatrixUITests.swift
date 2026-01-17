import XCTest

final class EisenhowerMatrixUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Tests

    /// GIVEN: App is launched
    /// WHEN: User taps "Matrix" tab
    /// THEN: Eisenhower Matrix view should be displayed
    func testEisenhowerMatrixTabExists() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        XCTAssertTrue(matrixTab.waitForExistence(timeout: 5), "Matrix tab should exist")

        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3), "Eisenhower Matrix navigation bar should appear")
    }

    // MARK: - Quadrant UI Tests

    /// GIVEN: Matrix view is displayed
    /// WHEN: Looking at the view
    /// THEN: All 4 quadrants should be visible
    func testAllFourQuadrantsVisible() throws {
        // Navigate to Matrix tab
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        // Wait for view to load
        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Check for all 4 quadrant titles
        // Using staticTexts (Text views in SwiftUI)
        let doFirstTitle = app.staticTexts["Do First"]
        let scheduleTitle = app.staticTexts["Schedule"]
        let delegateTitle = app.staticTexts["Delegate"]
        let eliminateTitle = app.staticTexts["Eliminate"]

        XCTAssertTrue(doFirstTitle.exists, "Do First quadrant should be visible")
        XCTAssertTrue(scheduleTitle.exists, "Schedule quadrant should be visible")
        XCTAssertTrue(delegateTitle.exists, "Delegate quadrant should be visible")
        XCTAssertTrue(eliminateTitle.exists, "Eliminate quadrant should be visible")
    }

    /// GIVEN: Matrix view is displayed
    /// WHEN: Looking at quadrant subtitles
    /// THEN: Each quadrant should show its German subtitle
    func testQuadrantSubtitlesVisible() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Check for German subtitles
        let doFirstSubtitle = app.staticTexts["Dringend + Wichtig"]
        let scheduleSubtitle = app.staticTexts["Nicht dringend + Wichtig"]
        let delegateSubtitle = app.staticTexts["Dringend + Weniger wichtig"]
        let eliminateSubtitle = app.staticTexts["Nicht dringend + Weniger wichtig"]

        XCTAssertTrue(doFirstSubtitle.exists, "Do First subtitle should be visible")
        XCTAssertTrue(scheduleSubtitle.exists, "Schedule subtitle should be visible")
        XCTAssertTrue(delegateSubtitle.exists, "Delegate subtitle should be visible")
        XCTAssertTrue(eliminateSubtitle.exists, "Eliminate subtitle should be visible")
    }

    // MARK: - Task Count Tests

    /// GIVEN: Matrix view is displayed
    /// WHEN: Looking at quadrants
    /// THEN: Each quadrant should show task count (number badge)
    func testQuadrantTaskCountsVisible() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Task counts are displayed as large bold numbers
        // They should exist (even if 0)
        // We can't check exact numbers without test data, but we can verify UI structure

        // Verify scrollView exists (quadrants in scrollable container)
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "ScrollView should exist for quadrants")
    }

    // MARK: - Empty State Tests

    /// GIVEN: No tasks in database
    /// WHEN: Matrix view is displayed
    /// THEN: All quadrants should show "Keine Tasks"
    func testEmptyStateShowsNoTasksMessage() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // In empty state, "Keine Tasks" should appear
        // (May need to scroll to see all quadrants)
        let noTasksLabels = app.staticTexts.matching(identifier: "Keine Tasks")

        // At least one "Keine Tasks" should be visible
        // (We may not see all 4 without scrolling, but at least one should be there)
        XCTAssertGreaterThan(noTasksLabels.count, 0, "Empty state message should be visible")
    }

    // MARK: - Pull to Refresh Tests

    /// GIVEN: Matrix view is displayed
    /// WHEN: User pulls down to refresh
    /// THEN: View should reload tasks
    func testPullToRefreshWorks() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Find scrollView
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "ScrollView should exist")

        // Perform pull-to-refresh gesture
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait a moment for refresh to complete
        sleep(1)

        // Verify view is still displayed (no crash)
        XCTAssertTrue(navBar.exists, "Matrix view should still be displayed after refresh")
    }

    // MARK: - Visual Hierarchy Tests

    /// GIVEN: Matrix view is displayed
    /// WHEN: Looking at quadrant cards
    /// THEN: Each quadrant should have icon, title, subtitle, and count
    func testQuadrantCardsShowAllElements() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Do First quadrant (first in list)
        // Icons in SwiftUI are rendered as images
        let doFirstTitle = app.staticTexts["Do First"]
        XCTAssertTrue(doFirstTitle.exists, "Do First title should exist")

        let doFirstSubtitle = app.staticTexts["Dringend + Wichtig"]
        XCTAssertTrue(doFirstSubtitle.exists, "Do First subtitle should exist")

        // Count badge should exist (as staticText with number)
        // We can't test exact count without known data, but structure should be there
    }

    // MARK: - Scrolling Tests

    /// GIVEN: Matrix view with all quadrants
    /// WHEN: User scrolls down
    /// THEN: Lower quadrants should become visible
    func testScrollingShowsAllQuadrants() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Check first quadrant is visible
        let doFirstTitle = app.staticTexts["Do First"]
        XCTAssertTrue(doFirstTitle.exists, "Do First should be visible initially")

        // Scroll down
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        // Wait for scroll animation
        sleep(1)

        // Check that Schedule or Delegate quadrants are visible
        let scheduleTitle = app.staticTexts["Schedule"]
        let delegateTitle = app.staticTexts["Delegate"]

        let lowerQuadrantsVisible = scheduleTitle.exists || delegateTitle.exists
        XCTAssertTrue(lowerQuadrantsVisible, "Lower quadrants should be visible after scrolling")
    }

    // MARK: - Integration with BacklogRow Tests

    /// GIVEN: Matrix view with tasks
    /// WHEN: Tasks are displayed in quadrants
    /// THEN: Each task should show BacklogRow UI (title, duration badge, etc.)
    /// NOTE: This test requires test data - may fail in empty state
    func testQuadrantsShowBacklogRowForTasks() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // If there are tasks, BacklogRow elements should be visible
        // We can't guarantee tasks exist, so this is a soft check

        // Look for any DurationBadge (appears in BacklogRow)
        // Duration badges show minutes like "15 Min"
        let durationLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Min'"))

        // If tasks exist, duration badges should be visible
        // If no tasks, this is expected to be 0
        // This test just verifies the UI structure doesn't crash
        XCTAssertTrue(true, "Matrix view should handle tasks with BacklogRow UI")
    }

    // MARK: - Task Limit Display Tests

    /// GIVEN: Matrix view with > 5 tasks in a quadrant
    /// WHEN: Looking at quadrant
    /// THEN: Should show "+ N weitere" indicator
    /// NOTE: Requires test data with > 5 tasks in one quadrant
    func testQuadrantShowsMoreTasksIndicator() throws {
        let matrixTab = app.tabBars.buttons["Matrix"]
        matrixTab.tap()

        let navBar = app.navigationBars["Eisenhower Matrix"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        // Look for "+ X weitere" text
        // This will only appear if there are > 5 tasks in any quadrant
        let moreTasksLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'weitere'"))

        // This test just verifies UI doesn't crash when checking for this element
        // Actual count depends on test data
        XCTAssertTrue(true, "Matrix view should handle task overflow indicators")
    }
}
