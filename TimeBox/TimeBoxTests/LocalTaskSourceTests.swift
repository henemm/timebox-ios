import XCTest
import SwiftData
@testable import TimeBox

@MainActor
final class LocalTaskSourceTests: XCTestCase {

    var container: ModelContainer!
    var source: LocalTaskSource!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        source = LocalTaskSource(modelContext: container.mainContext)
    }

    override func tearDownWithError() throws {
        container = nil
        source = nil
    }

    // MARK: - Static Properties

    func test_sourceIdentifier_isLocal() {
        XCTAssertEqual(LocalTaskSource.sourceIdentifier, "local")
    }

    func test_displayName_isLocalized() {
        XCTAssertEqual(LocalTaskSource.displayName, "Lokale Tasks")
    }

    // MARK: - Configuration

    func test_isConfigured_alwaysTrue() {
        XCTAssertTrue(source.isConfigured)
    }

    func test_requestAccess_alwaysReturnsTrue() async throws {
        let hasAccess = try await source.requestAccess()
        XCTAssertTrue(hasAccess)
    }

    // MARK: - Fetch Tasks

    func test_fetchIncompleteTasks_returnsOnlyIncomplete() async throws {
        // Setup: Create tasks directly in context
        let context = container.mainContext
        let task1 = LocalTask(title: "Task 1", priority: 0)
        let task2 = LocalTask(title: "Task 2", priority: 0)
        task2.isCompleted = true
        let task3 = LocalTask(title: "Task 3", priority: 0)

        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        try context.save()

        // Test
        let tasks = try await source.fetchIncompleteTasks()

        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.allSatisfy { !$0.isCompleted })
    }

    func test_fetchIncompleteTasks_sortsBySortOrder() async throws {
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

        let tasks = try await source.fetchIncompleteTasks()

        XCTAssertEqual(tasks[0].title, "First")
        XCTAssertEqual(tasks[1].title, "Second")
        XCTAssertEqual(tasks[2].title, "Third")
    }

    // MARK: - Mark Complete/Incomplete

    func test_markComplete_updatesTask() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test", priority: 0)
        context.insert(task)
        try context.save()

        try await source.markComplete(taskID: task.id)

        XCTAssertTrue(task.isCompleted)
    }

    func test_markIncomplete_updatesTask() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test", priority: 0)
        task.isCompleted = true
        context.insert(task)
        try context.save()

        try await source.markIncomplete(taskID: task.id)

        XCTAssertFalse(task.isCompleted)
    }

    // MARK: - Create Task

    func test_createTask_insertsNewTask() async throws {
        let newTask = try await source.createTask(
            title: "New Task",
            category: "Work",
            dueDate: Date(),
            priority: 2
        )

        XCTAssertEqual(newTask.title, "New Task")
        XCTAssertEqual(newTask.category, "Work")
        XCTAssertEqual(newTask.priority, 2)
        XCTAssertFalse(newTask.isCompleted)

        // Verify persisted
        let tasks = try await source.fetchIncompleteTasks()
        XCTAssertEqual(tasks.count, 1)
    }

    func test_createTask_assignsNextSortOrder() async throws {
        // Create first task
        let task1 = try await source.createTask(title: "First", category: nil, dueDate: nil, priority: 0)

        // Create second task
        let task2 = try await source.createTask(title: "Second", category: nil, dueDate: nil, priority: 0)

        XCTAssertEqual(task1.sortOrder, 0)
        XCTAssertEqual(task2.sortOrder, 1)
    }

    // MARK: - Update Task

    func test_updateTask_modifiesExistingTask() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Original", priority: 0)
        context.insert(task)
        try context.save()

        try await source.updateTask(
            taskID: task.id,
            title: "Updated",
            category: "Personal",
            dueDate: nil,
            priority: 3
        )

        XCTAssertEqual(task.title, "Updated")
        XCTAssertEqual(task.category, "Personal")
        XCTAssertEqual(task.priority, 3)
    }

    func test_updateTask_preservesUnchangedFields() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Original", priority: 5, category: "Work", categoryColorHex: "#FF0000", dueDate: Date())
        context.insert(task)
        try context.save()

        // Update only title
        try await source.updateTask(taskID: task.id, title: "New Title", category: nil, dueDate: nil, priority: nil)

        XCTAssertEqual(task.title, "New Title")
        XCTAssertEqual(task.priority, 5) // unchanged
        XCTAssertEqual(task.category, "Work") // unchanged
    }

    // MARK: - Delete Task

    func test_deleteTask_removesTask() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "To Delete", priority: 0)
        context.insert(task)
        try context.save()

        let taskID = task.id
        try await source.deleteTask(taskID: taskID)

        let tasks = try await source.fetchIncompleteTasks()
        XCTAssertEqual(tasks.count, 0)
    }

    // MARK: - Error Handling

    func test_markComplete_withInvalidID_doesNotCrash() async throws {
        // Should not throw, just silently do nothing
        try await source.markComplete(taskID: "invalid-id")
    }

    func test_deleteTask_withInvalidID_doesNotCrash() async throws {
        // Should not throw, just silently do nothing
        try await source.deleteTask(taskID: "invalid-id")
    }
}
