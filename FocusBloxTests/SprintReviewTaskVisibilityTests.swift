import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 43: Sprint Review shows 0 tasks because completed tasks are filtered out.
/// Tests verify that task lookup works AFTER marking tasks as completed.
@MainActor
final class SprintReviewTaskVisibilityTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - iOS: SyncEngine filters completed tasks

    /// GIVEN: 3 tasks assigned to a FocusBlock, 2 completed during focus session
    /// WHEN: SyncEngine.sync() is called (as loadData does)
    /// THEN: sync() should NOT find completed tasks → Sprint Review broken
    /// BUG: This is the CURRENT broken behavior we want to fix
    func testSyncEngineExcludesCompletedTasks() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let task1 = LocalTask(title: "Task A", importance: 2)
        let task2 = LocalTask(title: "Task B", importance: 2)
        let task3 = LocalTask(title: "Task C", importance: 2)

        // Simulate: tasks were completed during focus session
        task1.isCompleted = true
        task1.completedAt = Date()
        task2.isCompleted = true
        task2.completedAt = Date()

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let planItems = try await syncEngine.sync()

        // sync() only returns 1 task (the incomplete one) - broken for Sprint Review!
        XCTAssertEqual(planItems.count, 1, "sync() filtert erledigte Tasks - nur 1 von 3 gefunden")

        // Sprint Review needs ALL 3 tasks to show proper stats
        // This is what we need: a method that returns ALL tasks
        let allDescriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(allDescriptor)
        let allPlanItems = allTasks.map { PlanItem(localTask: $0) }

        XCTAssertEqual(allPlanItems.count, 3, "Ungefiltert sollten alle 3 Tasks da sein")

        // Simulate tasksForBlock lookup with all tasks
        let blockTaskIDs = [task1.id, task2.id, task3.id]
        let foundTasks = blockTaskIDs.compactMap { taskID in
            allPlanItems.first { $0.id == taskID }
        }
        XCTAssertEqual(foundTasks.count, 3, "Sprint Review muss alle 3 Tasks finden")
    }

    // MARK: - macOS: @Query filters completed tasks

    /// GIVEN: 4 tasks in SwiftData, all completed
    /// WHEN: Querying with !isCompleted predicate (as MacFocusView does)
    /// THEN: 0 tasks returned → Sprint Review empty
    func testFilteredQueryExcludesAllCompletedTasks() throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Task 1", importance: 1)
        let task2 = LocalTask(title: "Task 2", importance: 1)
        let task3 = LocalTask(title: "Task 3", importance: 1)
        let task4 = LocalTask(title: "Task 4", importance: 1)

        // All 4 completed during focus
        [task1, task2, task3, task4].forEach {
            $0.isCompleted = true
            $0.completedAt = Date()
            context.insert($0)
        }
        try context.save()

        // Simulate macOS @Query(filter: !isCompleted) - the broken behavior
        let filteredDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let filteredTasks = try context.fetch(filteredDescriptor)
        XCTAssertEqual(filteredTasks.count, 0, "Gefilterter Query findet 0 Tasks - Bug!")

        // Without filter - what Sprint Review needs
        let allDescriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(allDescriptor)
        XCTAssertEqual(allTasks.count, 4, "Ungefilterter Query findet alle 4 Tasks")

        // Simulate Sprint Review tasksForBlock lookup
        let blockTaskIDs = [task1.id, task2.id, task3.id, task4.id]
        let completedIDs = Set(blockTaskIDs) // All completed

        let foundForReview = blockTaskIDs.compactMap { id in
            allTasks.first { $0.id == id }
        }
        XCTAssertEqual(foundForReview.count, 4, "Sprint Review muss alle 4 Tasks zeigen")

        let completedCount = foundForReview.filter { completedIDs.contains($0.id) }.count
        XCTAssertEqual(completedCount, 4, "Alle 4 als erledigt erkannt")
    }

    // MARK: - SyncEngine.syncAllTasks should exist

    /// GIVEN: SyncEngine has sync() for incomplete and syncCompletedTasks() for completed
    /// WHEN: We need ALL tasks for Sprint Review
    /// THEN: A syncAllTasks() method should exist that returns everything
    func testSyncAllTasksMethodNeeded() async throws {
        let context = container.mainContext
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)

        let task1 = LocalTask(title: "Done", importance: 1)
        task1.isCompleted = true
        task1.completedAt = Date()

        let task2 = LocalTask(title: "Open", importance: 1)

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Current: sync() misses completed
        let incomplete = try await syncEngine.sync()
        XCTAssertEqual(incomplete.count, 1)

        // Needed: syncAllTasks() returns both - WILL FAIL until method exists
        let all = try await syncEngine.syncAllTasks()
        XCTAssertEqual(all.count, 2, "syncAllTasks() muss completed + incomplete liefern")
    }
}
