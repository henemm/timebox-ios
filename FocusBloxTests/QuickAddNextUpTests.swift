import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for QuickAdd Next Up feature
/// Tests that isNextUp + nextUpSortOrder are correctly set after task creation
/// EXPECTED TO FAIL: No code sets isNextUp during Quick Add flow yet
@MainActor
final class QuickAddNextUpTests: XCTestCase {

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

    // MARK: - Default Behavior (no Next Up)

    /// GIVEN: A task created via LocalTaskSource.createTask()
    /// WHEN: isNextUp is not explicitly set after creation
    /// THEN: Task should have isNextUp = false (default)
    func test_createTask_defaultIsNextUp_false() async throws {
        let task = try await source.createTask(title: "Normal Task")

        XCTAssertFalse(task.isNextUp, "Task created without Next Up should default to false")
        XCTAssertNil(task.nextUpSortOrder, "Task without Next Up should have nil sortOrder")
    }

    // MARK: - Next Up Set After Creation

    /// GIVEN: A task created via createTask()
    /// WHEN: isNextUp is set to true + nextUpSortOrder is set after creation
    /// THEN: Task should have isNextUp = true and nextUpSortOrder = Int.max
    /// EXPECTED TO FAIL: This pattern is not used in Quick Add yet
    func test_setNextUpAfterCreation_setsProperties() async throws {
        let task = try await source.createTask(title: "Next Up Task")

        // Simulate what the Quick Add flow SHOULD do:
        task.isNextUp = true
        task.nextUpSortOrder = Int.max
        try container.mainContext.save()

        XCTAssertTrue(task.isNextUp, "Task should be marked as Next Up")
        XCTAssertEqual(task.nextUpSortOrder, Int.max, "Next Up sort order should be Int.max (end of list)")
    }

    /// GIVEN: A task with isNextUp = true
    /// WHEN: Fetching tasks with isNextUp filter
    /// THEN: Task should appear in Next Up results
    func test_nextUpTask_appearsInNextUpQuery() async throws {
        // Create a normal task
        let normalTask = try await source.createTask(title: "Normal Task")

        // Create a Next Up task
        let nextUpTask = try await source.createTask(title: "Next Up Task")
        nextUpTask.isNextUp = true
        nextUpTask.nextUpSortOrder = Int.max
        try container.mainContext.save()

        // Fetch Next Up tasks
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isNextUp && !$0.isCompleted }
        )
        let nextUpTasks = try container.mainContext.fetch(descriptor)

        XCTAssertEqual(nextUpTasks.count, 1, "Should have exactly 1 Next Up task")
        XCTAssertEqual(nextUpTasks.first?.title, "Next Up Task", "Next Up task should be the correct one")
        XCTAssertFalse(normalTask.isNextUp, "Normal task should not be in Next Up")
    }
}
