import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests for Next Up Staging Area
/// These tests MUST FAIL initially because isNextUp property doesn't exist yet
@MainActor
final class NextUpTests: XCTestCase {

    var container: ModelContainer!
    var source: LocalTaskSource!
    var syncEngine: SyncEngine!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        source = LocalTaskSource(modelContext: container.mainContext)
        syncEngine = SyncEngine(taskSource: source, modelContext: container.mainContext)
    }

    override func tearDownWithError() throws {
        container = nil
        source = nil
        syncEngine = nil
    }

    // MARK: - LocalTask.isNextUp Tests

    /// Test: LocalTask.isNextUp should default to false
    /// GIVEN: A new LocalTask is created
    /// WHEN: No isNextUp value is explicitly set
    /// THEN: isNextUp should be false
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on LocalTask
    func test_localTask_isNextUp_defaultsFalse() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task", importance: 1)
        context.insert(task)

        // This line will fail to compile: 'isNextUp' is not a member of 'LocalTask'
        XCTAssertFalse(task.isNextUp, "isNextUp should default to false")
    }

    /// Test: LocalTask.isNextUp can be set to true
    /// GIVEN: A LocalTask exists
    /// WHEN: isNextUp is set to true
    /// THEN: isNextUp should be true
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on LocalTask
    func test_localTask_isNextUp_canBeSetToTrue() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Next Up Task", importance: 2)
        context.insert(task)

        task.isNextUp = true
        try context.save()

        XCTAssertTrue(task.isNextUp, "isNextUp should be true after setting")
    }

    /// Test: LocalTask.isNextUp persists after save
    /// GIVEN: A LocalTask with isNextUp = true
    /// WHEN: Context is saved and task is refetched
    /// THEN: isNextUp should still be true
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on LocalTask
    func test_localTask_isNextUp_persistsAfterSave() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Persistent Task", importance: 1)
        task.isNextUp = true
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<LocalTask>()
        let tasks = try context.fetch(descriptor)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks.first?.isNextUp ?? false, "isNextUp should persist")
    }

    // MARK: - PlanItem.isNextUp Tests

    /// Test: PlanItem should preserve isNextUp from LocalTask
    /// GIVEN: A LocalTask with isNextUp = true
    /// WHEN: PlanItem is created from LocalTask
    /// THEN: PlanItem.isNextUp should be true
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on PlanItem
    func test_planItem_preservesIsNextUp_true() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Next Up Task", importance: 2)
        task.isNextUp = true
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertTrue(planItem.isNextUp, "PlanItem should preserve isNextUp=true from LocalTask")
    }

    /// Test: PlanItem should preserve isNextUp = false from LocalTask
    /// GIVEN: A LocalTask with isNextUp = false (default)
    /// WHEN: PlanItem is created from LocalTask
    /// THEN: PlanItem.isNextUp should be false
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on PlanItem
    func test_planItem_preservesIsNextUp_false() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Regular Task", importance: 1)
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertFalse(planItem.isNextUp, "PlanItem should preserve isNextUp=false from LocalTask")
    }

    // MARK: - SyncEngine.updateNextUp Tests

    /// Test: SyncEngine.updateNextUp should set isNextUp to true
    /// GIVEN: A task with isNextUp = false
    /// WHEN: updateNextUp(itemID, isNextUp: true) is called
    /// THEN: Task.isNextUp should be true
    ///
    /// EXPECTED TO FAIL: Method updateNextUp does not exist on SyncEngine
    func test_syncEngine_updateNextUp_setsTrue() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 1)
        context.insert(task)
        try context.save()

        // This line will fail: 'updateNextUp' is not a member of 'SyncEngine'
        try syncEngine.updateNextUp(itemID: task.id, isNextUp: true)

        XCTAssertTrue(task.isNextUp, "Task.isNextUp should be true after updateNextUp")
    }

    /// Test: SyncEngine.updateNextUp should set isNextUp to false
    /// GIVEN: A task with isNextUp = true
    /// WHEN: updateNextUp(itemID, isNextUp: false) is called
    /// THEN: Task.isNextUp should be false
    ///
    /// EXPECTED TO FAIL: Method updateNextUp does not exist on SyncEngine
    func test_syncEngine_updateNextUp_setsFalse() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 1)
        task.isNextUp = true
        context.insert(task)
        try context.save()

        try syncEngine.updateNextUp(itemID: task.id, isNextUp: false)

        XCTAssertFalse(task.isNextUp, "Task.isNextUp should be false after updateNextUp")
    }

    /// Test: SyncEngine.updateNextUp with invalid ID should not crash
    /// GIVEN: No task with given ID exists
    /// WHEN: updateNextUp is called with invalid ID
    /// THEN: Should not crash, should return gracefully
    ///
    /// EXPECTED TO FAIL: Method updateNextUp does not exist on SyncEngine
    func test_syncEngine_updateNextUp_invalidID_doesNotCrash() throws {
        // This line will fail: 'updateNextUp' is not a member of 'SyncEngine'
        try syncEngine.updateNextUp(itemID: "invalid-uuid", isNextUp: true)
        // No crash = success
    }

    // MARK: - Fetch Next Up Tasks Tests

    /// Test: Can fetch only tasks with isNextUp = true
    /// GIVEN: Multiple tasks, some with isNextUp = true
    /// WHEN: Fetching with predicate for isNextUp
    /// THEN: Only isNextUp tasks should be returned
    ///
    /// EXPECTED TO FAIL: Property isNextUp does not exist on LocalTask
    func test_fetch_onlyNextUpTasks() throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Next Up 1", importance: 1)
        task1.isNextUp = true
        let task2 = LocalTask(title: "Regular", importance: 1)
        task2.isNextUp = false
        let task3 = LocalTask(title: "Next Up 2", importance: 2)
        task3.isNextUp = true

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isNextUp == true }
        )
        let nextUpTasks = try context.fetch(descriptor)

        XCTAssertEqual(nextUpTasks.count, 2, "Should only return tasks with isNextUp=true")
        XCTAssertTrue(nextUpTasks.allSatisfy { $0.isNextUp }, "All returned tasks should have isNextUp=true")
    }

    // MARK: - Bugfix Tests: Filter Exclusion

    /// Test: Backlog filter should EXCLUDE tasks with isNextUp=true
    /// GIVEN: Tasks where some have isNextUp=true
    /// WHEN: Filtering for backlog (like BacklogView.backlogTasks)
    /// THEN: isNextUp tasks should NOT be included
    ///
    /// EXPECTED TO FAIL: Current filter doesn't exclude isNextUp
    func test_backlogFilter_excludesNextUpTasks() throws {
        let context = container.mainContext

        let regularTask = LocalTask(title: "Regular Task", importance: 1)
        regularTask.isNextUp = false
        regularTask.isCompleted = false

        let nextUpTask = LocalTask(title: "Next Up Task", importance: 2)
        nextUpTask.isNextUp = true
        nextUpTask.isCompleted = false

        context.insert(regularTask)
        context.insert(nextUpTask)
        try context.save()

        // Simulate BacklogView.backlogTasks filter: !isCompleted && !isNextUp
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let backlogTasks = allTasks.filter { !$0.isCompleted && !$0.isNextUp }

        XCTAssertEqual(backlogTasks.count, 1, "Backlog should only contain non-NextUp tasks")
        XCTAssertEqual(backlogTasks.first?.title, "Regular Task")
        XCTAssertFalse(backlogTasks.contains { $0.isNextUp }, "Backlog should NOT contain isNextUp tasks")
    }

    /// Test: Eisenhower "Do First" filter should EXCLUDE tasks with isNextUp=true
    /// GIVEN: Urgent+Important tasks where some have isNextUp=true
    /// WHEN: Filtering for doFirst quadrant
    /// THEN: isNextUp tasks should NOT be included
    ///
    /// EXPECTED TO FAIL: Current filter doesn't exclude isNextUp
    func test_doFirstFilter_excludesNextUpTasks() throws {
        let context = container.mainContext

        // Regular urgent+important task
        let regularTask = LocalTask(title: "Regular Urgent", importance: 3)
        regularTask.urgency = "urgent"
        regularTask.isNextUp = false
        regularTask.isCompleted = false

        // Next Up urgent+important task (should be excluded from quadrant)
        let nextUpTask = LocalTask(title: "Next Up Urgent", importance: 3)
        nextUpTask.urgency = "urgent"
        nextUpTask.isNextUp = true
        nextUpTask.isCompleted = false

        context.insert(regularTask)
        context.insert(nextUpTask)
        try context.save()

        // Simulate BacklogView.doFirstTasks filter: urgent && priority==3 && !isCompleted && !isNextUp
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let doFirstTasks = allTasks.filter {
            $0.urgency == "urgent" && $0.importance == 3 && !$0.isCompleted && !$0.isNextUp
        }

        XCTAssertEqual(doFirstTasks.count, 1, "Do First should only contain non-NextUp tasks")
        XCTAssertEqual(doFirstTasks.first?.title, "Regular Urgent")
        XCTAssertFalse(doFirstTasks.contains { $0.isNextUp }, "Do First should NOT contain isNextUp tasks")
    }
}
