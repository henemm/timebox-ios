@preconcurrency import EventKit
import Foundation

@Observable
final class EventKitRepository: @unchecked Sendable {
    private let eventStore = EKEventStore()

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
        let reminders = try await requestReminderAccess()
        let calendar = try await requestCalendarAccess()
        return reminders && calendar
    }

    func fetchIncompleteReminders() async throws -> [ReminderData] {
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

    func createCalendarEvent(title: String, startDate: Date, endDate: Date) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
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
