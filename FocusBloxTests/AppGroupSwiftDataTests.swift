import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for App Group SwiftData migration and shared container access.
/// TDD RED: These tests should FAIL until implementation is complete.
final class AppGroupSwiftDataTests: XCTestCase {

    private let appGroupID = "group.com.henning.focusblox"

    override func setUp() {
        super.setUp()
        // Reset migration flag for each test
        UserDefaults.standard.removeObject(forKey: "appGroupMigrationDone")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "appGroupMigrationDone")
        super.tearDown()
    }

    // MARK: - SharedModelContainer Tests

    /// Test that SharedModelContainer can be created without error
    func testSharedContainerAccessible() throws {
        // GIVEN: App Group is configured in entitlements

        // WHEN: Creating shared container
        // This should use SharedModelContainer.create() which doesn't exist yet
        let container = try SharedModelContainer.create()

        // THEN: Container is created successfully
        XCTAssertNotNil(container)
    }

    /// Test that SharedModelContainer uses App Group
    func testSharedContainerUsesAppGroup() throws {
        // Skip if App Group not available (unsigned builds/unit tests)
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: SharedModelContainer exists

        // WHEN: Creating container
        let container = try SharedModelContainer.create()

        // THEN: Container uses App Group path
        // The store URL should contain the app group identifier
        let storeURL = container.configurations.first?.url
        XCTAssertNotNil(storeURL)
        // App Group containers have a specific path pattern
        XCTAssertTrue(storeURL?.path.contains("group.com.henning.focusblox") == true ||
                     storeURL?.path.contains("AppGroup") == true,
                     "Store should be in App Group container")
    }

    // MARK: - Migration Tests

    /// Test that migration copies all tasks from default to App Group container
    func testMigrationCopiesAllTasks() throws {
        // Skip if App Group not available (unsigned builds)
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: 3 tasks exist in default container
        let schema = Schema([LocalTask.self, TaskMetadata.self])
        let defaultConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        let defaultContainer = try ModelContainer(for: schema, configurations: [defaultConfig])
        let defaultContext = ModelContext(defaultContainer)

        let task1 = LocalTask(title: "Migration Test Task 1")
        let task2 = LocalTask(title: "Migration Test Task 2")
        let task3 = LocalTask(title: "Migration Test Task 3")
        defaultContext.insert(task1)
        defaultContext.insert(task2)
        defaultContext.insert(task3)
        try defaultContext.save()

        // WHEN: Migration runs
        // This calls AppGroupMigration.migrateIfNeeded() which doesn't exist yet
        try AppGroupMigration.migrateIfNeeded()

        // THEN: All 3 tasks exist in App Group container
        let appGroupContainer = try SharedModelContainer.create()
        let appGroupContext = ModelContext(appGroupContainer)
        let descriptor = FetchDescriptor<LocalTask>()
        let migratedTasks = try appGroupContext.fetch(descriptor)

        XCTAssertGreaterThanOrEqual(migratedTasks.count, 3, "Should have at least 3 migrated tasks")

        let titles = Set(migratedTasks.map(\.title))
        XCTAssertTrue(titles.contains("Migration Test Task 1"))
        XCTAssertTrue(titles.contains("Migration Test Task 2"))
        XCTAssertTrue(titles.contains("Migration Test Task 3"))
    }

    /// Test that migration only runs once
    func testMigrationOnlyRunsOnce() throws {
        // GIVEN: Migration has already completed
        UserDefaults.standard.set(true, forKey: "appGroupMigrationDone")

        // WHEN: Checking if migration is needed
        // This calls AppGroupMigration.needsMigration() which doesn't exist yet
        let needsMigration = AppGroupMigration.needsMigration()

        // THEN: Migration is not needed
        XCTAssertFalse(needsMigration, "Migration should not run twice")
    }

    /// Test that migration sets completion flag
    func testMigrationSetsCompletionFlag() throws {
        // Skip if App Group not available
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            throw XCTSkip("App Group not available - requires signed build")
        }

        // GIVEN: Migration has not run
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "appGroupMigrationDone"))

        // WHEN: Migration runs
        try AppGroupMigration.migrateIfNeeded()

        // THEN: Flag is set
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "appGroupMigrationDone"))
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
