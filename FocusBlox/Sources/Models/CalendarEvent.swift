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

    // MARK: - Focus Block Support

    /// Check if this event is a Focus Block
    var isFocusBlock: Bool {
        guard let notes else { return false }
        return notes.contains("focusBlock:true")
    }

    /// Get task IDs assigned to this focus block
    var focusBlockTaskIDs: [String] {
        guard let notes else { return [] }
        return parseNotesLine(prefix: "tasks:", from: notes)
    }

    /// Get completed task IDs for this focus block
    var focusBlockCompletedIDs: [String] {
        guard let notes else { return [] }
        return parseNotesLine(prefix: "completed:", from: notes)
    }

    /// Parse a line from notes with format "prefix:id1|id2|id3"
    private func parseNotesLine(prefix: String, from notes: String) -> [String] {
        let lines = notes.components(separatedBy: "\n")
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return []
        }
        let value = String(line.dropFirst(prefix.count))
        guard !value.isEmpty else { return [] }
        return value.components(separatedBy: "|")
    }
}
