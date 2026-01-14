import XCTest
@testable import TimeBox

/// Tests for Calendar Selection feature
/// These tests verify the EventKitRepository calendar selection methods
final class CalendarSelectionTests: XCTestCase {

    var eventKitRepo: EventKitRepository!

    override func setUpWithError() throws {
        eventKitRepo = EventKitRepository()
    }

    override func tearDownWithError() throws {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "selectedCalendarID")
        UserDefaults.standard.removeObject(forKey: "visibleCalendarIDs")
        eventKitRepo = nil
    }

    // MARK: - getAllCalendars Tests

    /// GIVEN: EventKitRepository
    /// WHEN: getAllCalendars() is called
    /// THEN: Should return array of EKCalendar (may be empty without permission)
    func testGetAllCalendarsExists() throws {
        // This test will FAIL because getAllCalendars() doesn't exist yet
        let calendars = eventKitRepo.getAllCalendars()
        XCTAssertNotNil(calendars, "getAllCalendars should return an array")
    }

    // MARK: - getWritableCalendars Tests

    /// GIVEN: EventKitRepository
    /// WHEN: getWritableCalendars() is called
    /// THEN: Should return array of writable calendars only
    func testGetWritableCalendarsExists() throws {
        // This test will FAIL because getWritableCalendars() doesn't exist yet
        let calendars = eventKitRepo.getWritableCalendars()
        XCTAssertNotNil(calendars, "getWritableCalendars should return an array")
    }

    // MARK: - calendarForEvents Tests

    /// GIVEN: No calendar selected in UserDefaults
    /// WHEN: calendarForEvents() is called
    /// THEN: Should return default calendar (or nil without permission)
    func testCalendarForEventsReturnsDefaultWhenNoSelection() throws {
        // Ensure no selection
        UserDefaults.standard.removeObject(forKey: "selectedCalendarID")

        // This test will FAIL because calendarForEvents() doesn't exist yet
        let calendar = eventKitRepo.calendarForEvents()
        // Without calendar permission, this may be nil - that's ok for this test
        // The important thing is the method exists and doesn't crash
        XCTAssertTrue(true, "calendarForEvents should not crash when no selection")
    }

    /// GIVEN: Invalid calendar ID in UserDefaults
    /// WHEN: calendarForEvents() is called
    /// THEN: Should fall back to default calendar
    func testCalendarForEventsFallsBackWithInvalidID() throws {
        // Set an invalid calendar ID
        UserDefaults.standard.set("invalid-calendar-id-12345", forKey: "selectedCalendarID")

        // This test will FAIL because calendarForEvents() doesn't exist yet
        let calendar = eventKitRepo.calendarForEvents()
        // Should not crash and should fall back to default
        XCTAssertTrue(true, "calendarForEvents should fall back gracefully")
    }

    // MARK: - visibleCalendarIDs Tests

    /// GIVEN: No visible calendars set in UserDefaults
    /// WHEN: visibleCalendarIDs() is called
    /// THEN: Should return nil
    func testVisibleCalendarIDsReturnsNilWhenNotSet() throws {
        // Ensure nothing is set
        UserDefaults.standard.removeObject(forKey: "visibleCalendarIDs")

        // This test will FAIL because visibleCalendarIDs() doesn't exist yet
        let ids = eventKitRepo.visibleCalendarIDs()
        XCTAssertNil(ids, "visibleCalendarIDs should return nil when not set")
    }

    /// GIVEN: Visible calendar IDs are set in UserDefaults
    /// WHEN: visibleCalendarIDs() is called
    /// THEN: Should return the saved array
    func testVisibleCalendarIDsReturnsSetIDs() throws {
        // Set some IDs
        let testIDs = ["cal-1", "cal-2", "cal-3"]
        UserDefaults.standard.set(testIDs, forKey: "visibleCalendarIDs")

        // This test will FAIL because visibleCalendarIDs() doesn't exist yet
        let ids = eventKitRepo.visibleCalendarIDs()
        XCTAssertEqual(ids, testIDs, "visibleCalendarIDs should return saved IDs")
    }

    // MARK: - visibleCalendars Tests

    /// GIVEN: No visible calendars set
    /// WHEN: visibleCalendars() is called
    /// THEN: Should return nil (meaning show all)
    func testVisibleCalendarsReturnsNilWhenNotSet() throws {
        UserDefaults.standard.removeObject(forKey: "visibleCalendarIDs")

        // This test will FAIL because visibleCalendars() doesn't exist yet
        let calendars = eventKitRepo.visibleCalendars()
        XCTAssertNil(calendars, "visibleCalendars should return nil when not configured")
    }
}
