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
                // Update existing task with Apple data (preserve local fields)
                updateTask(existingTask, from: reminder)
                importedTasks.append(existingTask)
            } else {
                // Create new LocalTask
                let newTask = createTask(from: reminder)
                modelContext.insert(newTask)
                importedTasks.append(newTask)
            }
        }

        // Handle deleted/hidden reminders: set sourceSystem to "local"
        try handleDeletedReminders(currentReminderIDs: Set(reminders.map(\.id)))

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
        // Update Apple-synced fields
        task.title = reminder.title
        task.isCompleted = reminder.isCompleted
        task.dueDate = reminder.dueDate
        task.taskDescription = reminder.notes

        // Importance: Preserve local value if set, otherwise use Apple's priority
        // This allows users to override Apple's priority locally
        let appleImportance = mapReminderPriority(reminder.priority)
        if task.importance == nil {
            // User hasn't set importance locally → use Apple's value
            task.importance = appleImportance
        }
        // If task.importance is already set, keep it (user's local override)

        // Local-only fields (tags, urgency, taskType, isNextUp) are preserved
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

    private func handleDeletedReminders(currentReminderIDs: Set<String>) throws {
        let reminderTasks = try fetchReminderSourcedTasks()

        for task in reminderTasks {
            guard let externalID = task.externalID else { continue }

            if !currentReminderIDs.contains(externalID) {
                // Reminder was deleted or hidden - remove from backlog
                // Will be re-imported if list is re-enabled
                modelContext.delete(task)
            }
        }
    }
}
