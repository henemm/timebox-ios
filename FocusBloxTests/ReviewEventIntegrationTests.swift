import XCTest
@testable import FocusBlox

/// Unit Tests for Review Integration with Calendar Events
/// Validates that ReviewStatsCalculator correctly includes/excludes calendar events in category stats.
final class ReviewEventIntegrationTests: XCTestCase {

    private let categoryMappingKey = "calendarEventCategories"

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: categoryMappingKey)
    }

    // MARK: - Helper: Create CalendarEvent with category

    /// Creates a CalendarEvent and writes the category to UserDefaults (matching production behavior since BUG_63).
    private func makeEvent(
        id: String = UUID().uuidString,
        title: String,
        durationMinutes: Int,
        category: String?
    ) -> CalendarEvent {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let event = CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )
        if let category {
            setCategoryInUserDefaults(calendarItemID: event.calendarItemIdentifier, category: category)
        }
        return event
    }

    private func makeFocusBlockEvent(
        id: String = UUID().uuidString,
        title: String,
        durationMinutes: Int,
        category: String? = nil
    ) -> CalendarEvent {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let event = CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:task-1"
        )
        if let category {
            setCategoryInUserDefaults(calendarItemID: event.calendarItemIdentifier, category: category)
        }
        return event
    }

    private func setCategoryInUserDefaults(calendarItemID: String, category: String) {
        var dict = UserDefaults.standard.dictionary(forKey: categoryMappingKey) as? [String: String] ?? [:]
        dict[calendarItemID] = category
        UserDefaults.standard.set(dict, forKey: categoryMappingKey)
    }

    // MARK: - Test: ReviewStatsCalculator exists

    /// GIVEN: ReviewStatsCalculator utility
    /// WHEN: Instantiated
    /// THEN: Can compute category stats from events
    /// TDD RED: ReviewStatsCalculator does not exist yet
    func testReviewStatsCalculatorExists() throws {
        let calculator = ReviewStatsCalculator()
        XCTAssertNotNil(calculator, "ReviewStatsCalculator should exist")
    }

    // MARK: - Test: Categorized events counted in stats

    /// GIVEN: Events with category "income" (60 min) and "learning" (30 min)
    /// WHEN: Computing category stats
    /// THEN: Stats include 60 min for income and 30 min for learning
    func testCategoryStatsIncludesCalendarEvents() throws {
        let events = [
            makeEvent(title: "Client Meeting", durationMinutes: 60, category: "income"),
            makeEvent(title: "Workshop", durationMinutes: 30, category: "learning")
        ]

        let calculator = ReviewStatsCalculator()
        let stats = calculator.computeCategoryMinutes(tasks: [], calendarEvents: events)

        XCTAssertEqual(stats["income"], 60,
            "Income category should have 60 minutes from Client Meeting")
        XCTAssertEqual(stats["learning"], 30,
            "Learning category should have 30 minutes from Workshop")
    }

    // MARK: - Test: Uncategorized events excluded

    /// GIVEN: Events without category
    /// WHEN: Computing category stats
    /// THEN: Uncategorized events are NOT included
    func testCategoryStatsExcludesUncategorizedEvents() throws {
        let events = [
            makeEvent(title: "Team Standup", durationMinutes: 30, category: nil),
            makeEvent(title: "Lunch", durationMinutes: 60, category: nil)
        ]

        let calculator = ReviewStatsCalculator()
        let stats = calculator.computeCategoryMinutes(tasks: [], calendarEvents: events)

        XCTAssertTrue(stats.isEmpty,
            "Stats should be empty when all events lack categories")
    }

    // MARK: - Test: FocusBlock events excluded (no double-counting)

    /// GIVEN: FocusBlock events with category
    /// WHEN: Computing category stats
    /// THEN: FocusBlock events are NOT counted (they use task-based stats)
    func testCategoryStatsExcludesFocusBlockEvents() throws {
        let events = [
            makeFocusBlockEvent(title: "Deep Work", durationMinutes: 90, category: "income"),
            makeEvent(title: "Client Call", durationMinutes: 30, category: "income")
        ]

        let calculator = ReviewStatsCalculator()
        let stats = calculator.computeCategoryMinutes(tasks: [], calendarEvents: events)

        XCTAssertEqual(stats["income"], 30,
            "Only non-FocusBlock event should count (30 min, not 120)")
    }

    // MARK: - Test: Mixed tasks and events

    /// GIVEN: Completed tasks (45 min income) AND events (60 min income)
    /// WHEN: Computing category stats
    /// THEN: Stats combine both: 105 min income
    func testCategoryStatsCombinesTasksAndEvents() throws {
        let events = [
            makeEvent(title: "Client Meeting", durationMinutes: 60, category: "income")
        ]

        let calculator = ReviewStatsCalculator()
        let taskMinutes: [String: Int] = ["income": 45]
        let stats = calculator.computeCategoryMinutes(
            taskMinutesByCategory: taskMinutes,
            calendarEvents: events
        )

        XCTAssertEqual(stats["income"], 105,
            "Should combine task minutes (45) and event minutes (60) = 105")
    }
}
