import Foundation
import SwiftData

/// Service for bidirectional sync with Apple Reminders.
/// Imports Reminders as LocalTask, preserves local-only fields.
@Observable
@MainActor
final class RemindersSyncService {
    private let eventKitRepo: EventKitRepositoryProtocol
    private let modelContext: ModelContext

    init(eventKitRepo: EventKitRepositoryProtocol, modelContext: ModelContext) {
        self.eventKitRepo = eventKitRepo
        self.modelContext = modelContext
    }

    /// Import incomplete reminders from visible Apple Reminders lists.
    /// Creates new LocalTask for new reminders, updates existing ones.
    /// Reminders from hidden lists are removed from backlog.
    func importFromReminders() async throws -> [LocalTask] {
        let allReminders = try await eventKitRepo.fetchIncompleteReminders()

        // Get visible reminder list IDs from UserDefaults
        let visibleListIDs: Set<String>
        if let savedListIDs = UserDefaults.standard.array(forKey: "visibleReminderListIDs") as? [String] {
            visibleListIDs = Set(savedListIDs)
        } else {
            // Default: all lists visible
            let allLists = eventKitRepo.getAllReminderLists()
            visibleListIDs = Set(allLists.map(\.id))
        }

        // Filter reminders by visible lists
        let reminders = allReminders.filter { reminder in
            guard let listID = reminder.calendarIdentifier else { return true }
            return visibleListIDs.contains(listID)
        }

        var importedTasks: [LocalTask] = []

        for reminder in reminders {
            if let existingTask = try findTask(byExternalID: reminder.id) {
                // Bug 59 Fix: Recover attributes from orphaned duplicate
                if let orphan = try findOrphanedTask(byTitle: reminder.title) {
                    transferAttributes(from: orphan, to: existingTask)
                    modelContext.delete(orphan)
                }
                updateTask(existingTask, from: reminder)
                importedTasks.append(existingTask)
            } else if let reminderTask = try findReminderTask(byTitle: reminder.title) {
                // Bug 60 Fix: ID changed but task found by title (sourceSystem="reminders").
                // Update externalID to new value, preserve all attributes.
                reminderTask.externalID = reminder.id
                updateTask(reminderTask, from: reminder)
                importedTasks.append(reminderTask)
            } else if let orphan = try findOrphanedTask(byTitle: reminder.title) {
                // Bug 59 Fix: Restore orphaned task (preserves all user attributes)
                orphan.sourceSystem = "reminders"
                orphan.externalID = reminder.id
                updateTask(orphan, from: reminder)
                importedTasks.append(orphan)
            } else {
                // Create new LocalTask
                let newTask = createTask(from: reminder)
                modelContext.insert(newTask)
                importedTasks.append(newTask)
            }
        }

        // Bug 60 Fix: Use ALL reminder IDs (not just visible-list filtered ones)
        // so tasks from hidden lists are NOT wrongly marked as deleted.
        try handleDeletedReminders(currentReminderIDs: Set(allReminders.map(\.id)))

        try modelContext.save()
        return importedTasks
    }

    /// Export a LocalTask to Apple Reminders.
    /// Only exports tasks with sourceSystem="reminders".
    func exportToReminders(task: LocalTask) async throws {
        guard task.sourceSystem == "reminders", let externalID = task.externalID else {
            return
        }

        try eventKitRepo.updateReminder(
            id: externalID,
            title: task.title,
            priority: mapToReminderPriority(task.importance),
            dueDate: task.dueDate,
            notes: task.taskDescription,
            isCompleted: task.isCompleted
        )
    }

    /// Full bidirectional sync.
    func syncAll() async throws {
        _ = try await importFromReminders()

        // Export all reminder-sourced tasks
        let reminderTasks = try fetchReminderSourcedTasks()
        for task in reminderTasks {
            try await exportToReminders(task: task)
        }
    }

    // MARK: - Private Helpers

