import XCTest
import SwiftData
@testable import TimeBox

@MainActor
final class LocalTaskTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        // Create in-memory SwiftData container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - Model Properties

    func test_localTask_hasRequiredProperties() throws {
        let context = container.mainContext
        let task = LocalTask(
            title: "Test Task",
            priority: 1
        )
        context.insert(task)

        XCTAssertNotNil(task.uuid)
        XCTAssertFalse(task.id.isEmpty)
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.priority, 1)
        XCTAssertNil(task.category)
        XCTAssertNil(task.categoryColorHex)
        XCTAssertNil(task.dueDate)
        XCTAssertNotNil(task.createdAt)
        XCTAssertEqual(task.sortOrder, 0)
    }

    func test_localTask_canSetOptionalProperties() throws {
        let context = container.mainContext
        let dueDate = Date()
        let task = LocalTask(
            title: "Task with extras",
            priority: 2,
            category: "Work",
            categoryColorHex: "#FF5733",
            dueDate: dueDate
        )
        context.insert(task)

        XCTAssertEqual(task.category, "Work")
        XCTAssertEqual(task.categoryColorHex, "#FF5733")
        XCTAssertEqual(task.dueDate, dueDate)
    }

    // MARK: - Persistence

    func test_localTask_canBeSaved() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Persistent Task", priority: 0)
        context.insert(task)

        try context.save()

        let descriptor = FetchDescriptor<LocalTask>()
        let tasks = try context.fetch(descriptor)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Persistent Task")
    }

    func test_localTask_canBeUpdated() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Original", priority: 0)
        context.insert(task)
        try context.save()

        task.title = "Updated"
        task.isCompleted = true
        try context.save()

        let descriptor = FetchDescriptor<LocalTask>()
        let tasks = try context.fetch(descriptor)
        XCTAssertEqual(tasks.first?.title, "Updated")
        XCTAssertTrue(tasks.first?.isCompleted ?? false)
    }

    func test_localTask_canBeDeleted() throws {
        let context = container.mainContext
        let task = LocalTask(title: "To Delete", priority: 0)
        context.insert(task)
        try context.save()

        context.delete(task)
        try context.save()

        let descriptor = FetchDescriptor<LocalTask>()
        let tasks = try context.fetch(descriptor)
        XCTAssertEqual(tasks.count, 0)
    }

    // MARK: - Queries

    func test_localTask_canFetchIncomplete() throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Task 1", priority: 0)
        let task2 = LocalTask(title: "Task 2", priority: 0)
        task2.isCompleted = true
        let task3 = LocalTask(title: "Task 3", priority: 0)

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        var descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]

        let incompleteTasks = try context.fetch(descriptor)
        XCTAssertEqual(incompleteTasks.count, 2)
        XCTAssertTrue(incompleteTasks.allSatisfy { !$0.isCompleted })
    }

    func test_localTask_canSortBySortOrder() throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Third", priority: 0)
        task1.sortOrder = 2
        let task2 = LocalTask(title: "First", priority: 0)
        task2.sortOrder = 0
        let task3 = LocalTask(title: "Second", priority: 0)
        task3.sortOrder = 1

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        var descriptor = FetchDescriptor<LocalTask>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]

        let sortedTasks = try context.fetch(descriptor)
        XCTAssertEqual(sortedTasks[0].title, "First")
        XCTAssertEqual(sortedTasks[1].title, "Second")
        XCTAssertEqual(sortedTasks[2].title, "Third")
    }

    // MARK: - Manual Duration

    func test_localTask_manualDuration_defaultsToNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", priority: 0)
        context.insert(task)

        XCTAssertNil(task.manualDuration)
    }

    func test_localTask_manualDuration_canBeSet() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", priority: 0)
        context.insert(task)

        task.manualDuration = 30
        try context.save()

        XCTAssertEqual(task.manualDuration, 30)
    }

    func test_localTask_manualDuration_canBeReset() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", priority: 0)
        task.manualDuration = 45
        context.insert(task)
        try context.save()

        task.manualDuration = nil
        try context.save()

        XCTAssertNil(task.manualDuration)
    }

    // MARK: - TaskSourceData Conformance

    func test_localTask_conformsToTaskSourceData() throws {
        let context = container.mainContext
        let task = LocalTask(
            title: "Source Task",
            priority: 1,
            category: "Personal",
            categoryColorHex: "#00FF00",
            dueDate: Date()
        )
        context.insert(task)

        // Test that LocalTask can be used where TaskSourceData is expected
        let sourceData: any TaskSourceData = task
        XCTAssertEqual(sourceData.title, "Source Task")
        XCTAssertEqual(sourceData.priority, 1)
        XCTAssertEqual(sourceData.categoryTitle, "Personal")
        XCTAssertEqual(sourceData.categoryColorHex, "#00FF00")
        XCTAssertFalse(sourceData.isCompleted)
    }
}
