@preconcurrency import EventKit
import Foundation

@Observable
final class EventKitRepository: @unchecked Sendable {
    private let eventStore = EKEventStore()

    /// Check if running in UI test mode
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    var reminderAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    var calendarAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestReminderAccess() async throws -> Bool {
        switch reminderAuthStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            return try await eventStore.requestFullAccessToReminders()
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    func requestCalendarAccess() async throws -> Bool {
        switch calendarAuthStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            return try await eventStore.requestFullAccessToEvents()
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    func requestAccess() async throws -> Bool {
        if Self.isUITesting { return true }
        let reminders = try await requestReminderAccess()
        let calendar = try await requestCalendarAccess()
        return reminders && calendar
    }

    func fetchIncompleteReminders() async throws -> [ReminderData] {
        // Return mock data for UI tests
        if Self.isUITesting {
            return Self.mockReminders
        }

        guard reminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    let data = reminders.map { ReminderData(from: $0) }
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: EventKitError.fetchFailed)
                }
            }
        }
    }

    /// Mock reminders for UI testing
    static let mockReminders: [ReminderData] = [
        ReminderData(id: "mock-1", title: "Design Review #30min"),
        ReminderData(id: "mock-2", title: "Team Standup #15min"),
        ReminderData(id: "mock-3", title: "Code Review"),
        ReminderData(id: "mock-4", title: "Documentation #60min")
    ]

    func fetchCalendarEvents(for date: Date) throws -> [CalendarEvent] {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw EventKitError.fetchFailed
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        return events.map { CalendarEvent(from: $0) }
    }

    func createCalendarEvent(title: String, startDate: Date, endDate: Date, reminderID: String? = nil) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Store reminderID in notes for later unscheduling
        if let reminderID {
            event.notes = "reminderID:\(reminderID)"
        }

        try eventStore.save(event, span: .thisEvent)
    }

    func deleteCalendarEvent(eventID: String) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let event = eventStore.event(withIdentifier: eventID) else {
            return // Silent fail if event not found
        }
        try eventStore.remove(event, span: .thisEvent)
    }

    func markReminderComplete(reminderID: String) throws {
        guard reminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return // Silent fail if reminder not found
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    func markReminderIncomplete(reminderID: String) throws {
        guard reminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return // Silent fail if reminder not found
        }
        reminder.isCompleted = false
        reminder.completionDate = nil
        try eventStore.save(reminder, commit: true)
    }
}

enum EventKitError: Error, LocalizedError {
    case notAuthorized
    case fetchFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Kein Zugriff auf Erinnerungen. Bitte in Einstellungen erlauben."
        case .fetchFailed:
            return "Erinnerungen konnten nicht geladen werden."
        case .saveFailed:
            return "Kalendereintrag konnte nicht gespeichert werden."
        }
    }
}
