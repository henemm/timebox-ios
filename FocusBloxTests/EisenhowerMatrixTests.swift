import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class EisenhowerMatrixTests: XCTestCase {

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

    // MARK: - Test Data Helpers

    func createTask(title: String, priority: Int, urgency: String, isCompleted: Bool = false) -> LocalTask {
        let task = LocalTask(
            title: title,
            priority: priority,
            tags: [],
            dueDate: nil,
            manualDuration: nil,
            urgency: urgency,
            taskType: "maintenance",
            taskDescription: nil
        )
        task.isCompleted = isCompleted
        return task
    }

    // MARK: - Do First Quadrant (Urgent + Important)

    func test_doFirstQuadrant_filtersUrgentAndHighPriority() async throws {
        let context = container.mainContext

        // Do First: urgent + priority 3
        let doFirst1 = createTask(title: "Urgent Important 1", priority: 3, urgency: "urgent")
        let doFirst2 = createTask(title: "Urgent Important 2", priority: 3, urgency: "urgent")

        // Other quadrants
        let schedule = createTask(title: "Not Urgent Important", priority: 3, urgency: "not_urgent")
        let delegate = createTask(title: "Urgent Less Important", priority: 2, urgency: "urgent")
        let eliminate = createTask(title: "Not Urgent Less Important", priority: 1, urgency: "not_urgent")

        context.insert(doFirst1)
        context.insert(doFirst2)
        context.insert(schedule)
        context.insert(delegate)
        context.insert(eliminate)
        try context.save()

        let planItems = try await syncEngine.sync()

        // Filter: urgent + priority 3 + not completed
        let doFirstTasks = planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted }

        XCTAssertEqual(doFirstTasks.count, 2, "Should have exactly 2 tasks in Do First quadrant")
        XCTAssertTrue(doFirstTasks.contains { $0.title == "Urgent Important 1" })
        XCTAssertTrue(doFirstTasks.contains { $0.title == "Urgent Important 2" })
    }

    func test_doFirstQuadrant_excludesCompletedTasks() async throws {
        let context = container.mainContext

        let active = createTask(title: "Active Urgent", priority: 3, urgency: "urgent")
        let completed = createTask(title: "Completed Urgent", priority: 3, urgency: "urgent", isCompleted: true)

        context.insert(active)
        context.insert(completed)
        try context.save()

        let planItems = try await syncEngine.sync()
        let doFirstTasks = planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted }

        XCTAssertEqual(doFirstTasks.count, 1, "Should exclude completed tasks")
        XCTAssertEqual(doFirstTasks.first?.title, "Active Urgent")
    }

    // MARK: - Schedule Quadrant (Not Urgent + Important)

    func test_scheduleQuadrant_filtersNotUrgentAndHighPriority() async throws {
        let context = container.mainContext

        // Schedule: not_urgent + priority 3
        let schedule1 = createTask(title: "Plan This 1", priority: 3, urgency: "not_urgent")
        let schedule2 = createTask(title: "Plan This 2", priority: 3, urgency: "not_urgent")

        // Other quadrants
        let doFirst = createTask(title: "Urgent Important", priority: 3, urgency: "urgent")
        let delegate = createTask(title: "Urgent Less Important", priority: 2, urgency: "urgent")

        context.insert(schedule1)
        context.insert(schedule2)
        context.insert(doFirst)
        context.insert(delegate)
        try context.save()

        let planItems = try await syncEngine.sync()
        let scheduleTasks = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue == 3 && !$0.isCompleted }

        XCTAssertEqual(scheduleTasks.count, 2, "Should have exactly 2 tasks in Schedule quadrant")
        XCTAssertTrue(scheduleTasks.contains { $0.title == "Plan This 1" })
        XCTAssertTrue(scheduleTasks.contains { $0.title == "Plan This 2" })
    }

    // MARK: - Delegate Quadrant (Urgent + Less Important)

    func test_delegateQuadrant_filtersUrgentAndLowerPriority() async throws {
        let context = container.mainContext

        // Delegate: urgent + priority < 3
        let delegate1 = createTask(title: "Urgent Priority 2", priority: 2, urgency: "urgent")
        let delegate2 = createTask(title: "Urgent Priority 1", priority: 1, urgency: "urgent")
        let delegate3 = createTask(title: "Urgent Priority 0", priority: 0, urgency: "urgent")

        // Other quadrants
        let doFirst = createTask(title: "Urgent Priority 3", priority: 3, urgency: "urgent")

        context.insert(delegate1)
        context.insert(delegate2)
        context.insert(delegate3)
        context.insert(doFirst)
        try context.save()

        let planItems = try await syncEngine.sync()
        let delegateTasks = planItems.filter { $0.urgency == "urgent" && $0.priorityValue < 3 && !$0.isCompleted }

        XCTAssertEqual(delegateTasks.count, 3, "Should have exactly 3 tasks in Delegate quadrant")
        XCTAssertTrue(delegateTasks.contains { $0.title == "Urgent Priority 2" })
        XCTAssertTrue(delegateTasks.contains { $0.title == "Urgent Priority 1" })
        XCTAssertTrue(delegateTasks.contains { $0.title == "Urgent Priority 0" })
    }

    // MARK: - Eliminate Quadrant (Not Urgent + Less Important)

    func test_eliminateQuadrant_filtersNotUrgentAndLowerPriority() async throws {
        let context = container.mainContext

        // Eliminate: not_urgent + priority < 3
        let eliminate1 = createTask(title: "Low Priority 2", priority: 2, urgency: "not_urgent")
        let eliminate2 = createTask(title: "Low Priority 1", priority: 1, urgency: "not_urgent")
        let eliminate3 = createTask(title: "Low Priority 0", priority: 0, urgency: "not_urgent")

        // Other quadrants
        let schedule = createTask(title: "Not Urgent Priority 3", priority: 3, urgency: "not_urgent")

        context.insert(eliminate1)
        context.insert(eliminate2)
        context.insert(eliminate3)
        context.insert(schedule)
        try context.save()

        let planItems = try await syncEngine.sync()
        let eliminateTasks = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue < 3 && !$0.isCompleted }

        XCTAssertEqual(eliminateTasks.count, 3, "Should have exactly 3 tasks in Eliminate quadrant")
        XCTAssertTrue(eliminateTasks.contains { $0.title == "Low Priority 2" })
        XCTAssertTrue(eliminateTasks.contains { $0.title == "Low Priority 1" })
        XCTAssertTrue(eliminateTasks.contains { $0.title == "Low Priority 0" })
    }

    // MARK: - Edge Cases

    func test_allQuadrants_distributeTasksCorrectly() async throws {
        let context = container.mainContext

        // 1 task per quadrant
        let doFirst = createTask(title: "Q1: Do First", priority: 3, urgency: "urgent")
        let schedule = createTask(title: "Q2: Schedule", priority: 3, urgency: "not_urgent")
        let delegate = createTask(title: "Q3: Delegate", priority: 2, urgency: "urgent")
        let eliminate = createTask(title: "Q4: Eliminate", priority: 1, urgency: "not_urgent")

        context.insert(doFirst)
        context.insert(schedule)
        context.insert(delegate)
        context.insert(eliminate)
        try context.save()

        let planItems = try await syncEngine.sync()

        let q1 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q2 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q3 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue < 3 && !$0.isCompleted }
        let q4 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue < 3 && !$0.isCompleted }

        XCTAssertEqual(q1.count, 1, "Q1 should have 1 task")
        XCTAssertEqual(q2.count, 1, "Q2 should have 1 task")
        XCTAssertEqual(q3.count, 1, "Q3 should have 1 task")
        XCTAssertEqual(q4.count, 1, "Q4 should have 1 task")

        XCTAssertEqual(q1.first?.title, "Q1: Do First")
        XCTAssertEqual(q2.first?.title, "Q2: Schedule")
        XCTAssertEqual(q3.first?.title, "Q3: Delegate")
        XCTAssertEqual(q4.first?.title, "Q4: Eliminate")
    }

    func test_emptyState_allQuadrantsEmpty() async throws {
        // No tasks in database
        let planItems = try await syncEngine.sync()

        let q1 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q2 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q3 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue < 3 && !$0.isCompleted }
        let q4 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue < 3 && !$0.isCompleted }

        XCTAssertEqual(q1.count, 0, "Q1 should be empty")
        XCTAssertEqual(q2.count, 0, "Q2 should be empty")
        XCTAssertEqual(q3.count, 0, "Q3 should be empty")
        XCTAssertEqual(q4.count, 0, "Q4 should be empty")
    }

    func test_allTasksCompleted_allQuadrantsEmpty() async throws {
        let context = container.mainContext

        // All tasks completed
        let t1 = createTask(title: "Completed 1", priority: 3, urgency: "urgent", isCompleted: true)
        let t2 = createTask(title: "Completed 2", priority: 3, urgency: "not_urgent", isCompleted: true)
        let t3 = createTask(title: "Completed 3", priority: 2, urgency: "urgent", isCompleted: true)
        let t4 = createTask(title: "Completed 4", priority: 1, urgency: "not_urgent", isCompleted: true)

        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
        context.insert(t4)
        try context.save()

        let planItems = try await syncEngine.sync()

        let q1 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q2 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue == 3 && !$0.isCompleted }
        let q3 = planItems.filter { $0.urgency == "urgent" && $0.priorityValue < 3 && !$0.isCompleted }
        let q4 = planItems.filter { $0.urgency == "not_urgent" && $0.priorityValue < 3 && !$0.isCompleted }

        XCTAssertEqual(q1.count, 0, "Q1 should be empty (all completed)")
        XCTAssertEqual(q2.count, 0, "Q2 should be empty (all completed)")
        XCTAssertEqual(q3.count, 0, "Q3 should be empty (all completed)")
        XCTAssertEqual(q4.count, 0, "Q4 should be empty (all completed)")
    }
}
