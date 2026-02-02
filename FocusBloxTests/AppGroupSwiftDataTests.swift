import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for SharedModelContainer (local storage).
/// Bug 25 fix: App Group was removed - causes SwiftDataError on devices.
final class SharedModelContainerTests: XCTestCase {

    // MARK: - SharedModelContainer Tests

    /// Test that SharedModelContainer can be created without error
    func testSharedContainerAccessible() throws {
        // WHEN: Creating shared container
        let container = try SharedModelContainer.create()

        // THEN: Container is created successfully
        XCTAssertNotNil(container)
    }

    /// Test that SharedModelContainer uses local storage (not App Group)
    func testSharedContainerUsesLocalStorage() throws {
        // GIVEN/WHEN: Creating container
        let container = try SharedModelContainer.create()

        // THEN: Container uses local storage (no App Group in path)
        let storeURL = container.configurations.first?.url
        XCTAssertNotNil(storeURL)
        // Bug 25 fix: Should NOT contain App Group path
        XCTAssertFalse(storeURL?.path.contains("group.com.henning.focusblox") == true,
                      "Store should NOT be in App Group container (Bug 25 fix)")
    }
}

// MARK: - Intent Integration Tests

/// Tests for Intent SwiftData access.
/// These test that Intents can read/write the shared container.
final class IntentSwiftDataTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up any test data
        cleanupTestTasks()
    }

    override func tearDown() {
        cleanupTestTasks()
        super.tearDown()
    }

    private func cleanupTestTasks() {
        // Best effort cleanup
        guard let container = try? SharedModelContainer.create() else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.title.contains("Intent Test") }
        )
        if let tasks = try? context.fetch(descriptor) {
            tasks.forEach { context.delete($0) }
            try? context.save()
        }
    }

    /// Test that CreateTaskIntent can save a task to shared container
    func testCreateTaskIntentSavesTask() async throws {
        // Skip if App Group not available
        let appGroupID = "group.com.henning.focusblox"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: Shared container is accessible
        let container = try SharedModelContainer.create()

        // WHEN: Creating a task via Intent pattern
        let context = ModelContext(container)
        let task = LocalTask(title: "Intent Test Task", importance: 3, estimatedDuration: 30)
        context.insert(task)
        try context.save()

        // THEN: Task can be read back
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.title == "Intent Test Task" }
        )
        let tasks = try newContext.fetch(descriptor)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.importance, 3)
        XCTAssertEqual(tasks.first?.estimatedDuration, 30)
    }

    /// Test that GetNextUpIntent can read Next Up tasks
    func testGetNextUpQueryReturnsTasks() async throws {
        // Skip if App Group not available
        let appGroupID = "group.com.henning.focusblox"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: Tasks with isNextUp = true exist
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let nextUpTask = LocalTask(title: "Intent Test NextUp Task")
        nextUpTask.isNextUp = true
        context.insert(nextUpTask)

        let backlogTask = LocalTask(title: "Intent Test Backlog Task")
        backlogTask.isNextUp = false
        context.insert(backlogTask)

        try context.save()

        // WHEN: Querying Next Up tasks
        let queryContext = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.isNextUp && !$0.isCompleted }
        )
        let nextUpTasks = try queryContext.fetch(descriptor)

        // THEN: Only Next Up tasks are returned
        let titles = nextUpTasks.map(\.title)
        XCTAssertTrue(titles.contains("Intent Test NextUp Task"))
        XCTAssertFalse(titles.contains("Intent Test Backlog Task"))
    }

    /// Test that CompleteTaskIntent can mark a task as completed
    func testCompleteTaskUpdatesTask() async throws {
        // Skip if App Group not available
        let appGroupID = "group.com.henning.focusblox"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: An incomplete task exists
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let taskUUID = UUID()
        let task = LocalTask(uuid: taskUUID, title: "Intent Test Complete Task")
        task.isCompleted = false
        context.insert(task)
        try context.save()

        // WHEN: Marking task as completed
        let updateContext = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { localTask in localTask.uuid == taskUUID }
        )
        guard let taskToComplete = try updateContext.fetch(descriptor).first else {
            XCTFail("Task not found")
            return
        }
        taskToComplete.isCompleted = true
        try updateContext.save()

        // THEN: Task is marked as completed
        let verifyContext = ModelContext(container)
        let verifyDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { localTask in localTask.uuid == taskUUID }
        )
        let completedTask = try verifyContext.fetch(verifyDescriptor).first
        XCTAssertTrue(completedTask?.isCompleted == true)
    }
}
