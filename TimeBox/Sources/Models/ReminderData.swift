import Foundation
@preconcurrency import EventKit

struct ReminderData: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int

    init(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "Untitled"
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
    }
}
