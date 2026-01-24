@preconcurrency import EventKit
import Foundation

@Observable
final class EventKitRepository: EventKitRepositoryProtocol, @unchecked Sendable {
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
            calendars: visibleCalendars()
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
        event.calendar = calendarForEvents()

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

    func updateReminder(id: String, title: String?, priority: Int?, dueDate: Date?, notes: String?, isCompleted: Bool?) throws {
        guard reminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return
        }

        if let title = title {
            reminder.title = title
        }
        if let priority = priority {
            reminder.priority = priority
        }
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        if let notes = notes {
            reminder.notes = notes
        }
        if let isCompleted = isCompleted {
            reminder.isCompleted = isCompleted
            reminder.completionDate = isCompleted ? Date() : nil
        }

        try eventStore.save(reminder, commit: true)
    }

    func moveCalendarEvent(eventID: String, to newStartDate: Date, duration: Int) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let event = eventStore.event(withIdentifier: eventID) else {
            return // Silent fail if event not found
        }

        let newEndDate = Calendar.current.date(
            byAdding: .minute,
            value: duration,
            to: newStartDate
        ) ?? newStartDate

        event.startDate = newStartDate
        event.endDate = newEndDate
        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Focus Block Methods

    func createFocusBlock(startDate: Date, endDate: Date) throws -> String {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }

        let event = EKEvent(eventStore: eventStore)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        event.title = "Focus Block \(formatter.string(from: startDate))"
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendarForEvents()
        event.notes = FocusBlock.serializeToNotes(taskIDs: [], completedTaskIDs: [])

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier ?? ""
    }

    func updateFocusBlock(eventID: String, taskIDs: [String], completedTaskIDs: [String]) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let event = eventStore.event(withIdentifier: eventID) else {
            return
        }

        event.notes = FocusBlock.serializeToNotes(taskIDs: taskIDs, completedTaskIDs: completedTaskIDs)
        try eventStore.save(event, span: .thisEvent)
    }

    func fetchFocusBlocks(for date: Date) throws -> [FocusBlock] {
        let events = try fetchCalendarEvents(for: date)
        return events.compactMap { FocusBlock(from: $0) }
    }

    func deleteFocusBlock(eventID: String) throws {
        try deleteCalendarEvent(eventID: eventID)
    }

    func updateFocusBlockTime(eventID: String, startDate: Date, endDate: Date) throws {
        guard calendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        guard let event = eventStore.event(withIdentifier: eventID) else {
            return
        }
        event.startDate = startDate
        event.endDate = endDate
        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Calendar Selection Methods

    /// Returns all available calendars for events
    func getAllCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    /// Returns only calendars that allow content modifications (writable)
    func getWritableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
    }

    /// Returns the selected calendar for creating events, with fallback to default
    func calendarForEvents() -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: "selectedCalendarID"),
           !id.isEmpty,
           let calendar = eventStore.calendar(withIdentifier: id),
           calendar.allowsContentModifications {
            return calendar
        }
        return eventStore.defaultCalendarForNewEvents
    }

    /// Returns the saved visible calendar IDs, or nil if not configured
    func visibleCalendarIDs() -> [String]? {
        UserDefaults.standard.array(forKey: "visibleCalendarIDs") as? [String]
    }

    /// Returns the visible calendars as EKCalendar array, or nil if not configured (show all)
    func visibleCalendars() -> [EKCalendar]? {
        guard let ids = visibleCalendarIDs(), !ids.isEmpty else { return nil }
        return ids.compactMap { eventStore.calendar(withIdentifier: $0) }
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
