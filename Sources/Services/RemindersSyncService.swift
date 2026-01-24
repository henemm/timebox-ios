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
            priority: task.priority,
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
            priority: reminder.priority,
            dueDate: reminder.dueDate,
            taskDescription: reminder.notes,
            externalID: reminder.id,
            sourceSystem: "reminders"
        )
    }

    private func updateTask(_ task: LocalTask, from reminder: ReminderData) {
        // Update Apple-synced fields
        task.title = reminder.title
        task.priority = reminder.priority
        task.isCompleted = reminder.isCompleted
        task.dueDate = reminder.dueDate
        task.taskDescription = reminder.notes
        // Local-only fields (tags, urgency, taskType, isNextUp) are preserved
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
