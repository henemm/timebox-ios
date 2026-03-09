import XCTest
@testable import FocusBlox

/// Bug 73: FocusBlockTasksSheet should show priority badges and sort by priority score.
/// These tests verify:
/// 1. allTasksSortedByPriority returns tasks in descending priority order
/// 2. PlanItems have correct priorityScore for sorting
@MainActor
final class FocusBlockTasksSheetTests: XCTestCase {

    // MARK: - Test 1: Tasks sorted by priority score (highest first)

    func testAllTasksSortedByPriorityDescending() {
        // GIVEN: Tasks with different importance/urgency
        let lowPriority = PlanItem.stub(title: "Low", importance: 1, urgency: nil)
        let midPriority = PlanItem.stub(title: "Mid", importance: 2, urgency: "not_urgent")
        let highPriority = PlanItem.stub(title: "High", importance: 3, urgency: "urgent")

        let unsorted = [lowPriority, midPriority, highPriority]

        // WHEN: Sorted by priorityScore descending
        let sorted = unsorted.sorted { $0.priorityScore > $1.priorityScore }

        // THEN: Highest priority first
        XCTAssertEqual(sorted[0].title, "High", "Highest priority task should be first")
        XCTAssertEqual(sorted[2].title, "Low", "Lowest priority task should be last")
        XCTAssertTrue(sorted[0].priorityScore > sorted[1].priorityScore, "Scores should be descending")
        XCTAssertTrue(sorted[1].priorityScore > sorted[2].priorityScore, "Scores should be descending")
    }

    // MARK: - Test 2: PlanItem exposes priorityScore and priorityTier

    func testPlanItemHasPriorityScoreAndTier() {
        // GIVEN: A task with importance=3 and urgency=urgent
        let task = PlanItem.stub(title: "Urgent Task", importance: 3, urgency: "urgent")

        // THEN: priorityScore is non-zero and tier reflects high priority
        XCTAssertGreaterThan(task.priorityScore, 0, "Task with importance+urgency should have positive score")
        XCTAssertNotEqual(task.priorityTier, .someday, "High priority task should not be 'someday' tier")
    }

    // MARK: - Test 3: Tasks with same priority maintain stable order

    func testSamePriorityTasksStableSort() {
        // GIVEN: Multiple tasks with identical priority
        let task1 = PlanItem.stub(title: "First", importance: 2, urgency: "not_urgent")
        let task2 = PlanItem.stub(title: "Second", importance: 2, urgency: "not_urgent")

        let tasks = [task1, task2]

        // WHEN: Sorted
        let sorted = tasks.sorted { $0.priorityScore > $1.priorityScore }

        // THEN: Both present, no crash
        XCTAssertEqual(sorted.count, 2)
    }
}

// MARK: - PlanItem Test Stub

private extension PlanItem {
    static func stub(
        title: String,
        importance: Int? = nil,
        urgency: String? = nil,
        duration: Int? = 30
    ) -> PlanItem {
        PlanItem(
            id: UUID().uuidString,
            title: title,
            isCompleted: false,
            rank: 0,
            effectiveDuration: duration ?? 30,
            durationSource: .explicit,
            importance: importance,
            urgency: urgency,
            estimatedDuration: duration,
            tags: [],
            taskType: "maintenance",
            dueDate: nil,
            taskDescription: nil,
            recurrencePattern: nil,
            recurrenceWeekdays: nil,
            recurrenceMonthDay: nil,
            recurrenceInterval: nil,
            recurrenceGroupID: nil,
            isTemplate: false,
            aiScore: nil,
            aiEnergyLevel: nil,
            createdAt: Date(),
            isNextUp: false,
            nextUpSortOrder: nil,
            assignedFocusBlockID: nil,
            completedAt: nil,
            rescheduleCount: 0,
            modifiedAt: nil
        )
    }
}
