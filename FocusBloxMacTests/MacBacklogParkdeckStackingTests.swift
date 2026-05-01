import XCTest
@testable import FocusBloxMac

/// Unit Tests for MAC_028: Parkdeck filtering + Stacking grouping logic.
/// These test the pure business logic that will be added to ContentView.
///
/// TDD RED: All tests MUST FAIL because the functions don't exist yet.
@MainActor
final class MacBacklogParkdeckStackingTests: XCTestCase {

    // MARK: - Parkdeck Filter Tests

    /// Verhalten: isParked tasks must be classified as parkdeck, not active.
    /// Bricht wenn: ContentView.isInParkdeck() function missing or wrong logic.
    func test_parkedTask_isClassifiedAsParkdeck() {
        let task = LocalTask(title: "Parked Task", importance: 3)
        task.isParked = true

        // The function we'll implement: classifies task as parkdeck or active
        let result = MacBacklogFilterHelper.isInParkdeck(
            task: task,
            score: TaskPriorityScoringService.calculateScore(
                importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
                createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
                estimatedDuration: task.estimatedDuration, taskType: task.taskType,
                isNextUp: task.isNextUp, dependentTaskCount: 0
            )
        )

        XCTAssertTrue(result, "isParked task must be in parkdeck regardless of tier")
    }

    /// RW 2.4b: Low-Tier-Task OHNE isParked ist NICHT geparkt — er landet in "Später"
    /// Bricht wenn: MacBacklogFilterHelper.isInParkdeck() noch Tier-Check enthält (alte Logik)
    func test_lowTierTask_notParked_isNotClassifiedAsParkdeck() {
        let task = LocalTask(title: "Low Priority", importance: 1)
        task.isParked = false

        let score = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp, dependentTaskCount: 0
        )

        let result = MacBacklogFilterHelper.isInParkdeck(task: task, score: score)
        // NEU: Low-Score allein macht NICHT geparkt
        XCTAssertFalse(result, "Low-tier task without isParked must NOT be in parkdeck")
    }

    /// Verhalten: doNow/planSoon tasks that are NOT parked stay in active list.
    /// Bricht wenn: MacBacklogFilterHelper.isInParkdeck() incorrectly classifies active tasks.
    func test_highTierUnparkedTask_isNotInParkdeck() {
        let task = LocalTask(title: "Urgent Task", importance: 3)
        task.urgency = "urgent"
        task.isParked = false

        let score = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp, dependentTaskCount: 0
        )

        let result = MacBacklogFilterHelper.isInParkdeck(task: task, score: score)
        XCTAssertFalse(result, "High-tier unparked task must NOT be in parkdeck")
    }

    // MARK: - Stacking Grouping Tests

    /// Verhalten: 3 tasks with same recurrenceGroupID produce 1 representative with stackedCount=2.
    /// Bricht wenn: MacBacklogStackingHelper.applyStacking() missing or wrong grouping.
    func test_stackingGroups_threeInstancesIntoOneRepresentative() {
        let groupID = "recurring-group-1"
        let task1 = LocalTask(title: "Instance 1", importance: 3)
        task1.recurrenceGroupID = groupID
        task1.dueDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())

        let task2 = LocalTask(title: "Instance 2", importance: 3)
        task2.recurrenceGroupID = groupID
        task2.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())

        let task3 = LocalTask(title: "Instance 3", importance: 3)
        task3.recurrenceGroupID = groupID
        task3.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let result = MacBacklogStackingHelper.applyStacking([task1, task2, task3])

        XCTAssertEqual(result.count, 1, "3 instances of same group should produce 1 representative")
        XCTAssertEqual(result.first?.stackedCount, 2, "Representative should have stackedCount = totalInstances - 1 = 2")
    }

    /// Verhalten (Bug `bug-recurring-stack-count-badge`):
    /// Representative ist das JUENGSTE Child (groesstes dueDate). So bleibt der
    /// "aktuelle" Eintrag in der Sektion sichtbar; oldestDueDate liefert das
    /// aelteste dueDate fuer die Counter-Bar.
    /// Bricht wenn: applyStacking() das aelteste statt das juengste Child waehlt.
    func test_stackingRepresentative_isYoungestByDueDate() {
        let groupID = "recurring-group-2"
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let oldTask = LocalTask(title: "Old Instance", importance: 3)
        oldTask.recurrenceGroupID = groupID
        oldTask.dueDate = oldDate

        let newTask = LocalTask(title: "New Instance", importance: 3)
        newTask.recurrenceGroupID = groupID
        newTask.dueDate = newDate

        // Pass in reverse order to prove sorting works
        let result = MacBacklogStackingHelper.applyStacking([oldTask, newTask])

        XCTAssertEqual(result.first?.task.title, "New Instance",
                       "Representative muss das juengste Child sein (groesstes dueDate)")
        XCTAssertEqual(result.first?.oldestDueDate, oldDate,
                       "oldestDueDate muss das aelteste dueDate der Gruppe sein")
    }

    /// Verhalten: Tasks without recurrenceGroupID are passed through ungrouped.
    /// Bricht wenn: applyStacking() incorrectly filters out non-recurring tasks.
    func test_stackingPreservesNonRecurringTasks() {
        let normalTask = LocalTask(title: "Normal Task", importance: 3)
        // No recurrenceGroupID set

        let result = MacBacklogStackingHelper.applyStacking([normalTask])

        XCTAssertEqual(result.count, 1, "Non-recurring task should pass through unchanged")
        XCTAssertEqual(result.first?.stackedCount, 0, "Non-recurring task has stackedCount 0")
    }

    /// Verhalten: Mixed recurring + non-recurring tasks are correctly separated.
    /// Bricht wenn: applyStacking() mixes grouped and ungrouped logic.
    func test_stackingMixedRecurringAndNormal() {
        let groupID = "group-mix"
        let recurring1 = LocalTask(title: "Recurring 1", importance: 3)
        recurring1.recurrenceGroupID = groupID
        recurring1.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())

        let recurring2 = LocalTask(title: "Recurring 2", importance: 3)
        recurring2.recurrenceGroupID = groupID
        recurring2.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let normal = LocalTask(title: "Normal", importance: 3)

        let result = MacBacklogStackingHelper.applyStacking([recurring1, recurring2, normal])

        // Should be 2 items: 1 representative + 1 normal
        XCTAssertEqual(result.count, 2, "Should have 1 stacked representative + 1 normal task")
    }

    /// Verhalten: Different recurrenceGroupIDs produce separate groups.
    /// Bricht wenn: applyStacking() groups by wrong key.
    func test_stackingDifferentGroupsStaySeparate() {
        let task1a = LocalTask(title: "Group A Instance 1", importance: 3)
        task1a.recurrenceGroupID = "group-A"
        task1a.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())

        let task1b = LocalTask(title: "Group A Instance 2", importance: 3)
        task1b.recurrenceGroupID = "group-A"
        task1b.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let task2a = LocalTask(title: "Group B Instance 1", importance: 3)
        task2a.recurrenceGroupID = "group-B"
        task2a.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())

        let result = MacBacklogStackingHelper.applyStacking([task1a, task1b, task2a])

        // Group A → 1 representative (stackedCount=1), Group B → 1 solo (stackedCount=0)
        XCTAssertEqual(result.count, 2, "Two different groups should produce 2 representatives")
    }
}
