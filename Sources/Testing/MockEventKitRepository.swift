import EventKit
import Foundation

/// Mock implementation of EventKitRepositoryProtocol for testing
/// Available in both main and test targets for UI testing support
final class MockEventKitRepository: EventKitRepositoryProtocol, @unchecked Sendable {
    // MARK: - Configurable Mock State

    var mockReminderAuthStatus: EKAuthorizationStatus = .fullAccess
    var mockCalendarAuthStatus: EKAuthorizationStatus = .fullAccess

    var mockReminders: [ReminderData] = []
    var mockEvents: [CalendarEvent] = []
    var mockFocusBlocks: [FocusBlock] = []
    var mockCalendars: [EKCalendar] = []

    // MARK: - Method Call Tracking

    var requestAccessCalled = false
    var deleteCalendarEventCalled = false
    var lastDeletedEventID: String?

    var markReminderCompleteCalled = false
    var lastCompletedReminderID: String?
    var completedReminderIDs: [String] = []
    var markCompleteError: Error?

    var markReminderIncompleteCalled = false
    var lastIncompletedReminderID: String?

    var createCalendarEventCalled = false
    var lastCreatedEventParams: (title: String, start: Date, end: Date, reminderID: String?)?

    // MARK: - Protocol Implementation - Authorization

    nonisolated var reminderAuthStatus: EKAuthorizationStatus {
        mockReminderAuthStatus
    }

    nonisolated var calendarAuthStatus: EKAuthorizationStatus {
        mockCalendarAuthStatus
    }

    func requestReminderAccess() async throws -> Bool {
        return mockReminderAuthStatus == .fullAccess
    }

    func requestCalendarAccess() async throws -> Bool {
        return mockCalendarAuthStatus == .fullAccess
    }

    func requestAccess() async throws -> Bool {
        requestAccessCalled = true
        let reminders = try await requestReminderAccess()
        let calendar = try await requestCalendarAccess()
        return reminders && calendar
    }

    // MARK: - Protocol Implementation - Reminders

    func fetchIncompleteReminders() async throws -> [ReminderData] {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        return mockReminders.filter { !$0.isCompleted }
    }

    var createReminderCalled = false
    var lastCreatedReminderTitle: String?

    func createReminder(title: String, priority: Int = 0, dueDate: Date? = nil, notes: String? = nil) throws -> String {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        createReminderCalled = true
        lastCreatedReminderTitle = title
        let newID = "mock-created-\(UUID().uuidString)"
        let newReminder = ReminderData(id: newID, title: title, isCompleted: false, priority: priority, dueDate: dueDate, notes: notes)
        mockReminders.append(newReminder)
        return newID
    }

    var deleteReminderCalled = false
    var lastDeletedReminderID: String?

    func deleteReminder(id: String) throws {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        deleteReminderCalled = true
        lastDeletedReminderID = id
        mockReminders.removeAll { $0.id == id }
    }

    func markReminderComplete(reminderID: String) throws {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        if let error = markCompleteError {
            throw error
        }
        markReminderCompleteCalled = true
        lastCompletedReminderID = reminderID
        completedReminderIDs.append(reminderID)
    }

    func markReminderIncomplete(reminderID: String) throws {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        markReminderIncompleteCalled = true
        lastIncompletedReminderID = reminderID
    }

    var updateReminderCalled = false
    var lastUpdatedReminderID: String?
    var lastUpdatedTitle: String?

    func updateReminder(id: String, title: String?, priority: Int?, dueDate: Date?, notes: String?, isCompleted: Bool?) throws {
        guard mockReminderAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        updateReminderCalled = true
        lastUpdatedReminderID = id
        lastUpdatedTitle = title
    }

    // MARK: - Protocol Implementation - Calendar Events

    func fetchCalendarEvents(for date: Date) throws -> [CalendarEvent] {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        return mockEvents
    }

    func createCalendarEvent(title: String, startDate: Date, endDate: Date, reminderID: String? = nil) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        createCalendarEventCalled = true
        lastCreatedEventParams = (title, startDate, endDate, reminderID)
    }

    func deleteCalendarEvent(eventID: String) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        deleteCalendarEventCalled = true
        lastDeletedEventID = eventID
        // Silent fail if event not found (matches production behavior)
    }

    func moveCalendarEvent(eventID: String, to newStartDate: Date, duration: Int) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        // Silent implementation for now
    }

    var updateEventCategoryCalled = false
    var lastUpdatedCalendarItemID: String?
    var lastUpdatedCategory: String?

    func updateEventCategory(calendarItemID: String, category: String?) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        updateEventCategoryCalled = true
        lastUpdatedCalendarItemID = calendarItemID
        lastUpdatedCategory = category

        // Store category in UserDefaults mapping (same as real implementation)
        let key = "calendarEventCategories"
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let category = category, !category.isEmpty {
            dict[calendarItemID] = category
        } else {
            dict.removeValue(forKey: calendarItemID)
        }
        UserDefaults.standard.set(dict, forKey: key)
    }

    // MARK: - Protocol Implementation - Focus Blocks

    func fetchFocusBlocks(for date: Date) throws -> [FocusBlock] {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        return mockFocusBlocks
    }

    func createFocusBlock(startDate: Date, endDate: Date) throws -> String {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        return UUID().uuidString
    }

    func updateFocusBlock(eventID: String, taskIDs: [String], completedTaskIDs: [String], taskTimes: [String: Int] = [:]) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        // Update mock focus block if exists
        if let index = mockFocusBlocks.firstIndex(where: { $0.id == eventID }) {
            mockFocusBlocks[index] = FocusBlock(
                id: eventID,
                title: mockFocusBlocks[index].title,
                startDate: mockFocusBlocks[index].startDate,
                endDate: mockFocusBlocks[index].endDate,
                taskIDs: taskIDs,
                completedTaskIDs: completedTaskIDs,
                taskTimes: taskTimes
            )
        }
    }

    func deleteFocusBlock(eventID: String) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        mockFocusBlocks.removeAll { $0.id == eventID }
    }

    func updateFocusBlockTime(eventID: String, startDate: Date, endDate: Date) throws {
        guard mockCalendarAuthStatus == .fullAccess else {
            throw EventKitError.notAuthorized
        }
        // Silent implementation for mock
    }

    // MARK: - Protocol Implementation - Calendars

    func getWritableCalendars() -> [EKCalendar] {
        return mockCalendars.filter { $0.allowsContentModifications }
    }

    func getAllCalendars() -> [EKCalendar] {
        return mockCalendars
    }

    // MARK: - Protocol Implementation - Reminder Lists

    var mockReminderLists: [ReminderListInfo] = []

    func getAllReminderLists() -> [ReminderListInfo] {
        return mockReminderLists
    }
}
