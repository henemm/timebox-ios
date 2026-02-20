import Foundation
import os
import SwiftData

/// Import-only service for Apple Reminders.
/// One-way: Reminders → FocusBlox. No write-back, no auto-sync.
/// After successful import, optionally marks reminders as completed in Apple Reminders.
@MainActor
final class RemindersImportService {
    private static let logger = Logger(subsystem: "com.henning.focusblox", category: "RemindersImport")
    private let eventKitRepo: EventKitRepositoryProtocol
    private let modelContext: ModelContext

    struct ImportResult {
        let imported: [LocalTask]
        let skippedDuplicates: Int
        let enrichedRecurrence: Int
        let markedComplete: Int
        let markCompleteFailures: Int
    }

    init(eventKitRepo: EventKitRepositoryProtocol, modelContext: ModelContext) {
        self.eventKitRepo = eventKitRepo
        self.modelContext = modelContext
    }

    /// Import reminders from visible lists as local tasks.
    /// Skips reminders whose title already exists in the backlog.
    /// Optionally marks imported reminders as completed in Apple Reminders.
    func importAll(markCompleteInReminders: Bool = false) async throws -> ImportResult {
        let allReminders = try await eventKitRepo.fetchIncompleteReminders()

        // Filter by visible lists
        let visibleListIDs: Set<String>
        if let savedListIDs = UserDefaults.standard.array(forKey: "visibleReminderListIDs") as? [String] {
            visibleListIDs = Set(savedListIDs)
        } else {
            let allLists = eventKitRepo.getAllReminderLists()
            visibleListIDs = Set(allLists.map(\.id))
        }

        let reminders = allReminders.filter { reminder in
            guard let listID = reminder.calendarIdentifier else { return true }
            return visibleListIDs.contains(listID)
        }

        // Fetch only INCOMPLETE tasks for duplicate detection + recurrence enrichment
        // IMPORTANT: Must exclude completed tasks! Completed recurring tasks may have
        // recurrencePattern set correctly (from RecurrenceService), while their active
        // counterparts still have "none". Fetching all tasks would match the completed
        // duplicate first, skip enrichment, and leave the active task un-enriched.
        let existingTasks = try modelContext.fetch(FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        ))
        let existingByTitle = Dictionary(grouping: existingTasks, by: \.title)

        var imported: [LocalTask] = []
        var skippedDuplicates = 0
        var enrichedRecurrence = 0

        Self.logger.info("Import: \(reminders.count) reminders to process")

        for reminder in reminders {
            Self.logger.info("  Reminder '\(reminder.title)' recurrencePattern='\(reminder.recurrencePattern)'")

            if let existing = existingByTitle[reminder.title]?.first {
                skippedDuplicates += 1
                // Enrich recurrencePattern if task has "none" but reminder is recurring
                if existing.recurrencePattern == "none" && reminder.recurrencePattern != "none" {
                    existing.recurrencePattern = reminder.recurrencePattern
                    enrichedRecurrence += 1
                    Self.logger.info("    ENRICHED pattern: '\(reminder.title)' none → '\(reminder.recurrencePattern)'")
                }
                // Enrich dueDate if task has none but reminder has one
                if existing.dueDate == nil, let reminderDueDate = reminder.dueDate {
                    existing.dueDate = reminderDueDate
                    Self.logger.info("    ENRICHED dueDate: '\(reminder.title)' nil → \(reminderDueDate)")
                }
                Self.logger.info("    State: existing pattern='\(existing.recurrencePattern)' dueDate=\(existing.dueDate?.description ?? "nil") isVisible=\(existing.isVisibleInBacklog)")
                continue
            }

            let task = LocalTask(
                title: reminder.title,
                importance: mapReminderPriority(reminder.priority),
                dueDate: reminder.dueDate,
                recurrencePattern: reminder.recurrencePattern,
                taskDescription: reminder.notes,
                externalID: nil,
                sourceSystem: "local"
            )
            modelContext.insert(task)
            imported.append(task)
        }

        try modelContext.save()

        Self.logger.info("Import done: \(imported.count) imported, \(skippedDuplicates) skipped, \(enrichedRecurrence) enriched")

        // After successful persist: optionally mark all reminders as completed.
        // Both imported AND skipped reminders get marked — skipped ones are already in FocusBlox.
        var markedComplete = 0
        var markCompleteFailures = 0

        if markCompleteInReminders {
            for reminder in reminders {
                do {
                    try eventKitRepo.markReminderComplete(reminderID: reminder.id)
                    markedComplete += 1
                } catch {
                    markCompleteFailures += 1
                    print("[RemindersImport] Failed to mark reminder '\(reminder.title)' as complete: \(error)")
                }
            }
        }

        return ImportResult(
            imported: imported,
            skippedDuplicates: skippedDuplicates,
            enrichedRecurrence: enrichedRecurrence,
            markedComplete: markedComplete,
            markCompleteFailures: markCompleteFailures
        )
    }

    /// Convert EKReminder priority to FocusBlox importance.
    /// EKReminder: 0=none, 1-4=high, 5=medium, 6-9=low
    /// FocusBlox: nil=tbd, 1=low, 2=medium, 3=high
    private func mapReminderPriority(_ ekPriority: Int) -> Int? {
        switch ekPriority {
        case 1...4: return 3  // High
        case 5: return 2      // Medium
        case 6...9: return 1  // Low
        default: return nil   // None (0) → TBD
        }
    }

    // MARK: - Migration

    /// Migrate existing "reminders"-sourced tasks to "local".
    /// Called once at app startup. Idempotent.
    @discardableResult
    static func migrateRemindersToLocal(in context: ModelContext) -> Int {
        do {
            let descriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate { $0.sourceSystem == "reminders" }
            )
            let reminderTasks = try context.fetch(descriptor)
            guard !reminderTasks.isEmpty else { return 0 }

            for task in reminderTasks {
                task.sourceSystem = "local"
                task.externalID = nil
            }

            try context.save()
            print("[RemindersImport] Migrated \(reminderTasks.count) tasks from 'reminders' to 'local'")
            return reminderTasks.count
        } catch {
            print("[RemindersImport] Migration failed: \(error)")
            return -1
        }
    }
}
