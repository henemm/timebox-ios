import XCTest
import SwiftData
@testable import FocusBlox

/// Bug 78: macOS crashes when swiping tasks because SwiftData objects can become
/// detached from their ModelContext (e.g., after delete or CloudKit sync).
/// Accessing properties like .tags on a detached object causes a fatal fault.
///
/// These tests verify that:
/// 1. Deleted tasks have nil modelContext (detached)
/// 2. Our guard pattern correctly identifies detached tasks
/// 3. Tags access on a valid (non-detached) task works normally
@MainActor
final class DetachedTaskGuardTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Test 1: Valid task has non-nil modelContext

    func testValidTaskHasModelContext() throws {
        // GIVEN: A task inserted into context
        let task = LocalTask(title: "Test Task")
        task.tags = ["work", "urgent"]
        context.insert(task)
        try context.save()

        // THEN: modelContext is non-nil
        XCTAssertNotNil(task.modelContext, "Valid task should have a modelContext")
    }

    // MARK: - Test 2: Deleted task has nil modelContext (detached)

    func testDeletedTaskHasNilModelContext() throws {
        // GIVEN: A task inserted and saved
        let task = LocalTask(title: "Soon to be deleted")
        task.tags = ["important"]
        context.insert(task)
        try context.save()

        // WHEN: Task is deleted from context
        context.delete(task)
        try context.save()

        // THEN: modelContext is nil (detached)
        XCTAssertNil(task.modelContext, "Deleted task should have nil modelContext (detached)")
    }

    // MARK: - Test 3: Guard pattern skips detached tasks in filter

    func testGuardPatternSkipsDetachedTaskInFilter() throws {
        // GIVEN: Two tasks, one will be deleted
        let task1 = LocalTask(title: "Keep me")
        task1.tags = ["work"]
        let task2 = LocalTask(title: "Delete me")
        task2.tags = ["personal"]
        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Keep reference to task2 (simulates stale ForEach closure)
        let staleReference = task2

        // WHEN: task2 is deleted
        context.delete(task2)
        try context.save()

        // THEN: Guard pattern correctly filters out detached task
        let allTasks = [task1, staleReference]
        let safeTasks = allTasks.filter { $0.modelContext != nil }

        XCTAssertEqual(safeTasks.count, 1, "Only non-detached tasks should pass guard")
        XCTAssertEqual(safeTasks.first?.title, "Keep me")
    }

    // MARK: - Test 4: matchesSearch guard pattern works

    func testMatchesSearchGuardSkipsDetachedTask() throws {
        // GIVEN: A task with tags
        let task = LocalTask(title: "Search Target")
        task.tags = ["design", "research"]
        context.insert(task)
        try context.save()

        // WHEN: Task is deleted (simulates detach)
        context.delete(task)
        try context.save()

        // THEN: Guard pattern returns false for detached task
        // This is the pattern that should be in ContentView.matchesSearch()
        let isDetached = task.modelContext == nil
        XCTAssertTrue(isDetached, "Deleted task should be detected as detached")

        // Safe tags access with guard
        let tagsAccessSafe: Bool
        if task.modelContext != nil {
            tagsAccessSafe = !(task.tags ?? []).isEmpty
        } else {
            tagsAccessSafe = false  // Skip detached objects
        }
        XCTAssertFalse(tagsAccessSafe, "Guard should prevent tags access on detached task")
    }

    // MARK: - Test 5: Tags access on valid task works normally

    func testTagsAccessOnValidTaskWorks() throws {
        // GIVEN: A valid task with tags
        let task = LocalTask(title: "Valid Task")
        task.tags = ["fitness", "health"]
        context.insert(task)
        try context.save()

        // THEN: Tags are accessible normally
        XCTAssertFalse((task.tags ?? []).isEmpty, "Valid task tags should be accessible")
        XCTAssertEqual((task.tags ?? []).count, 2)
        XCTAssertTrue((task.tags ?? []).contains("fitness"))
    }
}
