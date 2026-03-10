import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for Bug: Category change not immediately visible in BacklogView.
///
/// Root Cause: updateCategory() saves to DB via SyncEngine but doesn't update
/// the in-memory planItems array, unlike updateImportance/updateUrgency which do.
///
/// Bricht wenn: BacklogView.updateCategory() doesn't refresh the PlanItem
/// after SyncEngine.updateTask saves the new category.
@MainActor
final class CategoryUpdateRefreshTests: XCTestCase {

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

    // MARK: - Category Update Persistence

    /// After SyncEngine.updateTask with new taskType, the LocalTask must reflect the new category.
    /// Bricht wenn: SyncEngine.swift:82 — task.taskType assignment removed.
    func test_updateTask_persistsNewCategory() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task", importance: 2)
        task.taskType = "income"
        context.insert(task)
        try context.save()

        try syncEngine.updateTask(
            itemID: task.id, title: task.title, importance: task.importance,
            duration: task.estimatedDuration, tags: task.tags, urgency: task.urgency,
            taskType: "learning", dueDate: task.dueDate, description: task.taskDescription
        )

        XCTAssertEqual(task.taskType, "learning",
            "SyncEngine.updateTask must persist the new category on LocalTask")
    }

    /// A PlanItem created from an updated LocalTask must reflect the new category.
    /// This is the pattern that updateCategory() must use (like updateImportance does).
    /// Bricht wenn: PlanItem(localTask:) doesn't copy taskType correctly.
    func test_planItem_reflectsUpdatedCategory() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task", importance: 2)
        task.taskType = "income"
        context.insert(task)
        try context.save()

        // Simulate what updateCategory SHOULD do: update + create fresh PlanItem
        try syncEngine.updateTask(
            itemID: task.id, title: task.title, importance: task.importance,
            duration: task.estimatedDuration, tags: task.tags, urgency: task.urgency,
            taskType: "recharge", dueDate: task.dueDate, description: task.taskDescription
        )

        let freshPlanItem = PlanItem(localTask: task)
        XCTAssertEqual(freshPlanItem.taskType, "recharge",
            "Fresh PlanItem from updated LocalTask must show new category")
    }

    /// A stale PlanItem (created BEFORE the update) still shows the old category.
    /// This proves WHY the bug exists: PlanItem is a value type, it doesn't auto-update.
    /// Bricht wenn: PlanItem becomes a reference type (unlikely).
    func test_stalePlanItem_showsOldCategory() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task", importance: 2)
        task.taskType = "income"
        context.insert(task)
        try context.save()

        // Create PlanItem BEFORE update (this is what BacklogView holds in planItems array)
        let stalePlanItem = PlanItem(localTask: task)

        // Update category in DB
        try syncEngine.updateTask(
            itemID: task.id, title: task.title, importance: task.importance,
            duration: task.estimatedDuration, tags: task.tags, urgency: task.urgency,
            taskType: "learning", dueDate: task.dueDate, description: task.taskDescription
        )

        // Stale PlanItem still shows old value — this IS the bug
        XCTAssertEqual(stalePlanItem.taskType, "income",
            "Stale PlanItem must still show old category (value type, not auto-updated)")

        // Fresh PlanItem shows correct value — this is what the fix must produce
        let freshPlanItem = PlanItem(localTask: task)
        XCTAssertEqual(freshPlanItem.taskType, "learning",
            "Fresh PlanItem must show updated category")
    }

    /// After updateTask + re-fetch, a fresh PlanItem array contains the correct category.
    /// This simulates what refreshLocalTasks() does (the delayed path via DeferredSort).
    /// Bricht wenn: SyncEngine.sync() doesn't include taskType in PlanItem creation.
    func test_syncAfterCategoryUpdate_returnsCorrectCategory() async throws {
        let context = container.mainContext
        let task = LocalTask(title: "Sync Test", importance: 1)
        task.taskType = "income"
        context.insert(task)
        try context.save()

        try syncEngine.updateTask(
            itemID: task.id, title: task.title, importance: task.importance,
            duration: task.estimatedDuration, tags: task.tags, urgency: task.urgency,
            taskType: "giving_back", dueDate: task.dueDate, description: task.taskDescription
        )

        let planItems = try await syncEngine.sync()
        let updatedItem = planItems.first(where: { $0.id == task.id })

        XCTAssertNotNil(updatedItem, "Task should appear in sync results")
        XCTAssertEqual(updatedItem?.taskType, "giving_back",
            "After sync, PlanItem must reflect the updated category")
    }
}
