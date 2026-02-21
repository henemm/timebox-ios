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

    // MARK: - Dedup Tests

    /// When two tasks from the same series are completed concurrently (e.g. offline on 2 devices),
    /// createNextInstance should NOT create a duplicate open instance for the same due date.
    @MainActor
    func testCreateNextInstance_dedup_preventsDuplicateForSameDueDate() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let groupID = "dedup-test-group"
        let baseDueDate = makeDate(2026, 2, 17) // Monday

        // Simulate: two daily tasks from the same series, both with same dueDate (completed concurrently)
        let task1 = LocalTask(
            title: "Daily Standup",
            dueDate: baseDueDate,
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        task1.isCompleted = true
        task1.completedAt = Date()

        let task2 = LocalTask(
            title: "Daily Standup",
            dueDate: baseDueDate,
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        task2.isCompleted = true
        task2.completedAt = Date()

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // First completion creates next instance (Feb 18) - should succeed
        let instance1 = RecurrenceService.createNextInstance(from: task1, in: context)
        XCTAssertNotNil(instance1, "First instance should be created")
        try context.save()

        // Second completion tries to create same next instance (Feb 18) - should be DEDUPLICATED
        let instance2 = RecurrenceService.createNextInstance(from: task2, in: context)
        XCTAssertNil(instance2, "Duplicate instance should NOT be created")

        // Verify: only ONE open instance for Feb 18
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.recurrenceGroupID == groupID && !$0.isCompleted }
        )
        let openTasks = try context.fetch(descriptor)
        XCTAssertEqual(openTasks.count, 1, "There should be exactly one open instance, got \(openTasks.count)")
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


    // MARK: - nextDueDate Tests for NEW Patterns (Feature: recurrence-editing Phase 1)
    // EXPECTED TO FAIL: New patterns not yet handled in RecurrenceService.nextDueDate()

    /// weekdays pattern from Friday → next Monday
    func testNextDueDate_weekdays_fromFriday() {
        // 2026-02-20 is a Friday
        let base = makeDate(2026, 2, 20)
        let result = RecurrenceService.nextDueDate(pattern: "weekdays", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "weekdays pattern should return a date, not nil")
        if let result {
            // Next weekday after Friday = Monday (Feb 23)
            XCTAssertEqual(calendar.component(.day, from: result), 23)
            XCTAssertEqual(calendar.component(.month, from: result), 2)
        }
    }

    /// weekdays pattern from Wednesday → next Thursday
    func testNextDueDate_weekdays_fromWednesday() {
        // 2026-02-18 is a Wednesday
        let base = makeDate(2026, 2, 18)
        let result = RecurrenceService.nextDueDate(pattern: "weekdays", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "weekdays pattern should return a date")
        if let result {
            // Next weekday after Wednesday = Thursday (Feb 19)
            XCTAssertEqual(calendar.component(.day, from: result), 19)
        }
    }

    /// weekends pattern from Saturday → next Sunday
    func testNextDueDate_weekends_fromSaturday() {
        // 2026-02-21 is a Saturday
        let base = makeDate(2026, 2, 21)
        let result = RecurrenceService.nextDueDate(pattern: "weekends", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "weekends pattern should return a date, not nil")
        if let result {
            // Next weekend day after Saturday = Sunday (Feb 22)
            XCTAssertEqual(calendar.component(.day, from: result), 22)
        }
    }

    /// weekends pattern from Wednesday → next Saturday
    func testNextDueDate_weekends_fromWednesday() {
        // 2026-02-18 is a Wednesday
        let base = makeDate(2026, 2, 18)
        let result = RecurrenceService.nextDueDate(pattern: "weekends", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "weekends pattern should return a date")
        if let result {
            // Next weekend day after Wednesday = Saturday (Feb 21)
            XCTAssertEqual(calendar.component(.day, from: result), 21)
        }
    }

    /// quarterly pattern → baseDate + 3 months
    func testNextDueDate_quarterly() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "quarterly", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "quarterly pattern should return a date, not nil")
        if let result {
            // Feb 16 + 3 months = May 16
            XCTAssertEqual(calendar.component(.month, from: result), 5)
            XCTAssertEqual(calendar.component(.day, from: result), 16)
        }
    }

    /// semiannually pattern → baseDate + 6 months
    func testNextDueDate_semiannually() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "semiannually", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "semiannually pattern should return a date, not nil")
        if let result {
            // Feb 16 + 6 months = Aug 16
            XCTAssertEqual(calendar.component(.month, from: result), 8)
            XCTAssertEqual(calendar.component(.day, from: result), 16)
        }
    }

    /// yearly pattern → baseDate + 1 year
    func testNextDueDate_yearly() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(pattern: "yearly", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result, "yearly pattern should return a date, not nil")
        if let result {
            // Feb 16 + 1 year = Feb 16, 2027
            XCTAssertEqual(calendar.component(.year, from: result), 2027)
            XCTAssertEqual(calendar.component(.month, from: result), 2)
            XCTAssertEqual(calendar.component(.day, from: result), 16)
        }
    }

    /// quarterly from end of month handles month-length differences
    func testNextDueDate_quarterly_endOfMonth() {
        // Jan 31 + 3 months = April 30 (April has 30 days)
        let base = makeDate(2026, 1, 31)
        let result = RecurrenceService.nextDueDate(pattern: "quarterly", weekdays: nil, monthDay: nil, from: base)
        XCTAssertNotNil(result)
        if let result {
            XCTAssertEqual(calendar.component(.month, from: result), 4)
            // April has 30 days, so 31 clamps to 30
            XCTAssertTrue(calendar.component(.day, from: result) <= 30)
        }
    }

    // MARK: - Phase 2: Interval Support

    /// nextDueDate with daily + interval 3 → baseDate + 3 days
    /// Bricht wenn: `interval` Parameter in nextDueDate fehlt oder nicht multipliziert wird
    func testNextDueDate_daily_interval3() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "daily", weekdays: nil, monthDay: nil,
            interval: 3, from: base
        )
        XCTAssertNotNil(result)
        let expected = makeDate(2026, 2, 19) // +3 Tage
        XCTAssertEqual(calendar.component(.day, from: result!), 19)
        XCTAssertEqual(calendar.component(.month, from: result!), 2)
    }

    /// nextDueDate with weekly + interval 2 = biweekly equivalent
    /// Bricht wenn: weekly case ignoriert den interval Parameter
    func testNextDueDate_weekly_interval2() {
        let base = makeDate(2026, 2, 16) // Montag
        let result = RecurrenceService.nextDueDate(
            pattern: "weekly", weekdays: nil, monthDay: nil,
            interval: 2, from: base
        )
        XCTAssertNotNil(result)
        // weekly interval 2 ohne weekdays = +14 Tage
        XCTAssertEqual(calendar.component(.day, from: result!), 2) // 2. März
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
    }

    /// nextDueDate with monthly + interval 3 = quarterly equivalent
    /// Bricht wenn: monthly case ignoriert den interval Parameter
    func testNextDueDate_monthly_interval3() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "monthly", weekdays: nil, monthDay: nil,
            interval: 3, from: base
        )
        XCTAssertNotNil(result)
        // monthly interval 3 = +3 Monate
        XCTAssertEqual(calendar.component(.month, from: result!), 5)
    }

    /// nextDueDate with yearly + interval 2 → baseDate + 2 Jahre
    /// Bricht wenn: yearly case ignoriert den interval Parameter
    func testNextDueDate_yearly_interval2() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "yearly", weekdays: nil, monthDay: nil,
            interval: 2, from: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.year, from: result!), 2028)
    }

    /// Default interval (nil or 1) should behave exactly like before
    /// Bricht wenn: nil-interval nicht als 1 behandelt wird
    func testNextDueDate_daily_nilInterval_behavesAsDefault() {
        let base = makeDate(2026, 2, 16)
        let withNil = RecurrenceService.nextDueDate(
            pattern: "daily", weekdays: nil, monthDay: nil,
            interval: nil, from: base
        )
        let withOne = RecurrenceService.nextDueDate(
            pattern: "daily", weekdays: nil, monthDay: nil,
            interval: 1, from: base
        )
        let legacy = RecurrenceService.nextDueDate(
            pattern: "daily", weekdays: nil, monthDay: nil,
            from: base
        )
        XCTAssertEqual(withNil, withOne, "nil interval should equal interval 1")
        XCTAssertEqual(withNil, legacy, "nil interval should match legacy (no interval param)")
    }

    /// createNextInstance should use task's recurrenceInterval
    /// Bricht wenn: createNextInstance ignoriert recurrenceInterval auf LocalTask
    @MainActor
    func testCreateNextInstance_usesRecurrenceInterval() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let original = LocalTask(
            title: "Every 3 Days",
            dueDate: makeDate(2026, 2, 16),
            recurrencePattern: "daily"
        )
        original.recurrenceInterval = 3
        context.insert(original)
        try context.save()

        let instance = RecurrenceService.createNextInstance(from: original, in: context)

        XCTAssertNotNil(instance)
        // Due date should be +3 days (Feb 19), not +1 day
        XCTAssertEqual(calendar.component(.day, from: instance!.dueDate!), 19)
        // Interval should be copied to new instance
        XCTAssertEqual(instance!.recurrenceInterval, 3)
    }

    // MARK: - Custom Pattern Tests

    /// custom pattern with daily base (monthDay=1001) + interval 3 → +3 days
    /// Bricht wenn: "custom" case in nextDueDate nicht implementiert oder monthDay-Codes falsch
    func testNextDueDate_custom_dailyBase_interval3() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "custom", weekdays: nil, monthDay: 1001,
            interval: 3, from: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 19)
    }

    /// custom pattern with weekly base (monthDay=1002) + interval 2 → +14 days
    /// Bricht wenn: custom weekly resolution fehlschlaegt
    func testNextDueDate_custom_weeklyBase_interval2() {
        let base = makeDate(2026, 2, 16) // Sunday
        let result = RecurrenceService.nextDueDate(
            pattern: "custom", weekdays: nil, monthDay: 1002,
            interval: 2, from: base
        )
        XCTAssertNotNil(result)
        // Weekly with no weekdays and interval 2 → +14 days
        XCTAssertEqual(calendar.component(.day, from: result!), 2)
        XCTAssertEqual(calendar.component(.month, from: result!), 3)
    }

    /// custom pattern with monthly base (monthDay=1003) + interval 2 → +2 months
    /// Bricht wenn: custom monthly resolution fehlschlaegt
    func testNextDueDate_custom_monthlyBase_interval2() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "custom", weekdays: nil, monthDay: 1003,
            interval: 2, from: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.month, from: result!), 4)
    }

    /// custom pattern with yearly base (monthDay=1004) + interval 1 → +1 year
    /// Bricht wenn: custom yearly resolution fehlschlaegt
    func testNextDueDate_custom_yearlyBase_interval1() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "custom", weekdays: nil, monthDay: 1004,
            interval: 1, from: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.year, from: result!), 2027)
    }

    /// custom pattern with nil monthDay defaults to daily
    /// Bricht wenn: nil-monthDay default case nicht "daily"
    func testNextDueDate_custom_nilMonthDay_defaultsToDaily() {
        let base = makeDate(2026, 2, 16)
        let result = RecurrenceService.nextDueDate(
            pattern: "custom", weekdays: nil, monthDay: nil,
            interval: 5, from: base
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!), 21)
    }

    // MARK: - repairOrphanedRecurringSeries Tests

    /// Completed recurring task without open successor must be repaired.
    /// Bricht wenn: RecurrenceService.repairOrphanedRecurringSeries() nicht implementiert oder nicht aufgerufen.
    @MainActor
    func test_repairOrphaned_createsSuccessorForOrphanedSeries() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = "orphaned-series"

        // Completed recurring task — NO open successor exists
        let completed = LocalTask(
            title: "1 Blink lesen",
            dueDate: Calendar.current.startOfDay(for: Date()),
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        completed.isCompleted = true
        completed.completedAt = Date()
        context.insert(completed)
        try context.save()

        // Verify: no open tasks exist
        let beforeOpen = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        ))
        XCTAssertEqual(beforeOpen.count, 0, "No open tasks should exist before repair")

        // Run repair
        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        // Verify: new open task created
        let afterOpen = try context.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        ))
        XCTAssertEqual(repaired, 1, "Should repair exactly 1 orphaned series")
        XCTAssertEqual(afterOpen.count, 1, "One open successor should exist after repair")
        XCTAssertEqual(afterOpen.first?.title, "1 Blink lesen")
        XCTAssertEqual(afterOpen.first?.recurrencePattern, "daily")
        XCTAssertEqual(afterOpen.first?.recurrenceGroupID, groupID)
    }

    /// Series WITH an open successor should NOT be repaired (no duplicates).
    /// Bricht wenn: Repair-Logik Dedup-Check fehlt.
    @MainActor
    func test_repairOrphaned_skipsSeriesWithOpenSuccessor() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = "healthy-series"

        // Completed + open successor already exists
        let completed = LocalTask(title: "Healthy Task", dueDate: Date(), recurrencePattern: "daily", recurrenceGroupID: groupID)
        completed.isCompleted = true
        completed.completedAt = Date()

        let openSuccessor = LocalTask(title: "Healthy Task", dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), recurrencePattern: "daily", recurrenceGroupID: groupID)

        context.insert(completed)
        context.insert(openSuccessor)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)
        XCTAssertEqual(repaired, 0, "Healthy series should NOT be repaired")

        let allOpen = try context.fetch(FetchDescriptor<LocalTask>(predicate: #Predicate { !$0.isCompleted }))
        XCTAssertEqual(allOpen.count, 1, "Still exactly one open task")
    }

    /// Non-recurring completed tasks should be ignored.
    /// Bricht wenn: Guard-Check fuer recurrencePattern fehlt.
    @MainActor
    func test_repairOrphaned_ignoresNonRecurring() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let completed = LocalTask(title: "One-Off", recurrencePattern: "none")
        completed.isCompleted = true
        completed.completedAt = Date()
        context.insert(completed)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)
        XCTAssertEqual(repaired, 0, "Non-recurring tasks should not be repaired")
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
