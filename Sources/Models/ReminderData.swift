import Foundation
@preconcurrency import EventKit

struct ReminderData: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?
    let notes: String?

    init(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "Untitled"
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
        self.dueDate = reminder.dueDateComponents?.date
        self.notes = reminder.notes
    }

    // For testing
    init(id: String, title: String, isCompleted: Bool = false, priority: Int = 0, dueDate: Date? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes
    }
}
