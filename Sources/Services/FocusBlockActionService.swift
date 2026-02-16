import Foundation
import SwiftData

/// Shared service for task complete/skip actions during a FocusBlock.
/// Used by both iOS (FocusLiveView) and macOS (MacFocusView).
enum FocusBlockActionService {

    /// Result of a task action (complete or skip)
    enum TaskActionResult: Sendable {
        /// Task was marked as completed
        case completed
        /// Task was skipped (moved to end of queue)
        case skipped
        /// Last remaining task was skipped → auto-completed to end block
        case skippedLast
    }

    /// Mark a task as completed: update completedTaskIDs, record time, persist to SwiftData.
    @MainActor
    static func completeTask(
        taskID: String,
        block: FocusBlock,
        taskStartTime: Date?,
        eventKitRepo: any EventKitRepositoryProtocol,
        modelContext: ModelContext
    ) throws -> TaskActionResult {
        var updatedCompletedIDs = block.completedTaskIDs
        if !updatedCompletedIDs.contains(taskID) {
            updatedCompletedIDs.append(taskID)
        }

        var updatedTaskTimes = block.taskTimes
        if let startTime = taskStartTime {
            let secondsSpent = Int(Date().timeIntervalSince(startTime))
            updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
        }

        try eventKitRepo.updateFocusBlock(
            eventID: block.id,
            taskIDs: block.taskIDs,
            completedTaskIDs: updatedCompletedIDs,
            taskTimes: updatedTaskTimes
        )

        // Persist LocalTask.isCompleted + completedAt in SwiftData (for Review Tab)
        let fetchDescriptor = FetchDescriptor<LocalTask>()
        if let localTasks = try? modelContext.fetch(fetchDescriptor),
           let localTask = localTasks.first(where: { $0.id == taskID }) {
            localTask.isCompleted = true
            localTask.completedAt = Date()
            localTask.assignedFocusBlockID = nil  // Bug 52: Clear block assignment on complete

            // Generate next instance for recurring tasks
            if localTask.recurrencePattern != "none" {
                RecurrenceService.createNextInstance(from: localTask, in: modelContext)
            }

            try? modelContext.save()
        }

        return .completed
    }

    /// Skip a task: move to end of queue, or auto-complete if last remaining (Bug 15 Fix).
    @MainActor
    static func skipTask(
        taskID: String,
        block: FocusBlock,
        taskStartTime: Date?,
        eventKitRepo: any EventKitRepositoryProtocol
    ) throws -> TaskActionResult {
        let remainingTaskIDs = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
        let isOnlyRemainingTask = remainingTaskIDs.count == 1 && remainingTaskIDs.first == taskID

        // Preserve partial time spent on skipped task
        var updatedTaskTimes = block.taskTimes
        if let startTime = taskStartTime {
            let secondsSpent = Int(Date().timeIntervalSince(startTime))
            updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
        }

        if isOnlyRemainingTask {
            // Bug 15 Fix: Only 1 task remaining → mark as completed to end block
            var updatedCompletedIDs = block.completedTaskIDs
            updatedCompletedIDs.append(taskID)
            try eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: block.taskIDs,
                completedTaskIDs: updatedCompletedIDs,
                taskTimes: updatedTaskTimes
            )
            return .skippedLast
        } else {
            // Move task to end of queue
            var updatedTaskIDs = block.taskIDs
            if let index = updatedTaskIDs.firstIndex(of: taskID) {
                updatedTaskIDs.remove(at: index)
                updatedTaskIDs.append(taskID)
            }
            try eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: updatedTaskIDs,
                completedTaskIDs: block.completedTaskIDs,
                taskTimes: updatedTaskTimes
            )
            return .skipped
        }
    }
}
