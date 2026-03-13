import XCTest
import CoreSpotlight
import SwiftData
@testable import FocusBlox

/// Integration tests for Spotlight wiring in SyncEngine lifecycle methods.
/// The SpotlightIndexingService logic is tested in SpotlightIndexingServiceTests (8 tests).
/// These tests verify the SyncEngine lifecycle correctly marks tasks as non-indexable.
@MainActor
final class SpotlightIntegrationTests: XCTestCase {

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

    // MARK: - Lifecycle Integration

    /// After SyncEngine.completeTask(), the task must not be Spotlight-indexable.
    /// Bricht wenn: completeTask() doesn't mark task as completed (shouldIndex filter)
    func test_completeTask_makesTaskNonIndexable() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Spotlight Complete Test", importance: 2)
        context.insert(task)
        try context.save()

        // Pre-condition: active task IS indexable
        XCTAssertTrue(SpotlightIndexingService.shared.shouldIndex(task),
                       "Active task should be indexable before completion")

        // Act: complete via SyncEngine
        try syncEngine.completeTask(itemID: task.id)

        // Assert: completed task is NOT indexable
        XCTAssertFalse(SpotlightIndexingService.shared.shouldIndex(task),
                        "Completed task should NOT be Spotlight-indexable")
    }

    /// After SyncEngine.deleteTask(), the task is gone from SwiftData.
    /// The wiring ensures deindexTask is also called (verified by code review, not unit-testable
    /// without DI since SpotlightIndexingService is a singleton actor).
    func test_deleteTask_removesTaskFromStore() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Spotlight Delete Test", importance: 1)
        context.insert(task)
        try context.save()

        let taskID = task.id

        // Act: delete via SyncEngine
        try syncEngine.deleteTask(itemID: taskID)

        // Assert: task gone from SwiftData
        let remaining = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertTrue(remaining.isEmpty, "Deleted task should be removed from store")
    }

    /// Indexing an active task via nonisolated helpers should not crash.
    /// Smoke test for the wiring call-site in LocalTaskSource.createTask.
    func test_indexTask_doesNotCrashForActiveTask() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Index Smoke Test", importance: 2)
        context.insert(task)
        try context.save()

        // Uses the same nonisolated + callback API as production code
        XCTAssertTrue(SpotlightIndexingService.shared.shouldIndex(task))
        let item = try SpotlightIndexingService.shared.buildSearchableItem(for: task)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    /// CSSearchableIndex.deleteSearchableItems should not crash for any UUID.
    /// Smoke test for the wiring call-site in SyncEngine.completeTask/deleteTask.
    func test_deindexTask_doesNotCrashForAnyUUID() {
        // Uses the same callback API as production code (avoids actor boundary issues)
        let uuid = UUID()
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [uuid.uuidString]) { _ in }
    }

    /// Templates must never appear in Spotlight.
    /// Bricht wenn: shouldIndex doesn't check isTemplate
    func test_templateTask_isNotIndexable() {
        let template = LocalTask(title: "Template", recurrencePattern: "daily")
        template.isTemplate = true
        XCTAssertFalse(SpotlightIndexingService.shared.shouldIndex(template),
                        "Template tasks must not be Spotlight-indexable")
    }
}
