import Foundation
@preconcurrency import EventKit

struct CalendarEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: String?
    let notes: String?

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Ohne Titel"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.calendarColor = event.calendar?.cgColor?.components?.description
        self.notes = event.notes
    }

    // For testing
    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarColor: String?, notes: String?) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarColor = calendarColor
        self.notes = notes
    }

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Returns the reminderID if stored in notes (format: "reminderID:xxx")
    var reminderID: String? {
        guard let notes, notes.hasPrefix("reminderID:") else { return nil }
        return String(notes.dropFirst("reminderID:".count))
    }
}
