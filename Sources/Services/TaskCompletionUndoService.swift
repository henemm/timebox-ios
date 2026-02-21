import Foundation
import SwiftData

/// Enables undo of the last task completion.
/// Stores a single in-memory snapshot of the task state before completion.
/// iOS: triggered by shake gesture. macOS: triggered by Cmd+Z.
@MainActor
enum TaskCompletionUndoService {

    struct Snapshot {
        let taskID: String
        let wasNextUp: Bool
        let assignedFocusBlockID: String?
        let createdRecurringInstanceID: String?
    }

    private(set) static var lastSnapshot: Snapshot?

    /// Whether an undo operation is available.
    static var canUndo: Bool { lastSnapshot != nil }

    /// Capture the task state BEFORE completion.
    /// Call this in SyncEngine.completeTask() before setting isCompleted = true.
    static func capture(
        taskID: String,
        wasNextUp: Bool,
        assignedFocusBlockID: String?
    ) {
        lastSnapshot = Snapshot(
            taskID: taskID,
            wasNextUp: wasNextUp,
            assignedFocusBlockID: assignedFocusBlockID,
            createdRecurringInstanceID: nil
        )
    }

    /// Record the ID of a newly created recurring instance.
    /// Call this after RecurrenceService.createNextInstance() returns.
    static func recordCreatedInstance(id: String?) {
        guard let existing = lastSnapshot else { return }
        lastSnapshot = Snapshot(
            taskID: existing.taskID,
            wasNextUp: existing.wasNextUp,
            assignedFocusBlockID: existing.assignedFocusBlockID,
            createdRecurringInstanceID: id
        )
    }

    /// Undo the last completion. Restores the task to its pre-completion state
    /// and deletes any recurring instance that was created.
    /// Returns the task title on success, nil if nothing to undo.
    static func undo(in modelContext: ModelContext) throws -> String? {
        guard let snapshot = lastSnapshot else { return nil }

        // Use uuid (stored) instead of id (computed) for SwiftData predicate
        guard let taskUUID = UUID(uuidString: snapshot.taskID) else {
            clear()
            return nil
        }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == taskUUID }
        )
        guard let task = try modelContext.fetch(descriptor).first else {
            clear()
            return nil
        }

        // Restore pre-completion state
        task.isCompleted = false
        task.completedAt = nil
        task.isNextUp = snapshot.wasNextUp
        task.assignedFocusBlockID = snapshot.assignedFocusBlockID

        // Delete recurring instance if one was created
        if let instanceID = snapshot.createdRecurringInstanceID,
           let instanceUUID = UUID(uuidString: instanceID) {
            let instanceDescriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { $0.uuid == instanceUUID }
            )
            if let instance = try modelContext.fetch(instanceDescriptor).first {
                modelContext.delete(instance)
            }
        }

        try modelContext.save()
        let title = task.title
        clear()
        return title
    }

    /// Clear the stored snapshot.
    static func clear() {
        lastSnapshot = nil
    }
}
