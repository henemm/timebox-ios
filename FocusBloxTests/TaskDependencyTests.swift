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

    // MARK: - DEP-1: completeTask clears blockerTaskID on dependents

    func test_completeTask_clearsDependentsBlockerTaskID() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let blocker = LocalTask(title: "Blocker")
        let dep1 = LocalTask(title: "Dep 1")
        let dep2 = LocalTask(title: "Dep 2")
        context.insert(blocker)
        context.insert(dep1)
        context.insert(dep2)
        dep1.blockerTaskID = blocker.id
        dep2.blockerTaskID = blocker.id
        try context.save()

        // Complete the blocker
        try syncEngine.completeTask(itemID: blocker.id)

        XCTAssertNil(dep1.blockerTaskID,
                     "DEP-1: Completing blocker must clear blockerTaskID on dependents")
        XCTAssertNil(dep2.blockerTaskID,
                     "DEP-1: All dependents must be freed when blocker is completed")
        XCTAssertTrue(blocker.isCompleted)
    }

    // MARK: - DEP-2: deleteTask clears blockerTaskID on dependents

    func test_deleteTask_clearsDependentsBlockerTaskID() throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let blocker = LocalTask(title: "Blocker")
        let dep = LocalTask(title: "Dependent")
        context.insert(blocker)
        context.insert(dep)
        dep.blockerTaskID = blocker.id
        try context.save()

        let blockerID = blocker.id

        // Delete the blocker
        try syncEngine.deleteTask(itemID: blockerID)

        XCTAssertNil(dep.blockerTaskID,
                     "DEP-2: Deleting blocker must clear blockerTaskID on dependents")
    }

    // MARK: - DEP-3: PlanItem.priorityScore includes dependentTaskCount

    func test_planItem_priorityScore_includesBlockerBonus() throws {
        let blocker = LocalTask(title: "Blocker", importance: 1)
        let dep1 = LocalTask(title: "Dep 1")
        let dep2 = LocalTask(title: "Dep 2")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dep1)
        container.mainContext.insert(dep2)
        dep1.blockerTaskID = blocker.id
        dep2.blockerTaskID = blocker.id

        let allItems = [blocker, dep1, dep2].map { PlanItem(localTask: $0) }
        let blockerItem = allItems.first { $0.id == blocker.id }!
        let dependentCount = allItems.dependents(of: blockerItem.id).count

        let scoreWithBonus = TaskPriorityScoringService.calculateScore(
            importance: blockerItem.importance,
            urgency: blockerItem.urgency,
            dueDate: blockerItem.dueDate,
            createdAt: blockerItem.createdAt,
            rescheduleCount: blockerItem.rescheduleCount,
            estimatedDuration: blockerItem.estimatedDuration,
            taskType: blockerItem.taskType,
            isNextUp: blockerItem.isNextUp,
            dependentTaskCount: dependentCount
        )

        let scoreWithout = TaskPriorityScoringService.calculateScore(
            importance: blockerItem.importance,
            urgency: blockerItem.urgency,
            dueDate: blockerItem.dueDate,
            createdAt: blockerItem.createdAt,
            rescheduleCount: blockerItem.rescheduleCount,
            estimatedDuration: blockerItem.estimatedDuration,
            taskType: blockerItem.taskType,
            isNextUp: blockerItem.isNextUp,
            dependentTaskCount: 0
        )

        XCTAssertGreaterThan(scoreWithBonus, scoreWithout,
                             "DEP-3: Blocker with 2 dependents must have higher score than without")
        XCTAssertEqual(scoreWithBonus - scoreWithout, 6,
                       "DEP-3: 2 dependents should add +6 to score")
    }

    // MARK: - DEP-3b: populateDependentCounts wires through priorityScore

    func test_populateDependentCounts_boostsPriorityScore() throws {
        let blocker = LocalTask(title: "Blocker", importance: 1)
        let dep1 = LocalTask(title: "Dep 1")
        let dep2 = LocalTask(title: "Dep 2")
        let free = LocalTask(title: "Free")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dep1)
        container.mainContext.insert(dep2)
        container.mainContext.insert(free)
        dep1.blockerTaskID = blocker.id
        dep2.blockerTaskID = blocker.id

        // Before populateDependentCounts: dependentCount defaults to 0
        var items = [blocker, dep1, dep2, free].map { PlanItem(localTask: $0) }
        let scoreBefore = items.first { $0.id == blocker.id }!.priorityScore

        // After populateDependentCounts: blocker gets +6 (2 deps * 3)
        items.populateDependentCounts()
        let scoreAfter = items.first { $0.id == blocker.id }!.priorityScore
        let freeScore = items.first { $0.id == free.id }!

        XCTAssertEqual(scoreAfter - scoreBefore, 6,
                       "DEP-3b: populateDependentCounts must boost priorityScore by +6 for 2 dependents")
        XCTAssertEqual(freeScore.dependentCount, 0,
                       "Free task should have 0 dependents")
    }

    // MARK: - DEP-4: Blocked tasks excluded from actionable lists

    func test_nextUpActionableTasks_excludesBlockedTasks() throws {
        let blocker = LocalTask(title: "Blocker Task")
        let blocked = LocalTask(title: "Blocked Task")
        let freeNextUp = LocalTask(title: "Free Next Up")
        container.mainContext.insert(blocker)
        container.mainContext.insert(blocked)
        container.mainContext.insert(freeNextUp)

        blocked.blockerTaskID = blocker.id
        blocked.isNextUp = true
        freeNextUp.isNextUp = true

        let items = [blocker, blocked, freeNextUp].map { PlanItem(localTask: $0) }

        let actionable = items.nextUpActionableTasks

        XCTAssertEqual(actionable.count, 1,
                       "DEP-4: Blocked tasks must be excluded from Next Up actionable list")
        XCTAssertEqual(actionable.first?.title, "Free Next Up")
    }

    func test_nextUpActionableTasks_excludesCompletedAndTemplates() throws {
        let completed = LocalTask(title: "Done")
        let template = LocalTask(title: "Template")
        let active = LocalTask(title: "Active")
        container.mainContext.insert(completed)
        container.mainContext.insert(template)
        container.mainContext.insert(active)

        completed.isNextUp = true
        completed.isCompleted = true
        template.isNextUp = true
        template.isTemplate = true
        active.isNextUp = true

        let items = [completed, template, active].map { PlanItem(localTask: $0) }

        let actionable = items.nextUpActionableTasks

        XCTAssertEqual(actionable.count, 1,
                       "DEP-4: Completed and template tasks must be excluded from Next Up")
        XCTAssertEqual(actionable.first?.title, "Active")
    }

    func test_assignableTasks_excludesBlockedTasks() throws {
        let blocker = LocalTask(title: "Blocker")
        let blocked = LocalTask(title: "Blocked")
        let free = LocalTask(title: "Free Task")
        container.mainContext.insert(blocker)
        container.mainContext.insert(blocked)
        container.mainContext.insert(free)

        blocked.blockerTaskID = blocker.id

        let items = [blocker, blocked, free].map { PlanItem(localTask: $0) }

        let assignable = items.assignableToFocusBlock

        XCTAssertFalse(assignable.contains { $0.title == "Blocked" },
                       "DEP-4: Blocked tasks must not be assignable to FocusBlocks")
        XCTAssertTrue(assignable.contains { $0.title == "Free Task" },
                      "Free tasks should be assignable")
        XCTAssertTrue(assignable.contains { $0.title == "Blocker" },
                      "Blocker tasks should be assignable")
    }

    func test_isActionable_falseWhenBlocked() throws {
        let blocker = LocalTask(title: "Blocker")
        let blocked = LocalTask(title: "Blocked")
        container.mainContext.insert(blocker)
        container.mainContext.insert(blocked)

        blocked.blockerTaskID = blocker.id

        let blockedItem = PlanItem(localTask: blocked)
        let blockerItem = PlanItem(localTask: blocker)

        XCTAssertFalse(blockedItem.isActionable,
                       "DEP-4: Blocked task must not be actionable")
        XCTAssertTrue(blockerItem.isActionable,
                      "Blocker task itself should be actionable")
    }

    // MARK: - DEP-5: Transitive circularity detection

    func test_wouldCreateCycle_directCycle_detected() throws {
        // A blocks B. Setting B as blocker of A should be detected.
        let a = LocalTask(title: "A")
        let b = LocalTask(title: "B")
        container.mainContext.insert(a)
        container.mainContext.insert(b)

        b.blockerTaskID = a.id  // A → B

        let allTasks = [a, b]

        // If we try to set A.blockerTaskID = B.id → B→A cycle
        XCTAssertTrue(
            LocalTask.wouldCreateCycle(settingBlocker: b.id, on: a.id, allTasks: allTasks),
            "DEP-5: Direct cycle A→B→A must be detected"
        )
    }

    func test_wouldCreateCycle_transitiveCycle_detected() throws {
        // A → B → C. Setting C as blocker of A should be detected.
        let a = LocalTask(title: "A")
        let b = LocalTask(title: "B")
        let c = LocalTask(title: "C")
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(c)

        b.blockerTaskID = a.id  // A → B
        c.blockerTaskID = b.id  // B → C

        let allTasks = [a, b, c]

        // If we try to set A.blockerTaskID = C.id → C→B→A→C cycle
        XCTAssertTrue(
            LocalTask.wouldCreateCycle(settingBlocker: c.id, on: a.id, allTasks: allTasks),
            "DEP-5: 3-way cycle A→B→C→A must be detected"
        )
    }

    func test_wouldCreateCycle_noCycle_allowed() throws {
        // A → B. Setting C as blocker of A is fine (no cycle).
        let a = LocalTask(title: "A")
        let b = LocalTask(title: "B")
        let c = LocalTask(title: "C")
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        container.mainContext.insert(c)

        b.blockerTaskID = a.id  // A → B

        let allTasks = [a, b, c]

        XCTAssertFalse(
            LocalTask.wouldCreateCycle(settingBlocker: c.id, on: a.id, allTasks: allTasks),
            "DEP-5: Non-cyclic dependency should be allowed"
        )
    }

    func test_wouldCreateCycle_selfBlock_detected() throws {
        let a = LocalTask(title: "A")
        container.mainContext.insert(a)

        XCTAssertTrue(
            LocalTask.wouldCreateCycle(settingBlocker: a.id, on: a.id, allTasks: [a]),
            "DEP-5: Self-blocking must be detected"
        )
    }

    // MARK: - DEP-4b: Blocked tasks cannot be completed via alternative paths

    func test_syncEngine_completeTask_rejectsBlockedTask() throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let blocker = LocalTask(title: "Blocker")
        let blocked = LocalTask(title: "Blocked")
        context.insert(blocker)
        context.insert(blocked)
        blocked.blockerTaskID = blocker.id
        try context.save()

        // Try to complete the blocked task — should be rejected
        try syncEngine.completeTask(itemID: blocked.id)

        XCTAssertFalse(blocked.isCompleted,
                       "DEP-4b: SyncEngine must reject completion of blocked tasks")
    }

    func test_syncEngine_completeTask_allowsUnblockedTask() throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let task = LocalTask(title: "Free Task")
        context.insert(task)
        try context.save()

        try syncEngine.completeTask(itemID: task.id)

        XCTAssertTrue(task.isCompleted,
                      "DEP-4b: Unblocked tasks must remain completable")
    }

    func test_notificationDelegate_rejectsBlockedCompletion() throws {
        let blocker = LocalTask(title: "Blocker")
        let blocked = LocalTask(title: "Blocked")
        container.mainContext.insert(blocker)
        container.mainContext.insert(blocked)
        blocked.blockerTaskID = blocker.id
        try container.mainContext.save()

        let delegate = NotificationActionDelegate(container: container)
        delegate.handleActionForTesting(NotificationService.actionComplete, taskID: blocked.id)

        XCTAssertFalse(blocked.isCompleted,
                       "DEP-4b: Notification action must not complete blocked tasks")
    }

    func test_notificationDelegate_freesDependentsOnCompletion() throws {
        let blocker = LocalTask(title: "Blocker")
        let dep = LocalTask(title: "Dependent")
        container.mainContext.insert(blocker)
        container.mainContext.insert(dep)
        dep.blockerTaskID = blocker.id
        try container.mainContext.save()

        let delegate = NotificationActionDelegate(container: container)
        delegate.handleActionForTesting(NotificationService.actionComplete, taskID: blocker.id)

        XCTAssertNil(dep.blockerTaskID,
                     "DEP-4b: Notification completion must free dependents (missing freeDependents)")
    }
}
