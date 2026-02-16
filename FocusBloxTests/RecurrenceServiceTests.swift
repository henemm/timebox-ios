import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for RecurrenceService - next due date calculation and instance creation.
/// EXPECTED TO FAIL: RecurrenceService does not exist yet.
final class RecurrenceServiceTests: XCTestCase {

    // MARK: - nextDueDate Tests

    /// daily pattern → baseDate + 1 day
    func testNextDueDate_daily() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "daily", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 17)
        XCTAssertEqual(calendar.component(.month, from: result!), 2)
    }

    /// weekly with weekdays [1,3,5] (Mo/Mi/Fr), base=Monday → next Wednesday
    func testNextDueDate_weekly_withWeekdays() {
        // 2026-02-16 is a Monday (weekday 1 in our system: 1=Mo)
        let base = makeDate(2026, 2, 16) // Monday
        let result = RecurrenceService.nextDueDate(pattern: "weekly", weekdays: [1, 3, 5], monthDay: nil, from: base)
        XCTAssertNotNil(result)
        // Next matching weekday after Monday should be Wednesday (Feb 18)
        XCTAssertEqual(calendar.component(.day, from: result!), 18)
    }

    /// weekly without weekdays → baseDate + 7 days
    func testNextDueDate_weekly_noWeekdays() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "weekly", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 23)
    }

    /// biweekly → baseDate + 14 days
    func testNextDueDate_biweekly() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "biweekly", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 2)
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
    }

    /// monthly with monthDay=15 from Feb 16 → March 15
    func testNextDueDate_monthly_withMonthDay() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "monthly", weekdays: nil, monthDay: 15, from: base)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 15)
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
    }

    /// monthly with monthDay=32 → last day of next month
    func testNextDueDate_monthly_lastDay() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "monthly", weekdays: nil, monthDay: 32, from: base)
        XCTAssertNotNil(result)
        // Last day of March = 31
        XCTAssertEqual(calendar.component(.day, from: result!), 31)
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
    }

    /// none pattern → nil (no next date)
    func testNextDueDate_none() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "none", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNil(result)
    }

    // MARK: - createNextInstance Tests

    /// Instance copies all relevant attributes and gets new UUID
    @MainActor
    func testCreateNextInstance_copiesAttributes() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(
            title: "Recurring Task",
            importance: 3,
            tags: ["daily", "routine"],
            dueDate: makeDate(2026, 2, 16),
            estimatedDuration: 30,
            urgency: "urgent",
            taskType: "maintenance",
            recurrencePattern: "daily",
            taskDescription: "Do this every day"
        )
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)

        XCTAssertNotNil(instance, "Should create new instance")
        XCTAssertNotEqual(instance!.uuid, original.uuid, "New UUID")
        XCTAssertEqual(instance!.title, "Recurring Task")
        XCTAssertEqual(instance!.importance, 3)
        XCTAssertEqual(instance!.tags, ["daily", "routine"])
        XCTAssertEqual(instance!.estimatedDuration, 30)
        XCTAssertEqual(instance!.urgency, "urgent")
        XCTAssertEqual(instance!.taskType, "maintenance")
        XCTAssertEqual(instance!.recurrencePattern, "daily")
        XCTAssertEqual(instance!.taskDescription, "Do this every day")
        // Due date should be advanced to next day
        XCTAssertEqual(calendar.component(.day, from: instance!.dueDate!), 17)
    }

    /// Instance resets completion state
    @MainActor
    func testCreateNextInstance_resetsState() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(
            title: "Completed Recurring",
            dueDate: makeDate(2026, 2, 16),
            recurrencePattern: "daily"
        )
        original.isCompleted = true
        original.completedAt = Date()
        original.isNextUp = true
        original.assignedFocusBlockID = "block-123"
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)

        XCTAssertNotNil(instance)
        XCTAssertFalse(instance!.isCompleted, "Should not be completed")
        XCTAssertNil(instance!.completedAt, "Should have no completedAt")
        XCTAssertFalse(instance!.isNextUp, "Should not be in Next Up")
        XCTAssertNil(instance!.assignedFocusBlockID, "Should not be assigned to block")
    }

    /// none pattern → no instance created
    @MainActor
    func testCreateNextInstance_nonePattern() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(title: "One-time Task", recurrencePattern: "none")
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)
        XCTAssertNil(instance, "Should not create instance for non-recurring task")
    }

    // MARK: - Helpers

    private var calendar: Calendar { Calendar.current }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9
        return Calendar.current.date(from: components)!
    }
}
