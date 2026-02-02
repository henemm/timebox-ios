import XCTest
@testable import FocusBlox

/// Unit Tests for CalendarEvent category functionality
/// TDD RED: These tests MUST FAIL because category property doesn't exist yet
final class CalendarEventCategoryTests: XCTestCase {

    // MARK: - Category Parsing Tests

    /// GIVEN: CalendarEvent with notes containing "category:income"
    /// WHEN: Accessing .category property
    /// THEN: Returns "income"
    func testCategoryParsedFromNotes() throws {
        let event = CalendarEvent(
            id: "test-1",
            title: "Client Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "category:income"
        )

        XCTAssertEqual(event.category, "income",
            "Event with 'category:income' in notes should return 'income'")
    }

    /// GIVEN: CalendarEvent with notes containing multiple lines including category
    /// WHEN: Accessing .category property
    /// THEN: Returns the category value correctly
    func testCategoryParsedFromMultilineNotes() throws {
        let event = CalendarEvent(
            id: "test-2",
            title: "Workshop",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            calendarColor: nil,
            notes: "Some notes here\ncategory:learning\nMore notes"
        )

        XCTAssertEqual(event.category, "learning",
            "Category should be parsed correctly from multiline notes")
    }

    /// GIVEN: CalendarEvent with empty notes
    /// WHEN: Accessing .category property
    /// THEN: Returns nil
    func testCategoryNilWhenNoNotes() throws {
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
            "Event without notes should have nil category")
    }

    /// GIVEN: CalendarEvent with notes but no category line
    /// WHEN: Accessing .category property
    /// THEN: Returns nil
    func testCategoryNilWhenNotInNotes() throws {
        let event = CalendarEvent(
            id: "test-4",
            title: "Lunch Break",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Just some regular notes without category"
        )

        XCTAssertNil(event.category,
            "Event without 'category:' in notes should have nil category")
    }

    /// GIVEN: CalendarEvent with focusBlock:true in notes
    /// WHEN: Accessing .category property
    /// THEN: Returns nil (focus blocks use task categories, not event category)
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

    /// GIVEN: CalendarEvent with category that has special characters
    /// WHEN: Accessing .category property
    /// THEN: Returns the category value including underscores
    func testCategoryWithUnderscore() throws {
        let event = CalendarEvent(
            id: "test-6",
            title: "Giving Back Session",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "category:giving_back"
        )

        XCTAssertEqual(event.category, "giving_back",
            "Category with underscore should be parsed correctly")
    }

    // MARK: - All Category Values

    /// GIVEN: Events with each valid category
    /// WHEN: Accessing .category
    /// THEN: All 5 categories are correctly parsed
    func testAllCategoryValues() throws {
        let categories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        for cat in categories {
            let event = CalendarEvent(
                id: "test-\(cat)",
                title: "Test \(cat)",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                calendarColor: nil,
                notes: "category:\(cat)"
            )

            XCTAssertEqual(event.category, cat,
                "Category '\(cat)' should be parsed correctly")
        }
    }
}
