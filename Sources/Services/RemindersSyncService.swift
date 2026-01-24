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

    /// Import all incomplete reminders from Apple Reminders.
    /// Creates new LocalTask for new reminders, updates existing ones.
    func importFromReminders() async throws -> [LocalTask] {
        let reminders = try await eventKitRepo.fetchIncompleteReminders()
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

        // Handle deleted reminders: set sourceSystem to "local"
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
                // Reminder was deleted in Apple - convert to local task
                task.sourceSystem = "local"
                // Keep externalID for potential reconnection
            }
        }
    }
}