    private func findTask(byExternalID externalID: String) throws -> LocalTask? {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.externalID == externalID && $0.sourceSystem == "reminders" }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchReminderSourcedTasks() throws -> [LocalTask] {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.sourceSystem == "reminders" }
        )
        return try modelContext.fetch(descriptor)
    }

    private func createTask(from reminder: ReminderData) -> LocalTask {
        LocalTask(
            title: reminder.title,
            importance: mapReminderPriority(reminder.priority),
            dueDate: reminder.dueDate,
            taskDescription: reminder.notes,
            externalID: reminder.id,
            sourceSystem: "reminders"
        )
    }

    private func updateTask(_ task: LocalTask, from reminder: ReminderData) {
        // Bug 57 Fix A: Only write when value actually changed.
        // Unconditional writes mark SwiftData object as dirty,
        // causing CloudKit to sync ALL fields (including nil extended attributes).
        if task.title != reminder.title { task.title = reminder.title }
        if task.isCompleted != reminder.isCompleted { task.isCompleted = reminder.isCompleted }
        if task.dueDate != reminder.dueDate { task.dueDate = reminder.dueDate }
        if task.taskDescription != reminder.notes { task.taskDescription = reminder.notes }

        // Importance: Only set if user hasn't set it locally
        let appleImportance = mapReminderPriority(reminder.priority)
        if task.importance == nil {
            task.importance = appleImportance
        }
    }

    /// Convert EKReminder priority to FocusBlox importance
    /// EKReminder: 0=none, 1-4=high, 5=medium, 6-9=low
    /// FocusBlox: nil=tbd, 1=low, 2=medium, 3=high
    private func mapReminderPriority(_ ekPriority: Int) -> Int? {
        switch ekPriority {
        case 1...4: return 3  // High
        case 5: return 2      // Medium
        case 6...9: return 1  // Low
        default: return nil   // None (0) → TBD (keine Fake-Defaults)
        }
    }

    /// Convert FocusBlox importance back to EKReminder priority for export
    private func mapToReminderPriority(_ importance: Int?) -> Int {
        guard let importance else { return 0 }  // nil → None
        switch importance {
        case 3: return 1  // High
        case 2: return 5  // Medium
        case 1: return 9  // Low
        default: return 0 // None
        }
    }

    /// Bug 60 Fix: Find existing reminders-sourced task by title.
    /// Handles the case where calendarItemExternalIdentifier changed (Root Cause 4).
    /// Also finds completed tasks so they can be reactivated (Root Cause 2).
    private func findReminderTask(byTitle title: String) throws -> LocalTask? {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.sourceSystem == "reminders" && $0.title == title }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Bug 59 Fix: Find orphaned task by title match.
    /// Orphans are tasks soft-deleted by Bug 57 (sourceSystem="local", externalID=nil).
    private func findOrphanedTask(byTitle title: String) throws -> LocalTask? {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.sourceSystem == "local" && $0.externalID == nil && $0.title == title && $0.isCompleted == false }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Bug 59 Fix: Transfer user-entered attributes from orphan to existing task.
    /// Only transfers values that the target task doesn't already have.
    private func transferAttributes(from source: LocalTask, to target: LocalTask) {
        if target.importance == nil, let imp = source.importance { target.importance = imp }
        if target.urgency == nil { target.urgency = source.urgency }
        if (target.taskType.isEmpty || target.taskType == "inbox"), !source.taskType.isEmpty, source.taskType != "inbox" { target.taskType = source.taskType }
        if target.estimatedDuration == nil { target.estimatedDuration = source.estimatedDuration }
        if target.tags.isEmpty, !source.tags.isEmpty { target.tags = source.tags }
        if target.aiScore == nil { target.aiScore = source.aiScore }
        if target.aiEnergyLevel == nil { target.aiEnergyLevel = source.aiEnergyLevel }
        if target.taskDescription == nil { target.taskDescription = source.taskDescription }
        if !target.isNextUp, source.isNextUp {
            target.isNextUp = true
            target.nextUpSortOrder = source.nextUpSortOrder
        }
    }

    private func handleDeletedReminders(currentReminderIDs: Set<String>) throws {
        let reminderTasks = try fetchReminderSourcedTasks()

        for task in reminderTasks {
            guard let externalID = task.externalID else { continue }

            if !currentReminderIDs.contains(externalID) {
                // Bug 60 Fix: Keep externalID and sourceSystem for future recovery.
                // NEVER nil externalID — it makes recovery permanently impossible.
                // NEVER change sourceSystem — it breaks title-based matching.
                // Only mark as completed (reminder was completed/deleted in Apple Reminders).
                task.isCompleted = true
                task.completedAt = Date()
            }
        }
    }
}
