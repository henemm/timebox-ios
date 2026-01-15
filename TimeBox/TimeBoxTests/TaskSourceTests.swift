import XCTest
@testable import TimeBox

// MARK: - Mock Task Data

struct MockTaskData: TaskSourceData {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let categoryTitle: String?
    let categoryColorHex: String?
    let dueDate: Date?
}

// MARK: - Mock Task Source

final class MockTaskSource: TaskSource, TaskSourceWritable {
    typealias TaskData = MockTaskData

    static var sourceIdentifier: String { "mock" }
    static var displayName: String { "Mock Source" }

    var isConfigured: Bool = true
    var tasks: [MockTaskData] = []
    var accessGranted = true

    func requestAccess() async throws -> Bool {
        return accessGranted
    }

    func fetchIncompleteTasks() async throws -> [MockTaskData] {
        return tasks.filter { !$0.isCompleted }
    }

    func markComplete(taskID: String) async throws {
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            let task = tasks[index]
            tasks[index] = MockTaskData(
                id: task.id,
                title: task.title,
                isCompleted: true,
                priority: task.priority,
                categoryTitle: task.categoryTitle,
                categoryColorHex: task.categoryColorHex,
                dueDate: task.dueDate
            )
        }
    }

    func markIncomplete(taskID: String) async throws {
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            let task = tasks[index]
            tasks[index] = MockTaskData(
                id: task.id,
                title: task.title,
                isCompleted: false,
                priority: task.priority,
                categoryTitle: task.categoryTitle,
                categoryColorHex: task.categoryColorHex,
                dueDate: task.dueDate
            )
        }
    }

    func createTask(title: String, category: String?, dueDate: Date?, priority: Int) async throws -> MockTaskData {
        let task = MockTaskData(
            id: UUID().uuidString,
            title: title,
            isCompleted: false,
            priority: priority,
            categoryTitle: category,
            categoryColorHex: nil,
            dueDate: dueDate
        )
        tasks.append(task)
        return task
    }

    func updateTask(taskID: String, title: String?, category: String?, dueDate: Date?, priority: Int?) async throws {
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            let task = tasks[index]
            tasks[index] = MockTaskData(
                id: task.id,
                title: title ?? task.title,
                isCompleted: task.isCompleted,
                priority: priority ?? task.priority,
                categoryTitle: category ?? task.categoryTitle,
                categoryColorHex: task.categoryColorHex,
                dueDate: dueDate ?? task.dueDate
            )
        }
    }

    func deleteTask(taskID: String) async throws {
        tasks.removeAll { $0.id == taskID }
    }
}

// MARK: - Tests

final class TaskSourceTests: XCTestCase {

    // MARK: - TaskSourceData Tests

    func test_taskSourceData_hasRequiredProperties() {
        let task = MockTaskData(
            id: "test-1",
            title: "Test Task",
            isCompleted: false,
            priority: 1,
            categoryTitle: "Work",
            categoryColorHex: "#FF0000",
            dueDate: Date()
        )

        XCTAssertEqual(task.id, "test-1")
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.priority, 1)
        XCTAssertEqual(task.categoryTitle, "Work")
        XCTAssertEqual(task.categoryColorHex, "#FF0000")
        XCTAssertNotNil(task.dueDate)
    }

    func test_taskSourceData_optionalPropertiesCanBeNil() {
        let task = MockTaskData(
            id: "test-2",
            title: "Minimal Task",
            isCompleted: false,
            priority: 0,
            categoryTitle: nil,
            categoryColorHex: nil,
            dueDate: nil
        )

        XCTAssertNil(task.categoryTitle)
        XCTAssertNil(task.categoryColorHex)
        XCTAssertNil(task.dueDate)
    }

    // MARK: - TaskSource Tests

    func test_taskSource_hasStaticIdentifiers() {
        XCTAssertEqual(MockTaskSource.sourceIdentifier, "mock")
        XCTAssertEqual(MockTaskSource.displayName, "Mock Source")
    }

    func test_taskSource_isConfiguredByDefault() {
        let source = MockTaskSource()
        XCTAssertTrue(source.isConfigured)
    }

    func test_taskSource_requestAccess_returnsTrue() async throws {
        let source = MockTaskSource()
        let hasAccess = try await source.requestAccess()
        XCTAssertTrue(hasAccess)
    }

    func test_taskSource_requestAccess_canDenyAccess() async throws {
        let source = MockTaskSource()
        source.accessGranted = false
        let hasAccess = try await source.requestAccess()
        XCTAssertFalse(hasAccess)
    }

    func test_taskSource_fetchIncompleteTasks_returnsOnlyIncomplete() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil),
            MockTaskData(id: "2", title: "Task 2", isCompleted: true, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil),
            MockTaskData(id: "3", title: "Task 3", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil)
        ]

        let incomplete = try await source.fetchIncompleteTasks()

        XCTAssertEqual(incomplete.count, 2)
        XCTAssertTrue(incomplete.allSatisfy { !$0.isCompleted })
    }

    func test_taskSource_markComplete_updatesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil)
        ]

        try await source.markComplete(taskID: "1")

        XCTAssertTrue(source.tasks[0].isCompleted)
    }

    func test_taskSource_markIncomplete_updatesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: true, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil)
        ]

        try await source.markIncomplete(taskID: "1")

        XCTAssertFalse(source.tasks[0].isCompleted)
    }

    // MARK: - TaskSourceWritable Tests

    func test_taskSourceWritable_createTask_addsNewTask() async throws {
        let source = MockTaskSource()

        let newTask = try await source.createTask(
            title: "New Task",
            category: "Work",
            dueDate: nil,
            priority: 1
        )

        XCTAssertEqual(source.tasks.count, 1)
        XCTAssertEqual(newTask.title, "New Task")
        XCTAssertEqual(newTask.categoryTitle, "Work")
        XCTAssertEqual(newTask.priority, 1)
        XCTAssertFalse(newTask.isCompleted)
    }

    func test_taskSourceWritable_updateTask_modifiesExistingTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Old Title", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil)
        ]

        try await source.updateTask(taskID: "1", title: "New Title", category: "Work", dueDate: nil, priority: 2)

        XCTAssertEqual(source.tasks[0].title, "New Title")
        XCTAssertEqual(source.tasks[0].categoryTitle, "Work")
        XCTAssertEqual(source.tasks[0].priority, 2)
    }

    func test_taskSourceWritable_deleteTask_removesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil),
            MockTaskData(id: "2", title: "Task 2", isCompleted: false, priority: 0, categoryTitle: nil, categoryColorHex: nil, dueDate: nil)
        ]

        try await source.deleteTask(taskID: "1")

        XCTAssertEqual(source.tasks.count, 1)
        XCTAssertEqual(source.tasks[0].id, "2")
    }
}
