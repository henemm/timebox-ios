import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskDependencyTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - LocalTask: blockerTaskID Property

    func test_localTask_blockerTaskID_defaultsToNil() throws {
        let task = LocalTask(title: "Blocked Task")
        container.mainContext.insert(task)

        XCTAssertNil(task.blockerTaskID, "New tasks should have no blocker by default")
    }

    func test_localTask_blockerTaskID_canBeSet() throws {
        let blocker = LocalTask(title: "Blocker Task")
        let dependent = LocalTask(title: "Dependent Task")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dependent)

        dependent.blockerTaskID = blocker.id

        XCTAssertEqual(dependent.blockerTaskID, blocker.id)
    }

    // MARK: - PlanItem: blockerTaskID + isBlocked

    func test_planItem_blockerTaskID_copiedFromLocalTask() throws {
        let blocker = LocalTask(title: "Blocker")
        let dependent = LocalTask(title: "Dependent")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dependent)
        dependent.blockerTaskID = blocker.id

        let planItem = PlanItem(localTask: dependent)

        XCTAssertEqual(planItem.blockerTaskID, blocker.id,
                       "PlanItem should carry over blockerTaskID from LocalTask")
    }

    func test_planItem_isBlocked_trueWhenBlockerSet() throws {
        let blocker = LocalTask(title: "Blocker")
        let dependent = LocalTask(title: "Dependent")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dependent)
        dependent.blockerTaskID = blocker.id

        let planItem = PlanItem(localTask: dependent)

        XCTAssertTrue(planItem.isBlocked,
                      "Task with a blockerTaskID should report isBlocked = true")
    }

    func test_planItem_isBlocked_falseWhenNoBlocker() throws {
        let task = LocalTask(title: "Free Task")
        container.mainContext.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertFalse(planItem.isBlocked,
                       "Task without blockerTaskID should report isBlocked = false")
    }

    // MARK: - TaskPriorityScoringService: Blocker Bonus

    func test_scoring_blockerBonus_zeroWhenNoDependents() {
        let score = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "urgent",
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false,
            dependentTaskCount: 0
        )

        let scoreWithout = TaskPriorityScoringService.calculateScore(
            importance: 2,
            urgency: "urgent",
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false
        )

        XCTAssertEqual(score, scoreWithout,
                       "Zero dependents should produce same score as no parameter")
    }

    func test_scoring_blockerBonus_addsThreePerDependent() {
        let baseScore = TaskPriorityScoringService.calculateScore(
            importance: nil,
            urgency: nil,
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false,
            dependentTaskCount: 0
        )

        let scoreWith2 = TaskPriorityScoringService.calculateScore(
            importance: nil,
            urgency: nil,
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false,
            dependentTaskCount: 2
        )

        XCTAssertEqual(scoreWith2, baseScore + 6,
                       "Each dependent task should add +3 to the score")
    }

    func test_scoring_blockerBonus_cappedAtNine() {
        let scoreWith3 = TaskPriorityScoringService.calculateScore(
            importance: nil,
            urgency: nil,
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false,
            dependentTaskCount: 3
        )

        let scoreWith5 = TaskPriorityScoringService.calculateScore(
            importance: nil,
            urgency: nil,
            dueDate: nil,
            createdAt: Date(),
            rescheduleCount: 0,
            estimatedDuration: nil,
            taskType: "",
            isNextUp: false,
            dependentTaskCount: 5
        )

        XCTAssertEqual(scoreWith3, scoreWith5,
                       "Blocker bonus should be capped at +9 (3 dependents max)")
    }

    func test_scoring_blockerBonus_respectsMaxScore100() {
        // High base score + blocker bonus should not exceed 100
        let score = TaskPriorityScoringService.calculateScore(
            importance: 3,
            urgency: "urgent",
            dueDate: Date(), // today = +25
            createdAt: Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
            rescheduleCount: 10,
            estimatedDuration: 30,
            taskType: "income",
            isNextUp: true,
            dependentTaskCount: 3
        )

        XCTAssertLessThanOrEqual(score, 100,
                                  "Score should never exceed 100 even with blocker bonus")
    }
}
