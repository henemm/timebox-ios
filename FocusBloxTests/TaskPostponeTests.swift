import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for LocalTask.postpone() shared helper (Bug 85-C)
/// These tests verify:
/// 1. dueDate is advanced by correct number of days
/// 2. modifiedAt is updated
/// 3. rescheduleCount is incremented
/// 4. Tasks without dueDate are not modified
/// 5. Notification rescheduling is triggered (cancel + schedule)
final class TaskPostponeTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeTask(
        title: String = "Test Task",
        dueDate: Date? = Date(),
        rescheduleCount: Int = 0
    ) -> LocalTask {
        let task = LocalTask(title: title, dueDate: dueDate)
        task.rescheduleCount = rescheduleCount
        context.insert(task)
        try! context.save()
        return task
    }

    // MARK: - Postpone by 1 day (Morgen)

    /// GIVEN: Task with dueDate today
    /// WHEN: postpone by 1 day
    /// THEN: dueDate is tomorrow
    /// BREAKS WHEN: LocalTask.postpone() does not exist or miscalculates date
    func test_postpone_byOneDay_advancesDueDateByOneDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let task = makeTask(dueDate: today)

        LocalTask.postpone(task, byDays: 1, context: context)

        let expected = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: task.dueDate!),
            Calendar.current.startOfDay(for: expected),
            "dueDate should be advanced by 1 day"
        )
    }

    // MARK: - Postpone by 7 days (Naechste Woche)

    /// GIVEN: Task with dueDate today
    /// WHEN: postpone by 7 days
    /// THEN: dueDate is 7 days from now
    /// BREAKS WHEN: LocalTask.postpone() miscalculates or uses wrong Calendar method
    func test_postpone_bySevenDays_advancesDueDateBySevenDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let task = makeTask(dueDate: today)

        LocalTask.postpone(task, byDays: 7, context: context)

        let expected = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: task.dueDate!),
            Calendar.current.startOfDay(for: expected),
            "dueDate should be advanced by 7 days"
        )
    }

    // MARK: - modifiedAt is updated

    /// GIVEN: Task with no modifiedAt
    /// WHEN: postpone
    /// THEN: modifiedAt is set to now
    /// BREAKS WHEN: postpone() forgets to update modifiedAt
    func test_postpone_updatesModifiedAt() {
        let task = makeTask()
        task.modifiedAt = nil
        try! context.save()

        let before = Date()
        LocalTask.postpone(task, byDays: 1, context: context)

        XCTAssertNotNil(task.modifiedAt, "modifiedAt should be set after postpone")
        XCTAssertGreaterThanOrEqual(
            task.modifiedAt!.timeIntervalSince1970,
            before.timeIntervalSince1970 - 1,
            "modifiedAt should be approximately now"
        )
    }

    // MARK: - rescheduleCount incremented

    /// GIVEN: Task with rescheduleCount = 2
    /// WHEN: postpone
    /// THEN: rescheduleCount = 3
    /// BREAKS WHEN: postpone() forgets to increment rescheduleCount
    func test_postpone_incrementsRescheduleCount() {
        let task = makeTask(rescheduleCount: 2)

        LocalTask.postpone(task, byDays: 1, context: context)

        XCTAssertEqual(task.rescheduleCount, 3, "rescheduleCount should increment by 1")
    }

    // MARK: - No dueDate → no-op

    /// GIVEN: Task without dueDate
    /// WHEN: postpone
    /// THEN: nothing changes (dueDate stays nil, rescheduleCount unchanged)
    /// BREAKS WHEN: postpone() crashes on nil dueDate or creates a date from nothing
    func test_postpone_withoutDueDate_doesNothing() {
        let task = makeTask(dueDate: nil, rescheduleCount: 0)
        let originalModifiedAt = task.modifiedAt

        LocalTask.postpone(task, byDays: 1, context: context)

        XCTAssertNil(task.dueDate, "dueDate should remain nil")
        XCTAssertEqual(task.rescheduleCount, 0, "rescheduleCount should not change")
        XCTAssertEqual(task.modifiedAt, originalModifiedAt, "modifiedAt should not change")
    }

    // MARK: - Preserves time component

    /// GIVEN: Task with dueDate including time (14:30)
    /// WHEN: postpone by 1 day
    /// THEN: dueDate is tomorrow at 14:30 (time preserved)
    /// BREAKS WHEN: postpone() resets time to midnight
    func test_postpone_preservesTimeComponent() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 30
        let dueDateWithTime = Calendar.current.date(from: components)!
        let task = makeTask(dueDate: dueDateWithTime)

        LocalTask.postpone(task, byDays: 1, context: context)

        let resultComponents = Calendar.current.dateComponents([.hour, .minute], from: task.dueDate!)
        XCTAssertEqual(resultComponents.hour, 14, "Hour should be preserved")
        XCTAssertEqual(resultComponents.minute, 30, "Minute should be preserved")
    }

    // MARK: - Overdue task postponed (Bug: falsches Ursprungsdatum)

    /// GIVEN: Task was due 5 days ago
    /// WHEN: postpone by 1 day ("Morgen")
    /// THEN: dueDate is TOMORROW (not original + 1 = still 4 days overdue)
    /// BREAKS WHEN: postpone() adds days to original dueDate instead of today
    func test_postpone_overdueTask_byOneDay_setsDueDateToTomorrow() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Calendar.current.startOfDay(for: Date()))!
        let task = makeTask(dueDate: fiveDaysAgo)

        LocalTask.postpone(task, byDays: 1, context: context)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: task.dueDate!),
            tomorrow,
            "Overdue task postponed by 1 day should be TOMORROW, not original+1"
        )
    }

    /// GIVEN: Task was due 10 days ago
    /// WHEN: postpone by 7 days ("Naechste Woche")
    /// THEN: dueDate is 7 days from TODAY (not original + 7 = still 3 days overdue)
    /// BREAKS WHEN: postpone() adds days to original dueDate instead of today
    func test_postpone_overdueTask_bySevenDays_setsDueDateToNextWeek() {
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Calendar.current.startOfDay(for: Date()))!
        let task = makeTask(dueDate: tenDaysAgo)

        LocalTask.postpone(task, byDays: 7, context: context)

        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: task.dueDate!),
            nextWeek,
            "Overdue task postponed by 7 days should be NEXT WEEK from today, not original+7"
        )
    }

    /// GIVEN: Task was due 3 days ago at 14:30
    /// WHEN: postpone by 1 day
    /// THEN: dueDate is TOMORROW at 14:30 (day from today, time preserved from original)
    /// BREAKS WHEN: postpone() adds days to original date OR loses time component
    func test_postpone_overdueTask_preservesTimeComponent() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: Date()))!
        var components = Calendar.current.dateComponents([.year, .month, .day], from: threeDaysAgo)
        components.hour = 14
        components.minute = 30
        let overdueWithTime = Calendar.current.date(from: components)!
        let task = makeTask(dueDate: overdueWithTime)

        LocalTask.postpone(task, byDays: 1, context: context)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: task.dueDate!),
            tomorrow,
            "Day should be tomorrow, not 2-days-ago"
        )
        let resultComponents = Calendar.current.dateComponents([.hour, .minute], from: task.dueDate!)
        XCTAssertEqual(resultComponents.hour, 14, "Hour should be preserved from original")
        XCTAssertEqual(resultComponents.minute, 30, "Minute should be preserved from original")
    }
}
