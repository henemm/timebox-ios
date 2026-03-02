import XCTest
import SwiftData
@testable import FocusBlox

/// Regression tests for Bug: arithmetic overflow in macOS addToNextUp()
/// Root cause: Int.max used as sentinel + macOS did max() + 1 locally
/// Fix: macOS uses SyncEngine.updateNextUp() instead of local addToNextUp()
@MainActor
final class NextUpOverflowTests: XCTestCase {

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

    // MARK: - Overflow Regression Test

    /// Verhalten: Adding a second task to Next Up when first has Int.max sortOrder must NOT crash
    /// Bricht wenn: SyncEngine.updateNextUp does max() + 1 instead of safe assignment
    ///
    /// Reproduces the original crash:
    /// 1. Task A is added to Next Up (gets nextUpSortOrder = Int.max)
    /// 2. Task B is added to Next Up via SyncEngine
    /// 3. No arithmetic overflow should occur
    func test_addToNextUp_withExistingIntMaxSortOrder_doesNotOverflow() throws {
        let context = container.mainContext

        // Task A already in Next Up with Int.max (set by previous SyncEngine call)
        let taskA = LocalTask(title: "Task A", importance: 1)
        taskA.isNextUp = true
        taskA.nextUpSortOrder = Int.max
        context.insert(taskA)

        // Task B to be added
        let taskB = LocalTask(title: "Task B", importance: 2)
        context.insert(taskB)
        try context.save()

        // This was the crash: old macOS code did max() + 1 = Int.max + 1 = OVERFLOW
        // SyncEngine.updateNextUp sets Int.max directly, no addition
        try syncEngine.updateNextUp(itemID: taskB.id, isNextUp: true)

        XCTAssertTrue(taskB.isNextUp, "Task B should be in Next Up")
        XCTAssertNotNil(taskB.nextUpSortOrder, "Task B should have a sort order")
    }

    /// Verhalten: Adding multiple tasks sequentially via SyncEngine never overflows
    /// Bricht wenn: SyncEngine.updateNextUp accumulates sort orders unsafely
    func test_addMultipleTasksToNextUp_viaSync_doesNotOverflow() throws {
        let context = container.mainContext

        // Create 5 tasks
        var tasks: [LocalTask] = []
        for i in 1...5 {
            let task = LocalTask(title: "Task \(i)", importance: 1)
            context.insert(task)
            tasks.append(task)
        }
        try context.save()

        // Add all 5 to Next Up via SyncEngine (the correct path)
        for task in tasks {
            try syncEngine.updateNextUp(itemID: task.id, isNextUp: true)
        }

        // All should be Next Up with valid sort orders
        let nextUpTasks = tasks.filter { $0.isNextUp }
        XCTAssertEqual(nextUpTasks.count, 5, "All 5 tasks should be in Next Up")
        XCTAssertTrue(nextUpTasks.allSatisfy { $0.nextUpSortOrder != nil },
                      "All should have sort orders")
    }

    // MARK: - SyncEngine updateNextUp Behavior

    /// Verhalten: updateNextUp(isNextUp: false) clears sortOrder AND assignedFocusBlockID
    /// Bricht wenn: removeFromNextUp doesn't clear assignedFocusBlockID (Bug 52 regression)
    ///
    /// The old macOS removeFromNextUp only cleared isNextUp + nextUpSortOrder,
    /// but NOT assignedFocusBlockID. SyncEngine does all three.
    func test_removeFromNextUp_viaSyncEngine_clearsBlockAssignment() throws {
        let context = container.mainContext

        let task = LocalTask(title: "Assigned Task", importance: 1)
        task.isNextUp = true
        task.nextUpSortOrder = 5
        task.assignedFocusBlockID = "some-block-id"
        context.insert(task)
        try context.save()

        try syncEngine.updateNextUp(itemID: task.id, isNextUp: false)

        XCTAssertFalse(task.isNextUp, "Should no longer be Next Up")
        XCTAssertNil(task.nextUpSortOrder, "Sort order should be cleared")
        XCTAssertNil(task.assignedFocusBlockID,
                     "Block assignment should be cleared (Bug 52)")
    }

    /// Verhalten: updateNextUp preserves existing sortOrder when already in Next Up
    /// Bricht wenn: updateNextUp overwrites existing sort order on re-add
    func test_updateNextUp_alreadyInNextUp_preservesSortOrder() throws {
        let context = container.mainContext

        let task = LocalTask(title: "Already Next Up", importance: 1)
        task.isNextUp = true
        task.nextUpSortOrder = 3  // already has an order
        context.insert(task)
        try context.save()

        // Re-adding should preserve existing order (not reset to Int.max)
        try syncEngine.updateNextUp(itemID: task.id, isNextUp: true)

        XCTAssertTrue(task.isNextUp)
        XCTAssertEqual(task.nextUpSortOrder, 3,
                       "Existing sort order should be preserved, not overwritten")
    }
}
