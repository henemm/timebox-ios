import XCTest
@testable import TimeBox
import EventKit

final class MockEventKitRepositoryTests: XCTestCase {

    var mock: MockEventKitRepository!

    override func setUp() {
        mock = MockEventKitRepository()
    }

    override func tearDown() async throws {
        mock = nil
    }

    // MARK: - Authorization Tests

    /// GIVEN: Mock with authorized state
    /// WHEN: Checking auth status
    /// THEN: Returns mocked status
    func test_mockRepository_returnsConfiguredAuthStatus() throws {
        // GIVEN: Mock with authorized state
        mock.mockCalendarAuthStatus = .fullAccess
        mock.mockReminderAuthStatus = .fullAccess

        // WHEN: Checking auth status
        let calendarAuth = mock.calendarAuthStatus
        let reminderAuth = mock.reminderAuthStatus

        // THEN: Returns mocked status
        XCTAssertEqual(calendarAuth, .fullAccess)
        XCTAssertEqual(reminderAuth, .fullAccess)
    }

    /// GIVEN: Mock with denied state
    /// WHEN: Requesting access
    /// THEN: Returns false
    func test_mockRepository_canSimulateDeniedAccess() async throws {
        // GIVEN: Mock with denied state
        mock.mockCalendarAuthStatus = .denied

        // WHEN: Requesting access
        let hasAccess = try await mock.requestAccess()

        // THEN: Returns false
        XCTAssertFalse(hasAccess)
    }

    // MARK: - Mock Data Tests

    /// GIVEN: Mock with test reminders
    /// WHEN: Fetching reminders
    /// THEN: Returns mocked data
    func test_mockRepository_returnsConfiguredReminders() async throws {
        // GIVEN: Mock with test reminders
        mock.mockReminders = [
            ReminderData(id: "test-1", title: "Test Task"),
            ReminderData(id: "test-2", title: "Another Task")
        ]

        // WHEN: Fetching reminders
        let reminders = try await mock.fetchIncompleteReminders()

        // THEN: Returns mocked data
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders[0].id, "test-1")
    }

    /// GIVEN: Mock with test events
    /// WHEN: Fetching events
    /// THEN: Returns mocked data
    func test_mockRepository_returnsConfiguredEvents() throws {
        // GIVEN: Mock with test events
        let testDate = Date()
        mock.mockEvents = [
            CalendarEvent(
                id: "evt-1",
                title: "Meeting",
                startDate: testDate,
                endDate: testDate.addingTimeInterval(3600),
                isAllDay: false,
                calendarColor: nil,
                notes: nil
            )
        ]

        // WHEN: Fetching events
        let events = try mock.fetchCalendarEvents(for: testDate)

        // THEN: Returns mocked data
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].id, "evt-1")
    }

    // MARK: - Method Call Tracking Tests

    /// GIVEN: Mock repository
    /// WHEN: Deleting event
    /// THEN: Method call is recorded
    func test_mockRepository_recordsDeleteCalls() throws {
        // GIVEN: Mock repository (setUp)

        // WHEN: Deleting event
        try mock.deleteCalendarEvent(eventID: "test-id")

        // THEN: Method call is recorded
        XCTAssertTrue(mock.deleteCalendarEventCalled)
        XCTAssertEqual(mock.lastDeletedEventID, "test-id")
    }
}
