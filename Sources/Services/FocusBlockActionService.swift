import AppIntents
import Foundation
import SwiftData

/// Shared service for task complete/skip actions during a FocusBlock.
/// Used by both iOS (FocusLiveView) and macOS (MacFocusView).
enum FocusBlockActionService {

    /// Result of a task action (complete, skip, or follow-up)
    enum TaskActionResult: Sendable, Equatable {
        /// Task was marked as completed
        case completed
        /// Task was skipped (moved to end of queue)
        case skipped
        /// Last remaining task was skipped → auto-completed to end block
        case skippedLast
        /// Task was completed and a follow-up copy was created
        case followedUp(newTaskID: String)
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
        // DEP-4b: Check if task is blocked before any changes
        let blockCheckDescriptor = FetchDescriptor<LocalTask>()
        if let allTasks = try? modelContext.fetch(blockCheckDescriptor),
           let localTask = allTasks.first(where: { $0.id == taskID }),
           localTask.blockerTaskID != nil {
            return .completed  // Silently skip — blocked task stays incomplete
        }

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
            localTask.isNextUp = false

            // DEP-4b: Free dependents when completing a blocker
            let depDescriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { $0.blockerTaskID == taskID }
            )
            if let deps = try? modelContext.fetch(depDescriptor) {
                for dep in deps { dep.blockerTaskID = nil }
            }

            // Generate next instance for recurring tasks
            if localTask.recurrencePattern != "none" {
                RecurrenceService.createNextInstance(from: localTask, in: modelContext)
            }

            // Capture values BEFORE save — SwiftData objects are not thread-safe
            let capturedID = localTask.id
            let capturedTitle = localTask.title

            try? modelContext.save()

            // ITB-G1: Donate intent so Siri learns completion patterns
            #if !os(macOS)
            Task {
                let donationIntent = CompleteTaskIntent()
                donationIntent.task = TaskEntity(id: capturedID, title: capturedTitle)
                try? await IntentDonationManager.shared.donate(intent: donationIntent)
            }
            #endif
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

    /// Follow-up a task: complete the original and create an editable copy.
    @MainActor
    static func followUpTask(
        taskID: String,
        block: FocusBlock,
        taskStartTime: Date?,
        eventKitRepo: any EventKitRepositoryProtocol,
        modelContext: ModelContext
    ) throws -> TaskActionResult {
        // Step 1: Complete the original task (reuse full completion logic)
        _ = try completeTask(
            taskID: taskID,
            block: block,
            taskStartTime: taskStartTime,
            eventKitRepo: eventKitRepo,
            modelContext: modelContext
        )

        // Step 2: Fetch the original task to copy its metadata
        let descriptor = FetchDescriptor<LocalTask>()
        guard let allTasks = try? modelContext.fetch(descriptor),
              let original = allTasks.first(where: { $0.id == taskID }) else {
            return .completed
        }

        // Step 3: Create a copy with metadata preserved, status fields reset
        let copy = LocalTask(
            title: original.title,
            importance: original.importance,
            tags: original.tags,
            dueDate: original.dueDate,
            estimatedDuration: original.estimatedDuration,
            urgency: original.urgency,
            taskType: original.taskType,
            taskDescription: original.taskDescription
        )
        modelContext.insert(copy)
        try? modelContext.save()

        return .followedUp(newTaskID: copy.id)
    }
}
