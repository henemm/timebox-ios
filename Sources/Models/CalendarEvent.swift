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
    let hasAttendees: Bool
    let isReadOnly: Bool
    let calendarItemIdentifier: String

    private static let categoryMappingKey = "calendarEventCategories"

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Ohne Titel"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.calendarColor = event.calendar?.cgColor?.components?.description
        self.notes = event.notes
        self.hasAttendees = event.hasAttendees
        self.isReadOnly = event.hasAttendees || !(event.calendar?.allowsContentModifications ?? true)
        self.calendarItemIdentifier = event.calendarItemIdentifier
    }

    // For testing
    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarColor: String?, notes: String?, hasAttendees: Bool = false, calendarItemIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarColor = calendarColor
        self.notes = notes
        self.hasAttendees = hasAttendees
        self.isReadOnly = hasAttendees
        self.calendarItemIdentifier = calendarItemIdentifier ?? id
    }

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Returns the reminderID if stored in notes (format: "reminderID:xxx")
    var reminderID: String? {
        guard let notes, notes.hasPrefix("reminderID:") else { return nil }
        return String(notes.dropFirst("reminderID:".count))
    }

    // MARK: - Category Support

    /// Returns the category from local UserDefaults mapping (keyed by calendarItemIdentifier).
    /// Bug 63: Previously stored in notes (read-only for events with attendees) and iCloud KV Store
    /// (unstable eventIdentifier per occurrence). Now uses calendarItemIdentifier which is stable
    /// across all occurrences of a recurring event.
    var category: String? {
        let dict = UserDefaults.standard.dictionary(forKey: Self.categoryMappingKey) as? [String: String] ?? [:]
        return dict[calendarItemIdentifier]
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

    /// Get task times for this focus block (seconds spent per task)
    /// Format in notes: "times:id1=120|id2=90"
    var focusBlockTaskTimes: [String: Int] {
        guard let notes else { return [:] }
        let lines = notes.components(separatedBy: "\n")
        guard let line = lines.first(where: { $0.hasPrefix("times:") }) else {
            return [:]
        }
        let value = String(line.dropFirst("times:".count))
        guard !value.isEmpty else { return [:] }

        var result: [String: Int] = [:]
        let pairs = value.components(separatedBy: "|")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2, let seconds = Int(parts[1]) {
                result[parts[0]] = seconds
            }
        }
        return result
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
