import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class SyncEngineTests: XCTestCase {

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

    // MARK: - Sync Tests

    func test_sync_returnsIncompleteTasks() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Task 1", importance: 0)
        let task2 = LocalTask(title: "Task 2", importance: 0)
        task2.isCompleted = true
        let task3 = LocalTask(title: "Task 3", importance: 0)

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let planItems = try await syncEngine.sync()

        XCTAssertEqual(planItems.count, 2)
        XCTAssertTrue(planItems.allSatisfy { !$0.isCompleted })
    }

    func test_sync_sortsByRank() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Third", importance: 0)
        task1.sortOrder = 2
        let task2 = LocalTask(title: "First", importance: 0)
        task2.sortOrder = 0
        let task3 = LocalTask(title: "Second", importance: 0)
        task3.sortOrder = 1

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        let planItems = try await syncEngine.sync()

        XCTAssertEqual(planItems[0].title, "First")
        XCTAssertEqual(planItems[1].title, "Second")
        XCTAssertEqual(planItems[2].title, "Third")
    }

    // MARK: - updateDuration Tests

    func test_updateDuration_setsManualDuration() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 0)
        context.insert(task)
        try context.save()

        try await syncEngine.updateDuration(itemID: task.id, minutes: 30)

        XCTAssertEqual(task.estimatedDuration, 30)
    }

    func test_updateDuration_resetsToNil() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 0)
        task.estimatedDuration = 30
        context.insert(task)
        try context.save()

        try await syncEngine.updateDuration(itemID: task.id, minutes: nil)

        XCTAssertNil(task.estimatedDuration)
    }

    func test_updateDuration_withInvalidID_doesNotCrash() async throws {
        try await syncEngine.updateDuration(itemID: "invalid-id", minutes: 15)
        // No crash = success
    }

    // MARK: - updateSortOrder Tests

    // MARK: - deleteRecurringSeries Tests (Ticket 2)

    /// Deleting a single recurring instance keeps other series members
    func test_deleteSingleInstance_keepsOthers() throws {
        let context = container.mainContext
        let groupID = "series-abc"

        let task1 = LocalTask(title: "Instance 1", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task2 = LocalTask(title: "Instance 2", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let task3 = LocalTask(title: "Instance 3", recurrencePattern: "daily", recurrenceGroupID: groupID)
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        // Delete only task2 (single instance)
        try syncEngine.deleteTask(itemID: task2.id)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(remaining.count, 2, "Only one instance should be deleted")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Instance 1" }))
        XCTAssertTrue(remaining.contains(where: { $0.title == "Instance 3" }))
    }

    /// Deleting entire series removes all open instances but keeps completed ones
    func test_deleteRecurringSeries_deletesAllOpen() throws {
        let context = container.mainContext
        let groupID = "series-xyz"

        let open1 = LocalTask(title: "Open 1", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let open2 = LocalTask(title: "Open 2", recurrencePattern: "daily", recurrenceGroupID: groupID)
        let completed = LocalTask(title: "Completed", recurrencePattern: "daily", recurrenceGroupID: groupID)
        completed.isCompleted = true
        completed.completedAt = Date()

        let unrelated = LocalTask(title: "Unrelated", recurrencePattern: "daily", recurrenceGroupID: "other-group")

        context.insert(open1)
        context.insert(open2)
        context.insert(completed)
        context.insert(unrelated)
        try context.save()

        try syncEngine.deleteRecurringSeries(groupID: groupID)

        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(remaining.count, 2, "Only completed + unrelated should remain")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Completed" }), "Completed instances stay")
        XCTAssertTrue(remaining.contains(where: { $0.title == "Unrelated" }), "Unrelated tasks stay")
    }

    // MARK: - updateSortOrder Tests

    func test_updateSortOrder_updatesTasksSortOrder() async throws {
        let context = container.mainContext
        let task1 = LocalTask(title: "Task 1", importance: 0)
        task1.sortOrder = 0
        let task2 = LocalTask(title: "Task 2", importance: 0)
        task2.sortOrder = 1

        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Create PlanItems in reversed order
        let planItems = [
            PlanItem(localTask: task2),
            PlanItem(localTask: task1)
        ]

        try await syncEngine.updateSortOrder(for: planItems)

        XCTAssertEqual(task2.sortOrder, 0)
        XCTAssertEqual(task1.sortOrder, 1)
    }
}
