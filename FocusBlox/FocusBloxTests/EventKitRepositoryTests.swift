import XCTest
@testable import FocusBlox

final class EventKitRepositoryTests: XCTestCase {

    var eventKitRepo: (any EventKitRepositoryProtocol)!

    override func setUp() {
        let mock = MockEventKitRepository()
        mock.mockCalendarAuthStatus = .fullAccess
        mock.mockReminderAuthStatus = .fullAccess
        eventKitRepo = mock
    }

    override func tearDown() async throws {
        eventKitRepo = nil
    }

    // MARK: - TDD RED: markReminderComplete Tests

    /// GIVEN: An invalid reminder ID
    /// WHEN: markReminderComplete is called
    /// THEN: No error is thrown (silent fail)
    func testMarkReminderCompleteWithInvalidIDDoesNotThrow() throws {
        // This test should FAIL because method doesn't exist yet
        XCTAssertNoThrow(try eventKitRepo.markReminderComplete(reminderID: "invalid-id-12345"))
    }

    /// GIVEN: markReminderComplete method exists
    /// WHEN: Called with any ID
    /// THEN: Method is callable (compile-time check via this test)
    func testMarkReminderCompleteMethodExists() throws {
        // This test will FAIL TO COMPILE because method doesn't exist
        // After implementation: verifies method signature is correct
        do {
            try eventKitRepo.markReminderComplete(reminderID: "test-id")
        } catch {
            // Expected: Either notAuthorized or silent success
            // We just verify it's callable
        }
    }

    // MARK: - TDD RED: Step 6 - Event Editing Tests

    /// GIVEN: An invalid reminder ID
    /// WHEN: markReminderIncomplete is called
    /// THEN: No error is thrown (silent fail)
    func testMarkReminderIncompleteWithInvalidIDDoesNotThrow() throws {
        XCTAssertNoThrow(try eventKitRepo.markReminderIncomplete(reminderID: "invalid-id"))
    }

    /// GIVEN: An invalid event ID
    /// WHEN: deleteCalendarEvent is called
    /// THEN: No error is thrown (silent fail)
    func testDeleteCalendarEventWithInvalidIDDoesNotThrow() throws {
        XCTAssertNoThrow(try eventKitRepo.deleteCalendarEvent(eventID: "invalid-event-id"))
    }

    /// GIVEN: createCalendarEvent with reminderID parameter
    /// WHEN: Method is called
    /// THEN: Method is callable with new signature
    func testCreateCalendarEventWithReminderIDExists() throws {
        do {
            try eventKitRepo.createCalendarEvent(
                title: "Test",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                reminderID: "test-reminder-id"
            )
        } catch {
            // Expected: notAuthorized in test environment
        }
    }
}

// MARK: - CalendarEvent Tests

final class CalendarEventTests: XCTestCase {

    /// GIVEN: CalendarEvent with notes containing reminderID
    /// WHEN: Accessing reminderID property
    /// THEN: Returns the parsed reminderID
    func testReminderIDParsesFromNotes() {
        // This test will FAIL because CalendarEvent doesn't have notes/reminderID yet
        let event = CalendarEvent(
            id: "test-id",
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "reminderID:abc123"
        )
        XCTAssertEqual(event.reminderID, "abc123")
    }

    /// GIVEN: CalendarEvent with nil notes
    /// WHEN: Accessing reminderID property
    /// THEN: Returns nil
    func testReminderIDReturnsNilWhenNoNotes() {
        let event = CalendarEvent(
            id: "test-id",
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )
        XCTAssertNil(event.reminderID)
    }

    /// GIVEN: CalendarEvent with notes NOT containing reminderID prefix
    /// WHEN: Accessing reminderID property
    /// THEN: Returns nil
    func testReminderIDReturnsNilWhenWrongFormat() {
        let event = CalendarEvent(
            id: "test-id",
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Some random notes"
        )
        XCTAssertNil(event.reminderID)
    }
}
