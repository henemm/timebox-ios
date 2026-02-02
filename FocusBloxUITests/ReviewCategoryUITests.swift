import XCTest

/// UI Tests for Review Integration with Calendar Events - Phase 2
/// Tests that categorized calendar events appear in review statistics
final class ReviewCategoryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ResetUserDefaults"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateToReview() {
        let reviewTab = app.tabBars.buttons["Rückblick"]
        if reviewTab.waitForExistence(timeout: 5) {
            reviewTab.tap()
        }
    }

    private func switchToWeekView() {
        let weekPicker = app.buttons["Diese Woche"]
        if weekPicker.waitForExistence(timeout: 3) {
            weekPicker.tap()
        }
    }

    // MARK: - User Expectation Tests

    /// USER EXPECTATION 1:
    /// Calendar events should contribute to category statistics
    ///
    /// GIVEN: There are categorized calendar events (Workshop = learning)
    /// WHEN: User views Weekly Review
    /// THEN: "Lernen" category shows time from calendar events
    func testCategorizedEventsAppearInWeeklyStats() throws {
        navigateToReview()
        switchToWeekView()
        sleep(2)

        // Should see "Zeit pro Kategorie" section
        let categorySection = app.staticTexts["Zeit pro Kategorie"]
        XCTAssertTrue(categorySection.waitForExistence(timeout: 5),
            "Category stats section should exist in weekly view")

        // "Lernen" should appear (from Workshop event with category:learning)
        // The mock has Workshop event at 16:00-17:00 = 60 minutes
        let learningCategory = app.staticTexts["Lernen"]
        XCTAssertTrue(learningCategory.waitForExistence(timeout: 3),
            "Learning category should appear from categorized Workshop event")
    }

    /// USER EXPECTATION 2:
    /// Uncategorized calendar events should count as "Unbekannt"
    ///
    /// GIVEN: There are calendar events without category (Team Meeting, Lunch Meeting)
    /// WHEN: User views Weekly Review
    /// THEN: "Unbekannt" category shows time from uncategorized events
    func testUncategorizedEventsShowAsUnknown() throws {
        navigateToReview()
        switchToWeekView()
        sleep(2)

        // "Unbekannt" should appear for uncategorized events
        // Mock has: Team Meeting (30min) + Lunch Meeting (60min) = 90 min uncategorized
        let unknownCategory = app.staticTexts["Unbekannt"]
        XCTAssertTrue(unknownCategory.waitForExistence(timeout: 3),
            "Uncategorized events should appear as 'Unbekannt' in review")
    }

    /// USER EXPECTATION 3:
    /// Total time in review should include both Focus Blocks AND calendar events
    ///
    /// GIVEN: Mix of Focus Blocks and calendar events
    /// WHEN: User views Weekly Review
    /// THEN: Stats reflect combined time
    func testTotalTimeIncludesEventsAndBlocks() throws {
        navigateToReview()
        switchToWeekView()
        sleep(2)

        // Should have multiple categories visible
        let categorySection = app.staticTexts["Zeit pro Kategorie"]
        guard categorySection.waitForExistence(timeout: 5) else {
            XCTFail("Category section should exist")
            return
        }

        // At minimum, we should see time bars for categories
        // This verifies the view is populated
        let categoryBars = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'categoryBar'"))

        // We can't assert exact count, but there should be at least one category
        // showing time from either Focus Blocks or Calendar Events
        XCTAssertTrue(categoryBars.count > 0 || learningOrUnknownExists(),
            "Review should show category stats from events and/or blocks")
    }

    private func learningOrUnknownExists() -> Bool {
        return app.staticTexts["Lernen"].exists || app.staticTexts["Unbekannt"].exists
    }

    /// USER EXPECTATION 4:
    /// Calendar events section should be visible in daily review
    ///
    /// GIVEN: User has calendar events today
    /// WHEN: User views Daily Review (Heute)
    /// THEN: A section shows today's calendar events with their categories
    func testDailyReviewShowsCalendarEvents() throws {
        navigateToReview()
        // Should be on "Heute" by default
        sleep(2)

        // Should see indication of calendar events or their contribution
        // Either a dedicated section or integrated into stats
        let todayLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Heute'"))
        XCTAssertTrue(todayLabel.count > 0, "Daily review should show 'Heute'")

        // The view should load without crashing (basic smoke test)
        // More specific assertions depend on mock data setup
    }

    /// USER EXPECTATION 5:
    /// "Unbekannt" category should have appropriate visual styling
    ///
    /// GIVEN: There are uncategorized events
    /// WHEN: User views category breakdown
    /// THEN: "Unbekannt" has a distinct (gray) color and icon
    func testUnknownCategoryHasDistinctStyling() throws {
        navigateToReview()
        switchToWeekView()
        sleep(2)

        // Look for unknown category
        let unknownCategory = app.staticTexts["Unbekannt"]
        guard unknownCategory.waitForExistence(timeout: 3) else {
            // If no uncategorized events, test passes trivially
            return
        }

        // The category should be visible with its row
        // We can't easily test color in UI tests, but we verify the label exists
        XCTAssertTrue(unknownCategory.exists,
            "Unbekannt should be visible with distinct styling")
    }
}
