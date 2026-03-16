import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class FocusBlockActionServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var mockRepo: MockEventKitRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = ModelContext(container)
        mockRepo = MockEventKitRepository()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        mockRepo = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func makeTask(
        id: String = UUID().uuidString,
        title: String = "Test Task",
        blockerTaskID: String? = nil,
        recurrencePattern: String = "none"
    ) -> LocalTask {
        let task = LocalTask(
            uuid: UUID(uuidString: id) ?? UUID(),
            title: title,
            importance: 2,
            estimatedDuration: 30,
            urgency: "medium",
            taskType: "maintenance",
            recurrencePattern: recurrencePattern
        )
        task.blockerTaskID = blockerTaskID
        context.insert(task)
        try? context.save()
        return task
    }

    private func makeBlock(
        taskIDs: [String],
        completedTaskIDs: [String] = [],
        taskTimes: [String: Int] = [:]
    ) -> FocusBlock {
        let block = FocusBlock(
            id: "event-\(UUID().uuidString)",
            title: "FocusBlox 09:00",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: taskIDs,
            completedTaskIDs: completedTaskIDs,
            taskTimes: taskTimes
        )
        mockRepo.mockFocusBlocks = [block]
        return block
    }

    // MARK: - completeTask — Happy Path

    /// Verhalten: Task wird als completed markiert, Block bekommt completedTaskID
    /// Bricht wenn: FocusBlockActionService.swift:58 — `localTask.isCompleted = true` entfernt
    func test_completeTask_happyPath_marksTaskCompleted() throws {
        let task = makeTask()
        let block = makeBlock(taskIDs: [task.id])

        let result = try FocusBlockActionService.completeTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        XCTAssertEqual(result, .completed)
        XCTAssertTrue(task.isCompleted, "Task should be marked completed in SwiftData")
        XCTAssertNotNil(task.completedAt, "completedAt should be set")
    }

    /// Verhalten: completedTaskIDs im Block wird aktualisiert via EventKit
    /// Bricht wenn: FocusBlockActionService.swift:37-39 — updatedCompletedIDs Logik entfernt
    func test_completeTask_updatesBlockCompletedIDs() throws {
        let task = makeTask()
        let block = makeBlock(taskIDs: [task.id])

        _ = try FocusBlockActionService.completeTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        // Check mock was updated
        let updatedBlock = mockRepo.mockFocusBlocks.first
        XCTAssertTrue(
            updatedBlock?.completedTaskIDs.contains(task.id) == true,
            "Block's completedTaskIDs should contain the completed task"
        )
    }

    // MARK: - completeTask — Blocked Task

    /// Verhalten: Geblockte Tasks werden NICHT tatsaechlich completed
    /// Bricht wenn: FocusBlockActionService.swift:29-34 — Blocker-Check entfernt
    func test_completeTask_blockedTask_doesNotComplete() throws {
        let blockerTask = makeTask(title: "Blocker")
        let blockedTask = makeTask(title: "Blocked", blockerTaskID: blockerTask.id)
        let block = makeBlock(taskIDs: [blockedTask.id])

        let result = try FocusBlockActionService.completeTask(
            taskID: blockedTask.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        XCTAssertEqual(result, .completed, "Returns .completed but silently skips")
        XCTAssertFalse(
            blockedTask.isCompleted,
            "Blocked task should NOT actually be marked completed"
        )
    }

    // MARK: - completeTask — Clears Dependents

    /// Verhalten: Wenn Blocker-Task erledigt wird, werden Dependents freigegeben
    /// Bricht wenn: FocusBlockActionService.swift:64-69 — Dependent-Clearing entfernt
    func test_completeTask_clearsDependentBlockerIDs() throws {
        let blockerTask = makeTask(title: "Blocker")
        let dependentTask = makeTask(title: "Dependent", blockerTaskID: blockerTask.id)
        let block = makeBlock(taskIDs: [blockerTask.id])

        _ = try FocusBlockActionService.completeTask(
            taskID: blockerTask.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        // Re-fetch dependent task
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let dep = allTasks.first { $0.id == dependentTask.id }

        XCTAssertNil(dep?.blockerTaskID, "Dependent's blockerTaskID should be cleared")
    }

    // MARK: - completeTask — assignedFocusBlockID Cleared

    /// Verhalten: assignedFocusBlockID wird auf nil gesetzt (Bug 52)
    /// Bricht wenn: FocusBlockActionService.swift:60 — `assignedFocusBlockID = nil` entfernt
    func test_completeTask_clearsAssignedFocusBlockID() throws {
        let task = makeTask()
        task.assignedFocusBlockID = "some-block-id"
        try context.save()

        let block = makeBlock(taskIDs: [task.id])

        _ = try FocusBlockActionService.completeTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        XCTAssertNil(task.assignedFocusBlockID, "assignedFocusBlockID should be cleared on complete")
    }

    // MARK: - skipTask — Multiple Remaining

    /// Verhalten: Skip verschiebt Task ans Ende der Queue
    /// Bricht wenn: FocusBlockActionService.swift:126-130 — Queue-Reorder Logik entfernt
    func test_skipTask_multipleRemaining_reordersQueue() throws {
        let block = makeBlock(taskIDs: ["task-A", "task-B", "task-C"])

        let result = try FocusBlockActionService.skipTask(
            taskID: "task-A",
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo
        )

        XCTAssertEqual(result, .skipped)

        let updatedBlock = mockRepo.mockFocusBlocks.first
        XCTAssertEqual(
            updatedBlock?.taskIDs,
            ["task-B", "task-C", "task-A"],
            "Skipped task should move to end of queue"
        )
    }

    // MARK: - skipTask — Last Remaining (Bug 15)

    /// Verhalten: Letzter verbleibender Task → auto-complete → .skippedLast
    /// Bricht wenn: FocusBlockActionService.swift:113-123 — isOnlyRemainingTask Branch entfernt
    func test_skipTask_lastRemaining_returnsSkippedLast() throws {
        // 2 tasks, 1 already completed → only "task-B" remaining
        let block = makeBlock(
            taskIDs: ["task-A", "task-B"],
            completedTaskIDs: ["task-A"]
        )

        let result = try FocusBlockActionService.skipTask(
            taskID: "task-B",
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo
        )

        XCTAssertEqual(result, .skippedLast, "Last remaining task should return .skippedLast")

        let updatedBlock = mockRepo.mockFocusBlocks.first
        XCTAssertTrue(
            updatedBlock?.completedTaskIDs.contains("task-B") == true,
            "Last skipped task should be added to completedTaskIDs"
        )
    }

    // MARK: - completeTask — TaskTimes

    /// Verhalten: taskTimes wird mit Zeiterfassung aktualisiert
    /// Bricht wenn: FocusBlockActionService.swift:41-45 — taskTimes Akkumulation entfernt
    func test_completeTask_updatesTaskTimes() throws {
        let task = makeTask()
        let block = makeBlock(taskIDs: [task.id])
        let startTime = Date().addingTimeInterval(-120) // 2 min ago

        _ = try FocusBlockActionService.completeTask(
            taskID: task.id,
            block: block,
            taskStartTime: startTime,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        let updatedBlock = mockRepo.mockFocusBlocks.first
        let recordedSeconds = updatedBlock?.taskTimes[task.id] ?? 0
        // Started 120 seconds ago, should record ~120s (±5s tolerance for execution time)
        XCTAssertGreaterThan(recordedSeconds, 100, "Should record ~120 seconds of work")
        XCTAssertLessThan(recordedSeconds, 150, "Should not record more than ~150 seconds")
    }

    // MARK: - completeTask — Recurring Task

    /// Verhalten: Wiederkehrender Task erzeugt naechste Instanz
    /// Bricht wenn: FocusBlockActionService.swift:72-74 — RecurrenceService.createNextInstance entfernt
    func test_completeTask_recurringTask_createsNextInstance() throws {
        let task = makeTask(recurrencePattern: "daily")
        task.dueDate = Date() // RecurrenceService needs dueDate
        try context.save()
        let block = makeBlock(taskIDs: [task.id])

        _ = try FocusBlockActionService.completeTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        // A new task should have been created by RecurrenceService
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let newInstances = allTasks.filter { $0.id != task.id && $0.title == task.title }

        XCTAssertFalse(
            newInstances.isEmpty,
            "Recurring task completion should create next instance"
        )
    }

    // MARK: - skipTask — TaskTimes

    /// Verhalten: Auch beim Skip wird die investierte Zeit erfasst
    /// Bricht wenn: FocusBlockActionService.swift:107-111 — taskTimes Update in skipTask entfernt
    func test_skipTask_updatesTaskTimes() throws {
        let block = makeBlock(taskIDs: ["task-X", "task-Y"])
        let startTime = Date().addingTimeInterval(-60) // 1 min ago

        _ = try FocusBlockActionService.skipTask(
            taskID: "task-X",
            block: block,
            taskStartTime: startTime,
            eventKitRepo: mockRepo
        )

        let updatedBlock = mockRepo.mockFocusBlocks.first
        let recordedSeconds = updatedBlock?.taskTimes["task-X"] ?? 0
        XCTAssertGreaterThan(recordedSeconds, 40, "Skip should also record time (~60s)")
        XCTAssertLessThan(recordedSeconds, 90, "Should not record more than ~90 seconds")
    }

    // MARK: - skipTask — Does NOT modify LocalTask

    /// Verhalten: Skip aendert NICHT den LocalTask-Status (nur Queue-Reihenfolge)
    /// Bricht wenn: skipTask faelschlicherweise isCompleted setzt
    func test_skipTask_doesNotModifyLocalTask() throws {
        let task = makeTask()
        let block = makeBlock(taskIDs: [task.id, "other-task"])

        _ = try FocusBlockActionService.skipTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo
        )

        XCTAssertFalse(task.isCompleted, "Skip should NOT mark task as completed")
        XCTAssertNil(task.completedAt, "Skip should NOT set completedAt")
    }

    // MARK: - followUpTask — Original wird completed

    /// Verhalten: followUpTask completed den Original-Task (wie "Erledigt")
    /// Bricht wenn: FocusBlockActionService.followUpTask — completeTask-Aufruf entfernt
    func test_followUpTask_completesOriginalTask() throws {
        let task = makeTask(title: "Anfrage senden")
        let block = makeBlock(taskIDs: [task.id])

        _ = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        XCTAssertTrue(task.isCompleted, "Original task should be marked completed")
        XCTAssertNotNil(task.completedAt, "Original task should have completedAt set")
    }

    // MARK: - followUpTask — Kopie wird erstellt

    /// Verhalten: followUpTask erstellt eine neue LocalTask als Kopie
    /// Bricht wenn: FocusBlockActionService.followUpTask — Task-Insert in ModelContext entfernt
    func test_followUpTask_createsNewTask() throws {
        let task = makeTask(title: "Anfrage senden")
        let block = makeBlock(taskIDs: [task.id])

        let result = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        // Result should be .followedUp with a new task ID
        guard case .followedUp(let newTaskID) = result else {
            XCTFail("Expected .followedUp result, got \(result)")
            return
        }

        // New task should exist in context
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let newTask = allTasks.first { $0.id == newTaskID }

        XCTAssertNotNil(newTask, "New follow-up task should exist in model context")
        XCTAssertNotEqual(newTaskID, task.id, "New task should have different ID")
    }

    // MARK: - followUpTask — Metadaten werden kopiert

    /// Verhalten: Kopie uebernimmt title, importance, urgency, estimatedDuration, taskType, tags
    /// Bricht wenn: FocusBlockActionService.followUpTask — Feld-Kopierung unvollstaendig
    func test_followUpTask_copiesMetadata() throws {
        let task = makeTask(title: "E-Mail an Chef")
        task.urgency = "urgent"
        task.estimatedDuration = 45
        task.taskType = "income"
        task.tags = ["Arbeit", "Wichtig"]
        task.dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        task.taskDescription = "Gehaltsverhandlung vorbereiten"
        try context.save()

        let block = makeBlock(taskIDs: [task.id])

        let result = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        guard case .followedUp(let newTaskID) = result else {
            XCTFail("Expected .followedUp result")
            return
        }

        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let copy = allTasks.first { $0.id == newTaskID }!

        XCTAssertEqual(copy.title, "E-Mail an Chef", "Title should be copied")
        XCTAssertEqual(copy.importance, 2, "Importance should be copied")
        XCTAssertEqual(copy.urgency, "urgent", "Urgency should be copied")
        XCTAssertEqual(copy.estimatedDuration, 45, "Duration should be copied")
        XCTAssertEqual(copy.taskType, "income", "TaskType should be copied")
        XCTAssertEqual(copy.tags, ["Arbeit", "Wichtig"], "Tags should be copied")
        XCTAssertEqual(copy.dueDate, task.dueDate, "DueDate should be copied")
        XCTAssertEqual(copy.taskDescription, "Gehaltsverhandlung vorbereiten", "Description should be copied")
    }

    // MARK: - followUpTask — Status-Felder werden zurueckgesetzt

    /// Verhalten: Kopie hat isCompleted=false, assignedFocusBlockID=nil, isNextUp=false
    /// Bricht wenn: FocusBlockActionService.followUpTask — Status-Reset fehlt
    func test_followUpTask_resetsStatusFields() throws {
        let task = makeTask(title: "Review PR")
        task.assignedFocusBlockID = "block-123"
        task.isNextUp = true
        try context.save()

        let block = makeBlock(taskIDs: [task.id])

        let result = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        guard case .followedUp(let newTaskID) = result else {
            XCTFail("Expected .followedUp result")
            return
        }

        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let copy = allTasks.first { $0.id == newTaskID }!

        XCTAssertFalse(copy.isCompleted, "Copy should not be completed")
        XCTAssertNil(copy.completedAt, "Copy should not have completedAt")
        XCTAssertNil(copy.assignedFocusBlockID, "Copy should not be assigned to a block")
        XCTAssertFalse(copy.isNextUp, "Copy should not be NextUp")
    }

    // MARK: - followUpTask — Recurrence und Blocker werden nicht kopiert

    /// Verhalten: Kopie hat recurrencePattern="none", blockerTaskID=nil
    /// Bricht wenn: FocusBlockActionService.followUpTask — recurrence/blocker Reset fehlt
    func test_followUpTask_resetsRecurrenceAndBlocker() throws {
        let blockerTask = makeTask(title: "Blocker")
        let task = makeTask(title: "Recurring Task", recurrencePattern: "daily")
        task.blockerTaskID = blockerTask.id
        task.recurrenceGroupID = "group-abc"
        try context.save()

        let block = makeBlock(taskIDs: [task.id])

        let result = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        guard case .followedUp(let newTaskID) = result else {
            XCTFail("Expected .followedUp result")
            return
        }

        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try context.fetch(descriptor)
        let copy = allTasks.first { $0.id == newTaskID }!

        XCTAssertEqual(copy.recurrencePattern, "none", "Copy should not be recurring")
        XCTAssertNil(copy.blockerTaskID, "Copy should not have a blocker")
        XCTAssertNil(copy.recurrenceGroupID, "Copy should not be in a recurrence group")
    }

    // MARK: - followUpTask — Block completedTaskIDs aktualisiert

    /// Verhalten: Original-TaskID ist in completedTaskIDs des Blocks
    /// Bricht wenn: FocusBlockActionService.followUpTask — completeTask-Delegation fehlt
    func test_followUpTask_updatesBlockCompletedIDs() throws {
        let task = makeTask(title: "Feedback einholen")
        let block = makeBlock(taskIDs: [task.id])

        _ = try FocusBlockActionService.followUpTask(
            taskID: task.id,
            block: block,
            taskStartTime: nil,
            eventKitRepo: mockRepo,
            modelContext: context
        )

        let updatedBlock = mockRepo.mockFocusBlocks.first
        XCTAssertTrue(
            updatedBlock?.completedTaskIDs.contains(task.id) == true,
            "Original task should be in block's completedTaskIDs"
        )
    }
}
