import XCTest
@testable import FocusBlox

/// Bug 63: Kategorie-Zuweisung bei wiederkehrenden Kalender-Events mit Gaesten
/// Fix: Lokales UserDefaults-Mapping mit calendarItemIdentifier als Key
///
/// TDD RED: Diese Tests MUESSEN FEHLSCHLAGEN weil:
/// - CalendarEvent hat noch kein calendarItemIdentifier Property
/// - category getter liest noch aus Notes statt UserDefaults
/// - updateEventCategory schreibt noch in Notes/KV Store statt UserDefaults
final class CalendarCategoryMappingTests: XCTestCase {

    private let mappingKey = "calendarEventCategories"

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: mappingKey)
        super.tearDown()
    }

    // MARK: - CalendarEvent.calendarItemIdentifier

    /// GIVEN: CalendarEvent created with calendarItemIdentifier
    /// WHEN: Accessing calendarItemIdentifier
    /// THEN: Returns the stored value
    /// BREAKS: CalendarEvent test init has no calendarItemIdentifier parameter
    func testCalendarEventHasCalendarItemIdentifier() {
        let event = CalendarEvent(
            id: "occurrence-id-123",
            title: "Weekly Standup",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true,
            calendarItemIdentifier: "stable-series-id-ABC"
        )

        XCTAssertEqual(event.calendarItemIdentifier, "stable-series-id-ABC",
            "CalendarEvent should store calendarItemIdentifier for stable recurring event identification")
    }

    // MARK: - Category from UserDefaults Mapping

    /// GIVEN: Category stored in UserDefaults for a calendarItemIdentifier
    /// WHEN: CalendarEvent with matching calendarItemIdentifier accesses .category
    /// THEN: Returns the stored category
    /// BREAKS: category getter doesn't read from UserDefaults yet
    func testCategoryReadFromUserDefaultsMapping() {
        // Setup: Store category mapping in UserDefaults
        let calendarItemID = "series-weekly-standup"
        let dict: [String: String] = [calendarItemID: "income"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let event = CalendarEvent(
            id: "occurrence-mon-id",
            title: "Weekly Standup",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true,
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertEqual(event.category, "income",
            "Category should be read from UserDefaults mapping using calendarItemIdentifier")
    }

    /// GIVEN: Category in UserDefaults for calendarItemIdentifier
    /// AND: Two events with DIFFERENT eventIdentifier but SAME calendarItemIdentifier
    /// WHEN: Both access .category
    /// THEN: Both return the same category
    /// THIS IS THE CORE BUG FIX: Recurring occurrences share category via calendarItemIdentifier
    func testRecurringOccurrencesShareCategory() {
        let calendarItemID = "series-team-meeting"
        let dict: [String: String] = [calendarItemID: "maintenance"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let mondayOccurrence = CalendarEvent(
            id: "occurrence-monday-id",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true,
            calendarItemIdentifier: calendarItemID
        )

        let tuesdayOccurrence = CalendarEvent(
            id: "occurrence-tuesday-id",
            title: "Team Meeting",
            startDate: Date().addingTimeInterval(86400),
            endDate: Date().addingTimeInterval(86400 + 3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true,
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertEqual(mondayOccurrence.category, "maintenance",
            "Monday occurrence should have category from calendarItemIdentifier mapping")
        XCTAssertEqual(tuesdayOccurrence.category, "maintenance",
            "Tuesday occurrence should have SAME category — same calendarItemIdentifier")
    }

    /// GIVEN: No category mapping in UserDefaults
    /// WHEN: CalendarEvent accesses .category
    /// THEN: Returns nil
    func testCategoryNilWhenNoMapping() {
        let event = CalendarEvent(
            id: "some-id",
            title: "Unmapped Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: false,
            calendarItemIdentifier: "unmapped-series-id"
        )

        XCTAssertNil(event.category,
            "Event without category mapping should return nil")
    }

    /// GIVEN: Event with attendees (previously read-only for category)
    /// WHEN: Category is stored via UserDefaults mapping
    /// THEN: Category is accessible — NO read-only distinction needed
    func testEventsWithAttendeesCanHaveCategory() {
        let calendarItemID = "client-meeting-series"
        let dict: [String: String] = [calendarItemID: "income"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let event = CalendarEvent(
            id: "client-meeting-occurrence",
            title: "Client Review",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            hasAttendees: true,
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertTrue(event.hasAttendees, "Event should have attendees")
        XCTAssertEqual(event.category, "income",
            "Events with attendees should have category via UserDefaults — no read-only limitation")
    }

    // MARK: - updateEventCategory via MockEventKitRepository

    /// GIVEN: MockEventKitRepository with event
    /// WHEN: updateEventCategory called with calendarItemID
    /// THEN: Category is stored in UserDefaults mapping
    /// BREAKS: Protocol uses eventID parameter, not calendarItemID
    func testUpdateEventCategoryStoresInUserDefaults() throws {
        let mock = MockEventKitRepository()
        let calendarItemID = "recurring-standup-series"

        mock.mockEvents = [
            CalendarEvent(
                id: "occurrence-1",
                title: "Standup",
                startDate: Date(),
                endDate: Date().addingTimeInterval(1800),
                isAllDay: false,
                calendarColor: nil,
                notes: nil,
                hasAttendees: true,
                calendarItemIdentifier: calendarItemID
            )
        ]

        try mock.updateEventCategory(calendarItemID: calendarItemID, category: "maintenance")

        XCTAssertTrue(mock.updateEventCategoryCalled, "Method should be called")
        XCTAssertEqual(mock.lastUpdatedCalendarItemID, calendarItemID,
            "Should store calendarItemID, not eventID")
        XCTAssertEqual(mock.lastUpdatedCategory, "maintenance",
            "Should store the category")
    }

    /// GIVEN: Category was previously set
    /// WHEN: updateEventCategory called with nil category
    /// THEN: Category mapping is removed
    func testRemoveCategoryDeletesMapping() throws {
        // Pre-set a category
        let calendarItemID = "series-to-clear"
        var dict: [String: String] = [calendarItemID: "learning"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let mock = MockEventKitRepository()
        try mock.updateEventCategory(calendarItemID: calendarItemID, category: nil)

        // Verify mapping was removed
        dict = UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
        XCTAssertNil(dict[calendarItemID],
            "Setting category to nil should remove the mapping")
    }

    // MARK: - All 5 Categories

    /// GIVEN: Each of the 5 categories stored in UserDefaults
    /// WHEN: CalendarEvent accesses .category
    /// THEN: All 5 categories are correctly returned
    func testAllCategoryValuesFromMapping() {
        let categories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        for cat in categories {
            let calendarItemID = "series-\(cat)"
            let dict: [String: String] = [calendarItemID: cat]
            UserDefaults.standard.set(dict, forKey: mappingKey)

            let event = CalendarEvent(
                id: "occ-\(cat)",
                title: "Test \(cat)",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                calendarColor: nil,
                notes: nil,
                calendarItemIdentifier: calendarItemID
            )

            XCTAssertEqual(event.category, cat,
                "Category '\(cat)' should be read from UserDefaults mapping")
        }
    }
}
