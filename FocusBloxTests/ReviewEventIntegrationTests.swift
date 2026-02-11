import XCTest
@testable import FocusBlox

/// Unit Tests for Review Integration with Calendar Events
/// TDD RED: These tests MUST FAIL because ReviewStatsCalculator doesn't exist yet
final class ReviewEventIntegrationTests: XCTestCase {

    // MARK: - Helper: Create CalendarEvent with category

    private func makeEvent(
        id: String = UUID().uuidString,
        title: String,
        durationMinutes: Int,
        category: String?
    ) -> CalendarEvent {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        var notes: String? = nil
        if let category {
            notes = "category:\(category)"
        }
        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarColor: nil,
            notes: notes
        )
    }

    private func makeFocusBlockEvent(
        id: String = UUID().uuidString,
        title: String,
        durationMinutes: Int,
        category: String? = nil
    ) -> CalendarEvent {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        var notesLines = ["focusBlock:true", "tasks:task-1"]
        if let category {
            notesLines.append("category:\(category)")
        }
        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarColor: nil,
            notes: notesLines.joined(separator: "\n")
        )
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
