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

    // MARK: - Grouping: tasksWithDependents

    func test_grouping_blockedTasksExcludedFromTopLevel() throws {
        let blocker = LocalTask(title: "Blocker")
        let dependent = LocalTask(title: "Dependent")
        let free = LocalTask(title: "Free")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dependent)
        container.mainContext.insert(free)
        dependent.blockerTaskID = blocker.id

        let items = [blocker, dependent, free].map { PlanItem(localTask: $0) }
        let topLevel = items.topLevelTasks

        XCTAssertEqual(topLevel.count, 2, "Blocked tasks should not appear in top-level")
        XCTAssertTrue(topLevel.contains(where: { $0.id == blocker.id }))
        XCTAssertTrue(topLevel.contains(where: { $0.id == free.id }))
        XCTAssertFalse(topLevel.contains(where: { $0.id == dependent.id }))
    }

    func test_grouping_dependentsForBlocker() throws {
        let blocker = LocalTask(title: "Blocker")
        let dep1 = LocalTask(title: "Dep 1")
        let dep2 = LocalTask(title: "Dep 2")
        let free = LocalTask(title: "Free")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dep1)
        container.mainContext.insert(dep2)
        container.mainContext.insert(free)
        dep1.blockerTaskID = blocker.id
        dep2.blockerTaskID = blocker.id

        let items = [blocker, dep1, dep2, free].map { PlanItem(localTask: $0) }
        let dependents = items.dependents(of: blocker.id)

        XCTAssertEqual(dependents.count, 2, "Should find 2 dependents for blocker")
        XCTAssertTrue(dependents.contains(where: { $0.id == dep1.id }))
        XCTAssertTrue(dependents.contains(where: { $0.id == dep2.id }))
    }

    func test_grouping_noDependentsForFreeTask() throws {
        let free1 = LocalTask(title: "Free 1")
        let free2 = LocalTask(title: "Free 2")
        container.mainContext.insert(free1)
        container.mainContext.insert(free2)

        let items = [free1, free2].map { PlanItem(localTask: $0) }
        let dependents = items.dependents(of: free1.id)

        XCTAssertTrue(dependents.isEmpty, "Free task should have no dependents")
    }

    // MARK: - Phase 3: createTask with blockerTaskID

    func test_createTask_withBlockerTaskID_setsBlocker() async throws {
        let context = container.mainContext
        let blocker = LocalTask(title: "Blocker Task")
        context.insert(blocker)
        try context.save()

        let source = LocalTaskSource(modelContext: context)
        let dependent = try await source.createTask(
            title: "Dependent Task",
            blockerTaskID: blocker.id
        )

        XCTAssertEqual(dependent.blockerTaskID, blocker.id,
                       "createTask with blockerTaskID should set the dependency")
    }

    func test_createTask_withoutBlockerTaskID_hasNilBlocker() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let task = try await source.createTask(title: "Free Task")

        XCTAssertNil(task.blockerTaskID,
                     "createTask without blockerTaskID should default to nil")
    }

    // MARK: - Score cap

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
