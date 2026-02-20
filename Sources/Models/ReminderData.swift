import Foundation
@preconcurrency import EventKit

struct ReminderData: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?
    let notes: String?
    let calendarIdentifier: String?  // Which reminder list this belongs to
    let recurrencePattern: String    // "none", "daily", "weekly", "biweekly", "monthly"

    init(from reminder: EKReminder) {
        // Use calendarItemIdentifier — this is the ID that EventKit's
        // calendarItem(withIdentifier:) accepts for markReminderComplete().
        // calendarItemExternalIdentifier was used for bidirectional sync (removed).
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "Untitled"
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
        self.dueDate = reminder.dueDateComponents?.date
        self.notes = reminder.notes
        self.calendarIdentifier = reminder.calendar?.calendarIdentifier
        self.recurrencePattern = Self.mapRecurrenceRules(reminder.recurrenceRules)
    }

    // For testing
    init(id: String, title: String, isCompleted: Bool = false, priority: Int = 0, dueDate: Date? = nil, notes: String? = nil, calendarIdentifier: String? = nil, recurrencePattern: String = "none") {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes
        self.calendarIdentifier = calendarIdentifier
        self.recurrencePattern = recurrencePattern
    }

    /// Map EKRecurrenceRule to FocusBlox recurrencePattern string.
    /// Internal for testability — called from init(from: EKReminder).
    static func mapRecurrenceRules(_ rules: [EKRecurrenceRule]?) -> String {
        guard let rule = rules?.first else { return "none" }
        switch rule.frequency {
        case .daily:
            return "daily"
        case .weekly:
            return rule.interval == 2 ? "biweekly" : "weekly"
        case .monthly:
            return "monthly"
        default:
            return "none"
        }
    }
}
