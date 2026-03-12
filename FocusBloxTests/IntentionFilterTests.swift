import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for intention-based backlog filtering.
///
/// Tests the static function `IntentionOption.matchesFilter(activeOptions:task:)`
/// which determines task visibility based on active morning intentions.
///
/// ALL tests expected to FAIL (RED) — the function doesn't exist yet.
@MainActor
final class IntentionFilterTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    /// Creates a PlanItem from a LocalTask with specific properties.
    private func makePlanItem(
        title: String = "Test Task",
        isNextUp: Bool = false,
        importance: Int? = nil,
        rescheduleCount: Int = 0,
        taskType: String = ""
    ) -> PlanItem {
        let task = LocalTask(title: title, importance: importance, taskType: taskType)
        task.isNextUp = isNextUp
        task.rescheduleCount = rescheduleCount
        context.insert(task)
        return PlanItem(localTask: task)
    }

    // MARK: - UT-01: Survival overrides all other filters

    /// Verhalten: When survival is among active options, ALL tasks pass the filter.
    /// Bricht wenn: IntentionOption.matchesFilter doesn't check for .survival early-return.
    func test_survival_overridesAllOtherFilters() {
        let task = makePlanItem(isNextUp: false, importance: 1, taskType: "income")
        let activeOptions: [IntentionOption] = [.survival, .fokus, .bhag]

        let result = IntentionOption.matchesFilter(activeOptions: activeOptions, task: task)

        XCTAssertTrue(result, "Survival should override all other filters — every task passes")
    }

    // MARK: - UT-02: Fokus shows only NextUp tasks

    /// Verhalten: Fokus filter shows only tasks with isNextUp == true.
    /// Bricht wenn: IntentionOption.matchesFilter .fokus case doesn't check isNextUp.
    func test_fokus_onlyShowsNextUpTasks() {
        let nextUpTask = makePlanItem(title: "NextUp Task", isNextUp: true)
        let backlogTask = makePlanItem(title: "Backlog Task", isNextUp: false)
        let activeOptions: [IntentionOption] = [.fokus]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: nextUpTask),
            "NextUp task should be visible with fokus filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: backlogTask),
            "Non-NextUp task should be hidden with fokus filter"
        )
    }

    // MARK: - UT-03: BHAG shows tasks with importance 3

    /// Verhalten: BHAG filter shows tasks with importance == 3.
    /// Bricht wenn: IntentionOption.matchesFilter .bhag case doesn't check importance.
    func test_bhag_showsHighImportanceTasks() {
        let highTask = makePlanItem(title: "Important", importance: 3)
        let medTask = makePlanItem(title: "Medium", importance: 2)
        let activeOptions: [IntentionOption] = [.bhag]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: highTask),
            "Task with importance 3 should be visible with BHAG filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: medTask),
            "Task with importance 2 should be hidden with BHAG filter"
        )
    }

    // MARK: - UT-04: BHAG shows highly rescheduled tasks

    /// Verhalten: BHAG filter shows tasks with rescheduleCount >= 2.
    /// Bricht wenn: IntentionOption.matchesFilter .bhag case doesn't check rescheduleCount.
    func test_bhag_showsHighlyRescheduledTasks() {
        let rescheduled2 = makePlanItem(title: "Twice rescheduled", rescheduleCount: 2)
        let rescheduled5 = makePlanItem(title: "Often rescheduled", rescheduleCount: 5)
        let fresh = makePlanItem(title: "Fresh task", rescheduleCount: 0)
        let activeOptions: [IntentionOption] = [.bhag]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: rescheduled2),
            "Task rescheduled 2x should be visible with BHAG filter"
        )
        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: rescheduled5),
            "Task rescheduled 5x should be visible with BHAG filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: fresh),
            "Task with rescheduleCount 0 should be hidden with BHAG filter"
        )
    }

    // MARK: - UT-05: Growth filters on learning category

    /// Verhalten: Growth filter shows only tasks with taskType == "learning".
    /// Bricht wenn: IntentionOption.matchesFilter .growth case doesn't check taskType.
    func test_growth_filtersOnLearningCategory() {
        let learningTask = makePlanItem(title: "Learn Swift", taskType: "learning")
        let incomeTask = makePlanItem(title: "Invoice", taskType: "income")
        let emptyTask = makePlanItem(title: "No category", taskType: "")
        let activeOptions: [IntentionOption] = [.growth]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: learningTask),
            "Learning task should be visible with growth filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: incomeTask),
            "Income task should be hidden with growth filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: emptyTask),
            "Uncategorized task should be hidden with growth filter"
        )
    }

    // MARK: - UT-06: Connection filters on giving_back category

    /// Verhalten: Connection filter shows only tasks with taskType == "giving_back".
    /// Bricht wenn: IntentionOption.matchesFilter .connection case doesn't check taskType.
    func test_connection_filtersOnGivingBackCategory() {
        let socialTask = makePlanItem(title: "Call Mom", taskType: "giving_back")
        let workTask = makePlanItem(title: "Work task", taskType: "maintenance")
        let activeOptions: [IntentionOption] = [.connection]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: socialTask),
            "Giving_back task should be visible with connection filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: workTask),
            "Maintenance task should be hidden with connection filter"
        )
    }

    // MARK: - UT-07: Multi-select uses UNION logic

    /// Verhalten: Multiple intentions use OR logic — task visible if it matches ANY.
    /// Bricht wenn: matchesFilter uses AND instead of OR for multiple options.
    func test_multiSelect_usesUnionLogic() {
        let nextUpIncome = makePlanItem(title: "NextUp Income", isNextUp: true, taskType: "income")
        let learningBacklog = makePlanItem(title: "Learning Backlog", isNextUp: false, taskType: "learning")
        let neitherTask = makePlanItem(title: "Neither", isNextUp: false, taskType: "income")
        let activeOptions: [IntentionOption] = [.fokus, .growth]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: nextUpIncome),
            "NextUp task should pass via fokus filter"
        )
        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: learningBacklog),
            "Learning task should pass via growth filter"
        )
        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: neitherTask),
            "Task matching neither fokus nor growth should be hidden"
        )
    }

    // MARK: - UT-08: Balance shows all tasks (no filter)

    /// Verhalten: Balance has no task-level filter (only changes grouping in UI).
    /// Bricht wenn: IntentionOption.matchesFilter .balance case filters out tasks.
    func test_balance_showsAllTasks() {
        let anyTask = makePlanItem(title: "Random task", importance: 1, taskType: "income")
        let activeOptions: [IntentionOption] = [.balance]

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: anyTask),
            "Balance should show all tasks (filtering is UI-level grouping only)"
        )
    }

    // MARK: - UT-09: Empty filter list means no filter

    /// Verhalten: When no intentions are active, all tasks pass (no filtering).
    /// Bricht wenn: matchesFilter returns false for empty activeOptions.
    func test_emptyFilters_showsAllTasks() {
        let anyTask = makePlanItem(title: "Any task")
        let activeOptions: [IntentionOption] = []

        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: anyTask),
            "Empty filter list should show all tasks"
        )
    }

    // MARK: - UT-10: BHAG reschedule threshold is exactly 2

    /// Verhalten: rescheduleCount == 1 does NOT pass BHAG filter, == 2 does.
    /// Bricht wenn: BHAG threshold is != 2 (e.g. >= 1 or >= 3).
    func test_bhag_rescheduleThresholdIsTwo() {
        let once = makePlanItem(title: "Once rescheduled", rescheduleCount: 1)
        let twice = makePlanItem(title: "Twice rescheduled", rescheduleCount: 2)
        let activeOptions: [IntentionOption] = [.bhag]

        XCTAssertFalse(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: once),
            "Task rescheduled 1x should NOT pass BHAG filter (threshold is 2)"
        )
        XCTAssertTrue(
            IntentionOption.matchesFilter(activeOptions: activeOptions, task: twice),
            "Task rescheduled 2x should pass BHAG filter"
        )
    }
}
