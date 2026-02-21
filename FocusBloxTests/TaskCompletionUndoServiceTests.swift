import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class TaskCompletionUndoServiceTests: XCTestCase {

    private var modelContext: ModelContext!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        TaskCompletionUndoService.clear()
    }

    override func tearDownWithError() throws {
        TaskCompletionUndoService.clear()
        modelContext = nil
        container = nil
    }

    // MARK: - Snapshot Capture

    /// Verhalten: capture() speichert taskID, wasNextUp, assignedFocusBlockID
    /// Bricht wenn: TaskCompletionUndoService.capture() nicht implementiert oder Snapshot-Felder fehlen
    func test_capture_storesSnapshot_and_canUndo() {
        // Arrange
        let taskID = UUID().uuidString

        // Act
        TaskCompletionUndoService.capture(
            taskID: taskID,
            wasNextUp: true,
            assignedFocusBlockID: "block-123"
        )

        // Assert
        XCTAssertTrue(TaskCompletionUndoService.canUndo, "canUndo should be true after capture")
    }

    /// Verhalten: Zweites capture() ersetzt den alten Snapshot
    /// Bricht wenn: capture() den alten Snapshot nicht ueberschreibt
    func test_newCompletion_replacesOldSnapshot() throws {
        // Arrange: Zwei Tasks anlegen
        let task1 = LocalTask(title: "Task 1")
        let task2 = LocalTask(title: "Task 2")
        task1.isCompleted = true
        task1.completedAt = Date()
        task2.isCompleted = true
        task2.completedAt = Date()
        modelContext.insert(task1)
        modelContext.insert(task2)
        try modelContext.save()

        // Act: Erst Task1, dann Task2 capturen
        TaskCompletionUndoService.capture(
            taskID: task1.id,
            wasNextUp: false,
            assignedFocusBlockID: nil
        )
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        TaskCompletionUndoService.capture(
            taskID: task2.id,
            wasNextUp: true,
            assignedFocusBlockID: "block-xyz"
        )
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        // Assert: Undo stellt Task2 wieder her (nicht Task1)
        let title = try TaskCompletionUndoService.undo(in: modelContext)
        XCTAssertEqual(title, "Task 2", "Undo should restore most recent completion")
        XCTAssertFalse(task2.isCompleted, "Task 2 should be uncompleted")
        XCTAssertTrue(task1.isCompleted, "Task 1 should still be completed")
    }

    // MARK: - Undo Restore

    /// Verhalten: undo() setzt isCompleted=false, completedAt=nil, stellt isNextUp + assignedFocusBlockID her
    /// Bricht wenn: Einer der 4 Zuweisungen in undo() fehlt
    func test_undo_restoresFullTaskState() throws {
        // Arrange: Task mit NextUp und Block-Assignment anlegen, dann "abhaken"
        let task = LocalTask(title: "Wichtiger Task")
        task.isNextUp = false // Wird auf true im Snapshot
        task.isCompleted = true
        task.completedAt = Date()
        task.assignedFocusBlockID = nil
        modelContext.insert(task)
        try modelContext.save()

        // Capture mit Original-Zustand VOR Completion
        TaskCompletionUndoService.capture(
            taskID: task.id,
            wasNextUp: true,
            assignedFocusBlockID: "focus-block-42"
        )
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        // Act
        let title = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert: Vollstaendiger Originalzustand
        XCTAssertEqual(title, "Wichtiger Task")
        XCTAssertFalse(task.isCompleted, "Should be uncompleted")
        XCTAssertNil(task.completedAt, "completedAt should be nil")
        XCTAssertTrue(task.isNextUp, "isNextUp should be restored to true")
        XCTAssertEqual(task.assignedFocusBlockID, "focus-block-42", "Block ID should be restored")
    }

    /// Verhalten: undo() loescht die durch Completion erzeugte Recurring-Instanz
    /// Bricht wenn: modelContext.delete(instance) in undo() fehlt
    func test_undo_deletesRecurringInstance() throws {
        // Arrange: Completed recurring Task + neue Instanz
        let completedTask = LocalTask(title: "Woechentlicher Report")
        completedTask.isCompleted = true
        completedTask.completedAt = Date()
        completedTask.recurrencePattern = "weekly"
        completedTask.recurrenceGroupID = "group-1"
        modelContext.insert(completedTask)

        let newInstance = LocalTask(title: "Woechentlicher Report")
        newInstance.recurrencePattern = "weekly"
        newInstance.recurrenceGroupID = "group-1"
        newInstance.dueDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
        modelContext.insert(newInstance)
        try modelContext.save()

        // Capture mit Instance-ID
        TaskCompletionUndoService.capture(
            taskID: completedTask.id,
            wasNextUp: false,
            assignedFocusBlockID: nil
        )
        TaskCompletionUndoService.recordCreatedInstance(id: newInstance.id)

        // Act
        _ = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert: Neue Instanz geloescht
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == "group-1" && !$0.isCompleted }
        )
        let remaining = try modelContext.fetch(descriptor)
        XCTAssertEqual(remaining.count, 1, "Only the restored original should remain (uncompleted)")
        XCTAssertEqual(remaining.first?.id, completedTask.id, "Remaining task should be the original")
    }

    /// Verhalten: undo() ohne Recurring-Instanz funktioniert normal (kein Crash)
    /// Bricht wenn: Guard fuer nil instanceID fehlt
    func test_undo_withoutRecurringInstance_worksNormally() throws {
        // Arrange
        let task = LocalTask(title: "Einfacher Task")
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        TaskCompletionUndoService.capture(
            taskID: task.id,
            wasNextUp: false,
            assignedFocusBlockID: nil
        )
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        // Act
        let title = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert
        XCTAssertEqual(title, "Einfacher Task")
        XCTAssertFalse(task.isCompleted)
    }

    // MARK: - Snapshot Lifecycle

    /// Verhalten: Nach undo() ist canUndo == false
    /// Bricht wenn: clear() am Ende von undo() fehlt
    func test_undo_clearsSnapshot() throws {
        // Arrange
        let task = LocalTask(title: "Task")
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        TaskCompletionUndoService.capture(taskID: task.id, wasNextUp: false, assignedFocusBlockID: nil)
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        // Act
        _ = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert
        XCTAssertFalse(TaskCompletionUndoService.canUndo, "canUndo should be false after undo")
    }

    /// Verhalten: undo() ohne vorherigen capture gibt nil zurueck
    /// Bricht wenn: Guard lastSnapshot == nil fehlt
    func test_undo_withNoSnapshot_returnsNil() throws {
        // Act
        let result = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert
        XCTAssertNil(result, "Should return nil when no snapshot exists")
    }

    /// Verhalten: undo() wenn der Task zwischenzeitlich geloescht wurde gibt nil zurueck
    /// Bricht wenn: Guard nach fetch().first fehlt
    func test_undo_taskDeleted_returnsNil() throws {
        // Arrange: Task anlegen, capturen, dann loeschen
        let task = LocalTask(title: "Geloeschter Task")
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        TaskCompletionUndoService.capture(taskID: task.id, wasNextUp: false, assignedFocusBlockID: nil)
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        // Task loeschen
        modelContext.delete(task)
        try modelContext.save()

        // Act
        let result = try TaskCompletionUndoService.undo(in: modelContext)

        // Assert
        XCTAssertNil(result, "Should return nil when task was deleted")
        XCTAssertFalse(TaskCompletionUndoService.canUndo, "Snapshot should be cleared")
    }
}
