import XCTest
import SwiftData
@testable import FocusBlox

/// Bug #225: Shake-Undo soll Rückfrage zeigen, nicht sofort ausführen.
/// Diese Tests prüfen den Confirmation-Flow über ShakeUndoHandler.
@MainActor
final class ShakeUndoConfirmationTests: XCTestCase {

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

    // MARK: - Test 1: Shake soll Confirmation triggern, nicht sofort Undo

    /// Verhalten: requestShakeUndo() setzt showUndoConfirmation=true, führt KEINEN Undo aus
    /// Bricht wenn: BacklogView den Undo noch direkt im .onShake-Handler ausführt
    func test_requestShakeUndo_showsConfirmation_doesNotUndo() throws {
        // Arrange: Task abschließen und Snapshot capturen
        let task = LocalTask(title: "Shake Test Task")
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

        // Act: requestShakeUndo aufrufen (das was .onShake jetzt machen soll)
        let handler = ShakeUndoHandler()
        handler.requestShakeUndo()

        // Assert: Confirmation-Flag gesetzt, aber Task noch completed
        XCTAssertTrue(handler.showUndoConfirmation,
            "showUndoConfirmation should be true after shake")
        XCTAssertTrue(task.isCompleted,
            "Task should still be completed — undo not yet executed")
        XCTAssertTrue(TaskCompletionUndoService.canUndo,
            "Undo snapshot should still be available")
    }

    // MARK: - Test 2: Confirmation-Bestätigung führt Undo aus

    /// Verhalten: confirmShakeUndo() führt den tatsächlichen Undo aus
    /// Bricht wenn: confirmShakeUndo() nicht implementiert oder Undo-Logik fehlt
    func test_confirmShakeUndo_executesUndo() throws {
        // Arrange
        let task = LocalTask(title: "Confirm Test Task")
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        try modelContext.save()

        TaskCompletionUndoService.capture(
            taskID: task.id,
            wasNextUp: true,
            assignedFocusBlockID: "block-1"
        )
        TaskCompletionUndoService.recordCreatedInstance(id: nil)

        let handler = ShakeUndoHandler()
        handler.requestShakeUndo()

        // Act: User bestätigt
        handler.confirmShakeUndo(in: modelContext)

        // Assert: Task wiederhergestellt
        XCTAssertFalse(task.isCompleted,
            "Task should be uncompleted after confirmation")
        XCTAssertNil(task.completedAt,
            "completedAt should be nil after undo")
        XCTAssertTrue(task.isNextUp,
            "isNextUp should be restored")
        XCTAssertFalse(handler.showUndoConfirmation,
            "Confirmation dialog should be dismissed")
    }

    // MARK: - Test 3: Abbrechen führt keinen Undo aus

    /// Verhalten: cancelShakeUndo() schließt Dialog, Task bleibt completed
    /// Bricht wenn: Cancel den Undo trotzdem ausführt
    func test_cancelShakeUndo_keepsTaskCompleted() throws {
        // Arrange
        let task = LocalTask(title: "Cancel Test Task")
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

        let handler = ShakeUndoHandler()
        handler.requestShakeUndo()

        // Act: User bricht ab
        handler.cancelShakeUndo()

        // Assert: Task unverändert
        XCTAssertTrue(task.isCompleted,
            "Task should still be completed after cancel")
        XCTAssertFalse(handler.showUndoConfirmation,
            "Confirmation dialog should be dismissed")
        XCTAssertTrue(TaskCompletionUndoService.canUndo,
            "Undo snapshot should still be available for future use")
    }
}
