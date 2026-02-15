import XCTest
@testable import FocusBlox

/// Unit Tests for CalendarEvent read-only/attendee detection (Bug 50)
/// TDD RED: These tests MUST FAIL because hasAttendees/isReadOnly properties don't exist yet
final class CalendarEventReadOnlyTests: XCTestCase {

    // MARK: - hasAttendees Tests

    /// GIVEN: CalendarEvent created with hasAttendees = true
    /// WHEN: Accessing .hasAttendees
    /// THEN: Returns true
    func testHasAttendees_true() {
        let event = CalendarEvent(
            id: "test-1",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true
        )

        XCTAssertTrue(event.hasAttendees,
            "Event created with hasAttendees=true should return true")
    }

    /// GIVEN: CalendarEvent created with hasAttendees = false
    /// WHEN: Accessing .hasAttendees
    /// THEN: Returns false
    func testHasAttendees_false() {
        let event = CalendarEvent(
            id: "test-2",
            title: "Solo Work",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: false
        )

        XCTAssertFalse(event.hasAttendees,
            "Event created with hasAttendees=false should return false")
    }

    /// GIVEN: CalendarEvent created with default test init (no hasAttendees param)
    /// WHEN: Accessing .hasAttendees
    /// THEN: Returns false (safe default)
    func testHasAttendees_defaultIsFalse() {
        let event = CalendarEvent(
            id: "test-3",
            title: "Regular Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )

        XCTAssertFalse(event.hasAttendees,
            "Default hasAttendees should be false for backwards compatibility")
    }

    // MARK: - isReadOnly Tests

    /// GIVEN: CalendarEvent with attendees
    /// WHEN: Accessing .isReadOnly
    /// THEN: Returns true (events with attendees can't be moved)
    func testIsReadOnly_withAttendees() {
        let event = CalendarEvent(
            id: "test-4",
            title: "Client Call",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true
        )

        XCTAssertTrue(event.isReadOnly,
            "Event with attendees should be read-only")
    }

    /// GIVEN: CalendarEvent without attendees
    /// WHEN: Accessing .isReadOnly
    /// THEN: Returns false
    func testIsReadOnly_withoutAttendees() {
        let event = CalendarEvent(
            id: "test-5",
            title: "Focus Time",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: false
        )

        XCTAssertFalse(event.isReadOnly,
            "Event without attendees should not be read-only")
    }

    // MARK: - EventKitError Tests

    /// GIVEN: EventKitError.eventReadOnly
    /// WHEN: Accessing errorDescription
    /// THEN: Returns user-friendly German message
    func testEventReadOnlyError_hasDescription() {
        let error = EventKitError.eventReadOnly

        XCTAssertNotNil(error.errorDescription,
            "eventReadOnly error should have a description")
        XCTAssertTrue(error.errorDescription?.contains("Gaeste") == true || error.errorDescription?.contains("verschoben") == true,
            "Error should mention guests or inability to move")
    }
}
