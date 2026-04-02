//
//  TaskDataChangedNotificationTests.swift
//  FocusBloxMacTests
//
//  Tests for Bug #189, #190, #191: macOS Refresh after local Task mutations
//

import XCTest
import SwiftData
@testable import FocusBloxMac

final class TaskDataChangedNotificationTests: XCTestCase {

    // MARK: - Notification Existence

    /// RED: Notification.Name.taskDataChanged must exist as a defined notification
    func testTaskDataChangedNotificationExists() {
        // This will fail until we define the extension on Notification.Name
        let name = Notification.Name.taskDataChanged
        XCTAssertEqual(name.rawValue, "taskDataChanged", "Notification name should be 'taskDataChanged'")
    }

    // MARK: - ContentView Refresh Pattern

    /// RED #190: After TaskInspector toggles isCompleted, refreshTasks pattern must show updated state
    @MainActor
    func testCompletedTaskDisappearsFromActiveListAfterRefresh() throws {
        let container = try MacModelContainer.create()
        let context = container.mainContext

        // Setup: Create an active task
        let testTitle = "Inspector Refresh Test \(UUID().uuidString)"
        let task = LocalTask(title: testTitle)
        task.lifecycleStatus = "active"
        context.insert(task)
        try context.save()

        // Simulate initial fetch (ContentView.refreshTasks pattern)
        var tasks = try context.fetch(FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
        ))
        let activeBefore = tasks.filter { !$0.isCompleted && $0.title == testTitle }
        XCTAssertEqual(activeBefore.count, 1, "Task should be active before toggle")

        // Simulate TaskInspector toggle: isCompleted = true + save
        task.isCompleted = true
        task.completedAt = Date()
        task.assignedFocusBlockID = nil
        task.isNextUp = false
        try context.save()

        // Simulate the refreshTasks() that SHOULD be triggered by notification
        try context.save()
        tasks = try context.fetch(FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
        ))
        let activeAfter = tasks.filter { !$0.isCompleted && $0.title == testTitle }

        XCTAssertEqual(activeAfter.count, 0, "Completed task must disappear from active list after refresh")

        // Cleanup
        context.delete(task)
        try context.save()
    }

    /// RED #191: After task assignment (isNextUp = false), task must leave Next Up list
    @MainActor
    func testTaskLeavesNextUpAfterAssignment() throws {
        let container = try MacModelContainer.create()
        let context = container.mainContext

        // Setup: Create a Next Up task
        let testTitle = "Assignment Refresh Test \(UUID().uuidString)"
        let task = LocalTask(title: testTitle)
        task.lifecycleStatus = "active"
        task.isNextUp = true
        task.nextUpSortOrder = 1
        context.insert(task)
        try context.save()

        // Verify task is in Next Up
        let nextUpBefore = try context.fetch(FetchDescriptor<LocalTask>())
            .filter { $0.isNextUp && !$0.isCompleted && $0.title == testTitle }
        XCTAssertEqual(nextUpBefore.count, 1, "Task should be in Next Up before assignment")

        // Simulate MacPlanningView.assignTaskToBlock: isNextUp = false
        task.isNextUp = false
        task.assignedFocusBlockID = "test-block-id"
        try context.save()

        // Simulate refreshTasks pattern
        try context.save()
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
        ))
        let nextUpAfter = allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.title == testTitle }

        XCTAssertEqual(nextUpAfter.count, 0, "Assigned task must not appear in Next Up after refresh")
        XCTAssertEqual(
            allTasks.first { $0.title == testTitle }?.assignedFocusBlockID,
            "test-block-id",
            "Task must have assigned block ID"
        )

        // Cleanup
        context.delete(task)
        try context.save()
    }

    /// RED #189: After sprint review, incomplete tasks must return to Next Up
    @MainActor
    func testIncompleteTasksReturnToNextUpAfterSprintReview() throws {
        let container = try MacModelContainer.create()
        let context = container.mainContext

        // Setup: Create a task assigned to a block (simulating in-progress focus)
        let testTitle = "Sprint Review Return Test \(UUID().uuidString)"
        let task = LocalTask(title: testTitle)
        task.lifecycleStatus = "active"
        task.isNextUp = false
        task.assignedFocusBlockID = "block-123"
        context.insert(task)
        try context.save()

        // Verify task is NOT in Next Up
        let nextUpBefore = try context.fetch(FetchDescriptor<LocalTask>())
            .filter { $0.isNextUp && $0.title == testTitle }
        XCTAssertEqual(nextUpBefore.count, 0, "Task should not be in Next Up while assigned to block")

        // Simulate returnIncompleteTasksToNextUp: isNextUp = true, assignedFocusBlockID = nil
        task.isNextUp = true
        task.assignedFocusBlockID = nil
        try context.save()

        // Simulate refreshTasks pattern
        try context.save()
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>(
            sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
        ))
        let nextUpAfter = allTasks.filter { $0.isNextUp && $0.title == testTitle }

        XCTAssertEqual(nextUpAfter.count, 1, "Incomplete task must return to Next Up after sprint review")

        // Cleanup
        context.delete(task)
        try context.save()
    }
}
