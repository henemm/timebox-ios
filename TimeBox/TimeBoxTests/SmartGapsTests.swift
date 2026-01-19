import XCTest
@testable import TimeBox

/// TDD RED Tests for Smart Gaps Feature
/// These tests define the expected behavior of the gap detection algorithm
final class SmartGapsTests: XCTestCase {

    // MARK: - Test 1: Find gaps between events

    func testFindFreeSlotsFindsGaps() {
        // GIVEN: Calendar with events at 8-9, 11-12, 15-16
        let date = createDate(year: 2026, month: 1, day: 20)
        let events = [
            createEvent(date: date, startHour: 8, endHour: 9),   // 8:00-9:00
            createEvent(date: date, startHour: 11, endHour: 12), // 11:00-12:00
            createEvent(date: date, startHour: 15, endHour: 16)  // 15:00-16:00
        ]

        // WHEN: findFreeSlots called
        let finder = GapFinder(events: events, focusBlocks: [], date: date)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // THEN: Should find gaps at 9-10, 10-11, 12-13, 13-14, 14-15, 16-17...
        XCTAssertFalse(slots.isEmpty, "Should find free slots between events")

        // Check that 9:00-10:00 slot exists (gap after first event)
        let nineToTen = slots.first { slot in
            Calendar.current.component(.hour, from: slot.startDate) == 9
        }
        XCTAssertNotNil(nineToTen, "Should find 9:00-10:00 slot")
    }

    // MARK: - Test 2: Respect minimum duration

    func testFindFreeSlotsRespectsMinDuration() {
        // GIVEN: 20-minute gap between events (8:00-8:40, 9:00-10:00)
        let date = createDate(year: 2026, month: 1, day: 20)
        let events = [
            createEvent(date: date, startHour: 8, startMinute: 0, endHour: 8, endMinute: 40),
            createEvent(date: date, startHour: 9, endHour: 10)
        ]

        // WHEN: findFreeSlots with min 30 minutes
        let finder = GapFinder(events: events, focusBlocks: [], date: date)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // THEN: The 20-minute gap (8:40-9:00) should NOT be included
        let shortGap = slots.first { slot in
            let hour = Calendar.current.component(.hour, from: slot.startDate)
            let minute = Calendar.current.component(.minute, from: slot.startDate)
            return hour == 8 && minute == 40
        }
        XCTAssertNil(shortGap, "20-minute gap should be excluded (min is 30)")
    }

    // MARK: - Test 3: Respect maximum duration

    func testFindFreeSlotsRespectsMaxDuration() {
        // GIVEN: 90-minute gap (10:00-11:30 free)
        let date = createDate(year: 2026, month: 1, day: 20)
        let events = [
            createEvent(date: date, startHour: 9, endHour: 10),
            createEvent(date: date, startHour: 11, startMinute: 30, endHour: 12, endMinute: 30)
        ]

        // WHEN: findFreeSlots with max 60 minutes
        let finder = GapFinder(events: events, focusBlocks: [], date: date)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // THEN: Should return 60-min slot (not 90-min)
        let gapSlot = slots.first { slot in
            Calendar.current.component(.hour, from: slot.startDate) == 10
        }
        XCTAssertNotNil(gapSlot, "Should find slot starting at 10:00")
        if let slot = gapSlot {
            XCTAssertLessThanOrEqual(slot.durationMinutes, 60, "Slot should be max 60 minutes")
        }
    }

    // MARK: - Test 4: Whole day free shows suggestions

    func testWholeDayFreeShowsSuggestions() {
        // GIVEN: No calendar events for the day
        let date = createDate(year: 2026, month: 1, day: 20)
        let events: [CalendarEvent] = []

        // WHEN: findFreeSlots called
        let finder = GapFinder(events: events, focusBlocks: [], date: date)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // THEN: Should return 4 default suggestions at 9, 11, 14, 16
        XCTAssertEqual(slots.count, 4, "Should show 4 suggested slots on free day")

        let hours = slots.map { Calendar.current.component(.hour, from: $0.startDate) }
        XCTAssertTrue(hours.contains(9), "Should suggest 9:00")
        XCTAssertTrue(hours.contains(11), "Should suggest 11:00")
        XCTAssertTrue(hours.contains(14), "Should suggest 14:00")
        XCTAssertTrue(hours.contains(16), "Should suggest 16:00")
    }

    // MARK: - Helpers

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    private func createEvent(date: Date, startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) -> CalendarEvent {
        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        let startDate = Calendar.current.date(from: startComponents) ?? date

        var endComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = endHour
        endComponents.minute = endMinute
        let endDate = Calendar.current.date(from: endComponents) ?? date

        return CalendarEvent(
            id: UUID().uuidString,
            title: "Test Event",
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )
    }
}
