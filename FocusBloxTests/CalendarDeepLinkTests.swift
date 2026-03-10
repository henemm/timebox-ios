import XCTest
@testable import FocusBlox

final class CalendarDeepLinkTests: XCTestCase {

    // MARK: - calendarAppURL Tests

    func test_calendarAppURL_returnsCalshowURLWithTimestamp() {
        // Given: An event at a specific time
        let startDate = Date(timeIntervalSince1970: 1_773_252_000) // 2026-03-09 14:00 UTC
        let event = CalendarEvent(
            id: "test-1",
            title: "Meeting",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )

        // When
        let url = event.calendarAppURL

        // Then: Should be a calshow URL with the event's start date timestamp
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("calshow:"))
        let timestamp = String(url!.absoluteString.dropFirst("calshow:".count))
        let parsedTimestamp = Double(timestamp)
        XCTAssertNotNil(parsedTimestamp)
        XCTAssertEqual(parsedTimestamp!, startDate.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func test_calendarAppURL_worksForAllDayEvents() {
        // Given: An all-day event
        let startDate = Calendar.current.startOfDay(for: Date())
        let event = CalendarEvent(
            id: "test-2",
            title: "Ganztaegig",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(86400),
            isAllDay: true,
            calendarColor: nil,
            notes: nil
        )

        // When
        let url = event.calendarAppURL

        // Then: Should still produce a valid calshow URL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("calshow:"))
    }

    func test_focusBlockEvent_isFocusBlockTrue() {
        // Given: A FocusBlock event
        let event = CalendarEvent(
            id: "fb-1",
            title: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:task1|task2"
        )

        // Then: isFocusBlock should be true (prerequisite for UI filter)
        XCTAssertTrue(event.isFocusBlock)
    }

    func test_externalEvent_isFocusBlockFalse() {
        // Given: A regular external calendar event
        let event = CalendarEvent(
            id: "ext-1",
            title: "Arzttermin",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Praxis Dr. Mueller"
        )

        // Then: isFocusBlock should be false
        XCTAssertFalse(event.isFocusBlock)
    }
}
