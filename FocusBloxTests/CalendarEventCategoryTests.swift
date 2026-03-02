import XCTest
@testable import FocusBlox

/// Unit Tests for CalendarEvent category functionality
/// Updated for Bug 63: Category now stored in UserDefaults mapping (not notes)
final class CalendarEventCategoryTests: XCTestCase {

    private let mappingKey = "calendarEventCategories"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: mappingKey)
        super.tearDown()
    }

    // MARK: - Category from UserDefaults Mapping

    /// GIVEN: CalendarEvent with category stored in UserDefaults mapping
    /// WHEN: Accessing .category property
    /// THEN: Returns the category
    func testCategoryParsedFromMapping() throws {
        let calendarItemID = "test-1-series"
        let dict: [String: String] = [calendarItemID: "income"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let event = CalendarEvent(
            id: "test-1",
            title: "Client Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertEqual(event.category, "income",
            "Event with category in UserDefaults mapping should return 'income'")
    }

    /// GIVEN: CalendarEvent with category in UserDefaults (multiline notes are irrelevant now)
    /// WHEN: Accessing .category property
    /// THEN: Returns the category from mapping
    func testCategoryFromMappingIgnoresNotes() throws {
        let calendarItemID = "test-2-series"
        let dict: [String: String] = [calendarItemID: "learning"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let event = CalendarEvent(
            id: "test-2",
            title: "Workshop",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            calendarColor: nil,
            notes: "Some notes here\nMore notes",
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertEqual(event.category, "learning",
            "Category should come from UserDefaults mapping, not notes")
    }

    /// GIVEN: CalendarEvent with no mapping
    /// WHEN: Accessing .category property
    /// THEN: Returns nil
    func testCategoryNilWhenNoMapping() throws {
        let event = CalendarEvent(
            id: "test-3",
            title: "Random Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )

        XCTAssertNil(event.category,
            "Event without mapping should have nil category")
    }

    /// GIVEN: CalendarEvent with notes but no mapping
    /// WHEN: Accessing .category property
    /// THEN: Returns nil (notes are no longer used for category)
    func testCategoryNilWhenNotInMapping() throws {
        let event = CalendarEvent(
            id: "test-4",
            title: "Lunch Break",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Just some regular notes"
        )

        XCTAssertNil(event.category,
            "Event without mapping should have nil category even with notes")
    }

    /// GIVEN: CalendarEvent that is a focus block (no mapping)
    /// WHEN: Accessing .category property
    /// THEN: Returns nil
    func testFocusBlockHasNoCategory() throws {
        let event = CalendarEvent(
            id: "test-5",
            title: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:task-1|task-2"
        )

        XCTAssertNil(event.category,
            "Focus blocks should not have event category (they use task categories)")
    }

    /// GIVEN: CalendarEvent with underscore category in mapping
    /// WHEN: Accessing .category property
    /// THEN: Returns the category value including underscores
    func testCategoryWithUnderscore() throws {
        let calendarItemID = "test-6-series"
        let dict: [String: String] = [calendarItemID: "giving_back"]
        UserDefaults.standard.set(dict, forKey: mappingKey)

        let event = CalendarEvent(
            id: "test-6",
            title: "Giving Back Session",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil,
            calendarItemIdentifier: calendarItemID
        )

        XCTAssertEqual(event.category, "giving_back",
            "Category with underscore should be returned correctly")
    }

    // MARK: - All Category Values

    /// GIVEN: Events with each valid category in mapping
    /// WHEN: Accessing .category
    /// THEN: All 5 categories are correctly returned
    func testAllCategoryValues() throws {
        let categories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        for cat in categories {
            let calendarItemID = "test-\(cat)-series"
            let dict: [String: String] = [calendarItemID: cat]
            UserDefaults.standard.set(dict, forKey: mappingKey)

            let event = CalendarEvent(
                id: "test-\(cat)",
                title: "Test \(cat)",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                calendarColor: nil,
                notes: nil,
                calendarItemIdentifier: calendarItemID
            )

            XCTAssertEqual(event.category, cat,
                "Category '\(cat)' should be returned from mapping")
        }
    }
}
