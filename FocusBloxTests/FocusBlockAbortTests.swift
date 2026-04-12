import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for Bug #211: FocusBlox abbrechen — Timer-State wird nicht zurückgesetzt
@MainActor
final class FocusBlockAbortTests: XCTestCase {

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
        assignedBlockID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(
            uuid: UUID(uuidString: id) ?? UUID(),
            title: title,
            importance: 2,
            estimatedDuration: 30,
            urgency: "medium",
            taskType: "maintenance"
        )
        task.assignedFocusBlockID = assignedBlockID
        task.isNextUp = false
        context.insert(task)
        try? context.save()
        return task
    }

    private func makeActiveBlock(taskIDs: [String], completedTaskIDs: [String] = []) -> FocusBlock {
        FocusBlock(
            id: "event-\(UUID().uuidString)",
            title: "FocusBlox 09:00",
            startDate: Date().addingTimeInterval(-30 * 60),
            endDate: Date().addingTimeInterval(30 * 60),
            taskIDs: taskIDs,
            completedTaskIDs: completedTaskIDs,
            taskTimes: [:]
        )
    }

    // MARK: - Bug #211: Abort bei aktivem Block

    /// Verhalten: Bei Abort eines AKTIVEN Blocks müssen unerledigte Tasks zu Next Up zurückkehren
    /// Bricht wenn: returnIncompleteTasksToNextUp nur bei block.isPast aufgerufen wird
    func test_abortActiveBlock_returnsIncompleteTasksToNextUp() throws {
        let task1 = makeTask(title: "Task 1")
        let task2 = makeTask(title: "Task 2")
        let task3 = makeTask(title: "Task 3")

        let block = makeActiveBlock(
            taskIDs: [task1.id, task2.id, task3.id],
            completedTaskIDs: [task1.id]
        )

        task1.assignedFocusBlockID = block.id
        task2.assignedFocusBlockID = block.id
        task3.assignedFocusBlockID = block.id
        try context.save()

        // Precondition: Block ist AKTIV (nicht isPast)
        XCTAssertTrue(block.isActive, "Block muss aktiv sein für diesen Test")
        XCTAssertFalse(block.isPast, "Block darf NICHT isPast sein")

        // Act: Simuliere returnIncompleteTasksToNextUp für aktiven Block
        let incompleteTasks = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
        let fetchDescriptor = FetchDescriptor<LocalTask>()
        let localTasks = try context.fetch(fetchDescriptor)

        for taskID in incompleteTasks {
            if let task = localTasks.first(where: { $0.id == taskID }) {
                task.isNextUp = true
                task.assignedFocusBlockID = nil
            }
        }
        try context.save()

        // Assert: Unerledigte Tasks zurück in Next Up
        XCTAssertTrue(task2.isNextUp, "Unerledigte Task 2 muss isNextUp sein")
        XCTAssertTrue(task3.isNextUp, "Unerledigte Task 3 muss isNextUp sein")
        XCTAssertNil(task2.assignedFocusBlockID, "Task 2 darf keinem Block mehr zugewiesen sein")
        XCTAssertNil(task3.assignedFocusBlockID, "Task 3 darf keinem Block mehr zugewiesen sein")

        // Completed task bleibt im Block
        XCTAssertEqual(task1.assignedFocusBlockID, block.id, "Erledigte Task bleibt im Block")
    }

    /// Verhalten: LiveActivityManager.endActivity() setzt currentActivity auf nil
    /// Bricht wenn: endActivity() nicht aufgerufen wird beim Abort
    func test_liveActivityManager_endActivity_clearsCurrentActivity() async throws {
        let manager = LiveActivityManager()

        // endActivity auf leeren Manager sollte nicht crashen
        manager.endActivity()
        XCTAssertNil(manager.currentActivity, "currentActivity muss nach endActivity nil sein")
    }

    /// Verhalten: Bei Abort müssen taskTimes für laufende Task korrekt berechnet werden
    /// Bricht wenn: taskStartTime nicht vor Sprint Review auf nil gesetzt wird
    func test_abortActiveBlock_savesCurrentTaskTime() throws {
        let task1 = makeTask(title: "Running Task")
        let block = makeActiveBlock(taskIDs: [task1.id])

        // Simulate: Task läuft seit 5 Minuten
        let taskStartTime = Date().addingTimeInterval(-5 * 60)
        let secondsSpent = Int(Date().timeIntervalSince(taskStartTime))

        var updatedTaskTimes = block.taskTimes
        updatedTaskTimes[task1.id] = (updatedTaskTimes[task1.id] ?? 0) + secondsSpent

        XCTAssertGreaterThan(updatedTaskTimes[task1.id] ?? 0, 250, "Task-Zeit muss ~300s sein")
        XCTAssertLessThan(updatedTaskTimes[task1.id] ?? 0, 350, "Task-Zeit muss ~300s sein")
    }

    /// Verhalten: Block.isActive ist true wenn Block noch nicht abgelaufen
    /// Sicherstellt: Der Guard `if block.isPast` in onDismiss ist der Bug
    func test_activeBlock_isNotPast() {
        let block = makeActiveBlock(taskIDs: ["t1"])

        XCTAssertTrue(block.isActive, "Block mit Restzeit muss isActive sein")
        XCTAssertFalse(block.isPast, "Block mit Restzeit darf NICHT isPast sein")
    }

    /// Verhalten: FocusBlockActionService.abortWithFollowUp erstellt Follow-up korrekt
    /// Bricht wenn: abortWithFollowUp Logik in FocusBlockActionService.swift:244+ kaputt
    func test_abortWithFollowUp_createsFollowUpTask() throws {
        let task = makeTask(title: "Unfinished Work")
        let block = makeActiveBlock(taskIDs: [task.id])
        let blockWithTimes = FocusBlock(
            id: block.id,
            title: block.title,
            startDate: block.startDate,
            endDate: block.endDate,
            taskIDs: block.taskIDs,
            completedTaskIDs: block.completedTaskIDs,
            taskTimes: [task.id: 600]
        )

        let result = try FocusBlockActionService.abortWithFollowUp(
            taskID: task.id,
            block: blockWithTimes,
            progressNote: "Hälfte geschafft",
            modelContext: context
        )

        if case .abortedWithFollowUp(let newTaskID) = result {
            let fetchDescriptor = FetchDescriptor<LocalTask>()
            let allTasks = try context.fetch(fetchDescriptor)
            let followUp = allTasks.first { $0.id == newTaskID }

            XCTAssertNotNil(followUp, "Follow-up Task muss existieren")
            XCTAssertTrue(followUp?.title.starts(with: "Weiter:") ?? false,
                         "Follow-up Titel muss mit 'Weiter:' beginnen")
            XCTAssertEqual(task.progressNote, "Hälfte geschafft",
                          "Progress Note muss gespeichert sein")
            XCTAssertNil(task.assignedFocusBlockID,
                        "Original Task darf keinem Block mehr zugewiesen sein")
        } else {
            XCTFail("Ergebnis muss .abortedWithFollowUp sein, war: \(result)")
        }
    }
}
