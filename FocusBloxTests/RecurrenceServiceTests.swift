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

    // MARK: - recurrenceGroupID Tests (Ticket 1)

    /// GroupID should be copied from completed task to new instance
    @MainActor
    func testRecurrenceGroupID_copiedOnNewInstance() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(
            title: "Daily Standup",
            dueDate: makeDate(2026, 2, 17),
            recurrencePattern: "daily"
        )
        original.recurrenceGroupID = "group-abc-123"
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)

        XCTAssertNotNil(instance)
        XCTAssertEqual(instance!.recurrenceGroupID, "group-abc-123", "GroupID must be copied to new instance")
    }

    /// When completed task has no GroupID (legacy), a new one should be generated for both
    @MainActor
    func testRecurrenceGroupID_generatedWhenNil() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(
            title: "Legacy Recurring",
            dueDate: makeDate(2026, 2, 17),
            recurrencePattern: "weekly"
        )
        // No recurrenceGroupID set (legacy task)
        XCTAssertNil(original.recurrenceGroupID)
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)

        XCTAssertNotNil(instance)
        // Both should now have a GroupID
        XCTAssertNotNil(original.recurrenceGroupID, "Original should get a GroupID retroactively")
        XCTAssertNotNil(instance!.recurrenceGroupID, "New instance should get a GroupID")
        XCTAssertEqual(original.recurrenceGroupID, instance!.recurrenceGroupID, "Both should share the same GroupID")
    }

    // MARK: - Sichtbarkeit / Fetch Filter Tests (Ticket 1)

    /// Recurring tasks with future dueDate should be hidden from backlog
    @MainActor
    func testFetchIncompleteTasks_hidesForwardDatedRecurring() async throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let taskSource = LocalTaskSource(modelContext: context)

        // Task due tomorrow (recurring) - should be HIDDEN
        let futureRecurring = LocalTask(
            title: "Future Recurring",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            recurrencePattern: "daily"
        )
        context.insert(futureRecurring)

        // Task due today (recurring) - should be VISIBLE
        let todayRecurring = LocalTask(
            title: "Today Recurring",
            dueDate: Calendar.current.startOfDay(for: Date()),
            recurrencePattern: "daily"
        )
        context.insert(todayRecurring)

        // Normal task (no recurrence) - should always be VISIBLE
        let normalTask = LocalTask(title: "Normal Task")
        context.insert(normalTask)

        try context.save()

        let tasks = try await taskSource.fetchIncompleteTasks()

        let titles = tasks.map(\.title)
        XCTAssertTrue(titles.contains("Today Recurring"), "Today's recurring task should be visible")
        XCTAssertTrue(titles.contains("Normal Task"), "Normal tasks should always be visible")
        XCTAssertFalse(titles.contains("Future Recurring"), "Future recurring tasks should be hidden")
    }

    /// Recurring tasks without dueDate should remain visible
    @MainActor
    func testFetchIncompleteTasks_showsRecurringWithoutDueDate() async throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let taskSource = LocalTaskSource(modelContext: context)

        let noDueDateRecurring = LocalTask(
            title: "No DueDate Recurring",
            recurrencePattern: "weekly"
        )
        context.insert(noDueDateRecurring)
        try context.save()

        let tasks = try await taskSource.fetchIncompleteTasks()
        let titles = tasks.map(\.title)
        XCTAssertTrue(titles.contains("No DueDate Recurring"), "Recurring without dueDate should be visible")
    }


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
