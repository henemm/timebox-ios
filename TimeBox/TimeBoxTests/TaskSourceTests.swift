import XCTest
@testable import TimeBox

// MARK: - Mock Task Data

struct MockTaskData: TaskSourceData {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let tags: [String]
    let dueDate: Date?

    // MARK: - Enhanced Task Fields

    let urgency: String
    let taskType: String
    let recurrencePattern: String
    let recurrenceWeekdays: [Int]?
    let recurrenceMonthDay: Int?
    let taskDescription: String?
    let externalID: String?
    let sourceSystem: String
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
                tags: task.tags,
                dueDate: task.dueDate,
                urgency: task.urgency,
                taskType: task.taskType,
                recurrencePattern: task.recurrencePattern,
                recurrenceWeekdays: task.recurrenceWeekdays,
                recurrenceMonthDay: task.recurrenceMonthDay,
                taskDescription: task.taskDescription,
                externalID: task.externalID,
                sourceSystem: task.sourceSystem
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
                tags: task.tags,
                dueDate: task.dueDate,
                urgency: task.urgency,
                taskType: task.taskType,
                recurrencePattern: task.recurrencePattern,
                recurrenceWeekdays: task.recurrenceWeekdays,
                recurrenceMonthDay: task.recurrenceMonthDay,
                taskDescription: task.taskDescription,
                externalID: task.externalID,
                sourceSystem: task.sourceSystem
            )
        }
    }

    func createTask(
        title: String,
        tags: [String] = [],
        dueDate: Date? = nil,
        priority: Int = 1,
        duration: Int? = nil,
        urgency: String = "not_urgent",
        taskType: String = "maintenance",
        recurrencePattern: String = "none",
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        description: String? = nil
    ) async throws -> MockTaskData {
        let task = MockTaskData(
            id: UUID().uuidString,
            title: title,
            isCompleted: false,
            priority: priority,
            tags: tags,
            dueDate: dueDate,
            urgency: urgency,
            taskType: taskType,
            recurrencePattern: recurrencePattern,
            recurrenceWeekdays: recurrenceWeekdays,
            recurrenceMonthDay: recurrenceMonthDay,
            taskDescription: description,
            externalID: nil,
            sourceSystem: "mock"
        )
        tasks.append(task)
        return task
    }

    func updateTask(
        taskID: String,
        title: String? = nil,
        tags: [String]? = nil,
        dueDate: Date? = nil,
        priority: Int? = nil,
        duration: Int? = nil,
        urgency: String? = nil,
        taskType: String? = nil,
        recurrencePattern: String? = nil,
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        description: String? = nil
    ) async throws {
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            let task = tasks[index]
            tasks[index] = MockTaskData(
                id: task.id,
                title: title ?? task.title,
                isCompleted: task.isCompleted,
                priority: priority ?? task.priority,
                tags: tags ?? task.tags,
                dueDate: dueDate ?? task.dueDate,
                urgency: urgency ?? task.urgency,
                taskType: taskType ?? task.taskType,
                recurrencePattern: recurrencePattern ?? task.recurrencePattern,
                recurrenceWeekdays: recurrenceWeekdays ?? task.recurrenceWeekdays,
                recurrenceMonthDay: recurrenceMonthDay ?? task.recurrenceMonthDay,
                taskDescription: description ?? task.taskDescription,
                externalID: task.externalID,
                sourceSystem: task.sourceSystem
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
            tags: ["Work", "Important"],
            dueDate: Date(),
            urgency: "urgent",
            taskType: "income",
            recurrencePattern: "none",
            recurrenceWeekdays: nil,
            recurrenceMonthDay: nil,
            taskDescription: "Test description",
            externalID: nil,
            sourceSystem: "mock"
        )

        XCTAssertEqual(task.id, "test-1")
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.priority, 1)
        XCTAssertEqual(task.tags, ["Work", "Important"])
        XCTAssertNotNil(task.dueDate)
        XCTAssertEqual(task.urgency, "urgent")
        XCTAssertEqual(task.taskType, "income")
        XCTAssertEqual(task.recurrencePattern, "none")
        XCTAssertNil(task.recurrenceWeekdays)
        XCTAssertNil(task.recurrenceMonthDay)
        XCTAssertEqual(task.taskDescription, "Test description")
    }

    func test_taskSourceData_optionalPropertiesCanBeNil() {
        let task = MockTaskData(
            id: "test-2",
            title: "Minimal Task",
            isCompleted: false,
            priority: 1,
            tags: [],
            dueDate: nil,
            urgency: "not_urgent",
            taskType: "maintenance",
            recurrencePattern: "none",
            recurrenceWeekdays: nil,
            recurrenceMonthDay: nil,
            taskDescription: nil,
            externalID: nil,
            sourceSystem: "mock"
        )

        XCTAssertTrue(task.tags.isEmpty)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.recurrenceWeekdays)
        XCTAssertNil(task.recurrenceMonthDay)
        XCTAssertNil(task.taskDescription)
        XCTAssertNil(task.externalID)
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
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock"),
            MockTaskData(id: "2", title: "Task 2", isCompleted: true, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock"),
            MockTaskData(id: "3", title: "Task 3", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock")
        ]

        let incomplete = try await source.fetchIncompleteTasks()

        XCTAssertEqual(incomplete.count, 2)
        XCTAssertTrue(incomplete.allSatisfy { !$0.isCompleted })
    }

    func test_taskSource_markComplete_updatesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock")
        ]

        try await source.markComplete(taskID: "1")

        XCTAssertTrue(source.tasks[0].isCompleted)
    }

    func test_taskSource_markIncomplete_updatesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: true, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock")
        ]

        try await source.markIncomplete(taskID: "1")

        XCTAssertFalse(source.tasks[0].isCompleted)
    }

    // MARK: - TaskSourceWritable Tests

    func test_taskSourceWritable_createTask_addsNewTask() async throws {
        let source = MockTaskSource()

        let newTask = try await source.createTask(
            title: "New Task",
            tags: ["Work"],
            dueDate: nil,
            priority: 1,
            duration: 30,
            urgency: "urgent",
            taskType: "income",
            recurrencePattern: "none",
            recurrenceWeekdays: nil,
            recurrenceMonthDay: nil,
            description: nil
        )

        XCTAssertEqual(source.tasks.count, 1)
        XCTAssertEqual(newTask.title, "New Task")
        XCTAssertEqual(newTask.tags, ["Work"])
        XCTAssertEqual(newTask.priority, 1)
        XCTAssertFalse(newTask.isCompleted)
        XCTAssertEqual(newTask.urgency, "urgent")
        XCTAssertEqual(newTask.taskType, "income")
    }

    func test_taskSourceWritable_updateTask_modifiesExistingTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Old Title", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock")
        ]

        try await source.updateTask(taskID: "1", title: "New Title", tags: ["Work"], dueDate: nil, priority: 2, duration: nil, urgency: "urgent", taskType: "income", recurrencePattern: "weekly", recurrenceWeekdays: [1, 3], recurrenceMonthDay: nil, description: "Updated")

        XCTAssertEqual(source.tasks[0].title, "New Title")
        XCTAssertEqual(source.tasks[0].tags, ["Work"])
        XCTAssertEqual(source.tasks[0].priority, 2)
        XCTAssertEqual(source.tasks[0].urgency, "urgent")
        XCTAssertEqual(source.tasks[0].taskType, "income")
        XCTAssertEqual(source.tasks[0].recurrencePattern, "weekly")
        XCTAssertEqual(source.tasks[0].recurrenceWeekdays, [1, 3])
        XCTAssertEqual(source.tasks[0].taskDescription, "Updated")
    }

    func test_taskSourceWritable_deleteTask_removesTask() async throws {
        let source = MockTaskSource()
        source.tasks = [
            MockTaskData(id: "1", title: "Task 1", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock"),
            MockTaskData(id: "2", title: "Task 2", isCompleted: false, priority: 1, tags: [], dueDate: nil, urgency: "not_urgent", taskType: "maintenance", recurrencePattern: "none", recurrenceWeekdays: nil, recurrenceMonthDay: nil, taskDescription: nil, externalID: nil, sourceSystem: "mock")
        ]

        try await source.deleteTask(taskID: "1")

        XCTAssertEqual(source.tasks.count, 1)
        XCTAssertEqual(source.tasks[0].id, "2")
    }
}
