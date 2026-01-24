import EventKit
import Foundation

/// Protocol for EventKit operations.
/// Enables dependency injection and mocking in tests.
@preconcurrency protocol EventKitRepositoryProtocol: Sendable {
    // MARK: - Authorization

    var reminderAuthStatus: EKAuthorizationStatus { get }
    var calendarAuthStatus: EKAuthorizationStatus { get }

    func requestReminderAccess() async throws -> Bool
    func requestCalendarAccess() async throws -> Bool
    func requestAccess() async throws -> Bool

    // MARK: - Reminders

    func fetchIncompleteReminders() async throws -> [ReminderData]
    func createReminder(title: String, priority: Int, dueDate: Date?, notes: String?) throws -> String
    func deleteReminder(id: String) throws
    func markReminderComplete(reminderID: String) throws
    func markReminderIncomplete(reminderID: String) throws
    func updateReminder(id: String, title: String?, priority: Int?, dueDate: Date?, notes: String?, isCompleted: Bool?) throws

    // MARK: - Calendar Events

    func fetchCalendarEvents(for date: Date) throws -> [CalendarEvent]
    func createCalendarEvent(title: String, startDate: Date, endDate: Date, reminderID: String?) throws
    func deleteCalendarEvent(eventID: String) throws
    func moveCalendarEvent(eventID: String, to newStartDate: Date, duration: Int) throws

    // MARK: - Focus Blocks

    func fetchFocusBlocks(for date: Date) throws -> [FocusBlock]
    func createFocusBlock(startDate: Date, endDate: Date) throws -> String
    func updateFocusBlock(eventID: String, taskIDs: [String], completedTaskIDs: [String]) throws
    func deleteFocusBlock(eventID: String) throws
    func updateFocusBlockTime(eventID: String, startDate: Date, endDate: Date) throws

    // MARK: - Calendars

    func getWritableCalendars() -> [EKCalendar]
    func getAllCalendars() -> [EKCalendar]

    // MARK: - Reminder Lists

    func getAllReminderLists() -> [ReminderListInfo]
}
