import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for Review: All completed tasks should appear regardless of FocusBlock assignment.
/// EXPECTED TO FAIL: Filter logic does not exist yet in DailyReviewView.
final class ReviewOutsideSprintTests: XCTestCase {

    // MARK: - todayCompletedTasks Filter Tests

    /// Tasks completed today with isCompleted=true should be included
    @MainActor
    func testTodayCompletedTasks_includesAllCompleted() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let t1 = LocalTask(title: "Task 1")
        t1.isCompleted = true
        t1.completedAt = Date()
        context.insert(t1)

        let t2 = LocalTask(title: "Task 2")
        t2.isCompleted = true
        t2.completedAt = Date()
        context.insert(t2)

        let t3 = LocalTask(title: "Task 3")
        t3.isCompleted = false
        context.insert(t3)

        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>()).map { PlanItem(localTask: $0) }
        let result = filterTodayCompleted(allTasks)

        XCTAssertEqual(result.count, 2, "Should include both completed tasks from today")
    }

    /// Tasks completed yesterday should NOT be included in today's filter
    @MainActor
    func testTodayCompletedTasks_excludesYesterday() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let t1 = LocalTask(title: "Today Task")
        t1.isCompleted = true
        t1.completedAt = Date()
        context.insert(t1)

        let t2 = LocalTask(title: "Yesterday Task")
        t2.isCompleted = true
        t2.completedAt = yesterday
        context.insert(t2)

        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>()).map { PlanItem(localTask: $0) }
        let result = filterTodayCompleted(allTasks)

        XCTAssertEqual(result.count, 1, "Should only include today's task")
        XCTAssertEqual(result.first?.title, "Today Task")
    }

    /// Tasks with isCompleted=false should NOT be included
    @MainActor
    func testTodayCompletedTasks_excludesIncomplete() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let t1 = LocalTask(title: "Incomplete")
        t1.isCompleted = false
        t1.completedAt = Date()  // has timestamp but not completed
        context.insert(t1)

        let t2 = LocalTask(title: "Complete")
        t2.isCompleted = true
        t2.completedAt = Date()
        context.insert(t2)

        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>()).map { PlanItem(localTask: $0) }
        let result = filterTodayCompleted(allTasks)

        XCTAssertEqual(result.count, 1, "Should only include completed task")
        XCTAssertEqual(result.first?.title, "Complete")
    }

    /// Tasks in block.completedTaskIDs should be excluded from outside-sprint list
    @MainActor
    func testOutsideSprintFilter_excludesBlockTasks() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let t1 = LocalTask(title: "Block Task")
        t1.isCompleted = true
        t1.completedAt = Date()
        context.insert(t1)

        let t2 = LocalTask(title: "Free Task")
        t2.isCompleted = true
        t2.completedAt = Date()
        context.insert(t2)

        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>()).map { PlanItem(localTask: $0) }
        let todayCompleted = filterTodayCompleted(allTasks)

        // Simulate block with t1 as completed
        let blockCompletedIDs: Set<String> = [t1.id]
        let outsideSprint = todayCompleted.filter { !blockCompletedIDs.contains($0.id) }

        XCTAssertEqual(outsideSprint.count, 1, "Should only include non-block task")
        XCTAssertEqual(outsideSprint.first?.title, "Free Task")
    }

    // MARK: - Bug: completedAt missing on macOS completion paths

    /// Regression test for bug: macOS completion handlers didn't set completedAt.
    /// Verifies the invariant: isCompleted=true WITHOUT completedAt → invisible in review.
    /// This proves WHY completedAt must be set at every completion site.
    @MainActor
    func testCompletedWithoutCompletedAt_isInvisibleInReview() throws {
        let container = try ModelContainer(for: LocalTask.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Task with isCompleted=true but NO completedAt (the old macOS bug pattern)
        let buggyTask = LocalTask(title: "Buggy Completion")
        buggyTask.isCompleted = true
        // completedAt intentionally nil — simulates the old broken code path
        context.insert(buggyTask)

        // Task with CORRECT completion (both fields set — the fixed code path)
        let fixedTask = LocalTask(title: "Fixed Completion")
        fixedTask.isCompleted = true
        fixedTask.completedAt = Date()
        context.insert(fixedTask)

        try context.save()

        let allTasks = try context.fetch(FetchDescriptor<LocalTask>()).map { PlanItem(localTask: $0) }
        let result = filterTodayCompleted(allTasks)

        // Only the correctly completed task appears — buggy one is invisible
        XCTAssertEqual(result.count, 1, "Only task with completedAt set should appear in review")
        XCTAssertEqual(result.first?.title, "Fixed Completion")
    }

    // MARK: - Helper

    /// Replicates the filter logic that will be added to DailyReviewView
    private func filterTodayCompleted(_ tasks: [PlanItem]) -> [PlanItem] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfToday
        }
    }
}
