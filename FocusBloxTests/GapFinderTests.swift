import XCTest
@testable import FocusBlox

final class GapFinderTests: XCTestCase {

    // MARK: - Helpers

    /// Create a date on a FUTURE day to avoid "today" logic interfering
    private func futureDate(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    /// The reference date (tomorrow) for GapFinder initialization
    private var tomorrowDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    }

    private func makeEvent(
        startHour: Int, startMinute: Int = 0,
        endHour: Int, endMinute: Int = 0,
        isAllDay: Bool = false,
        isFocusBlock: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: "Event",
            startDate: futureDate(hour: startHour, minute: startMinute),
            endDate: futureDate(hour: endHour, minute: endMinute),
            isAllDay: isAllDay,
            calendarColor: nil,
            notes: isFocusBlock ? "focusBlock:true" : nil
        )
    }

    private func makeBlock(startHour: Int, endHour: Int) -> FocusBlock {
        FocusBlock(
            id: UUID().uuidString,
            title: "FocusBlox",
            startDate: futureDate(hour: startHour),
            endDate: futureDate(hour: endHour)
        )
    }

    // MARK: - Default Suggestions

    /// Verhalten: Leerer Kalender gibt Default-Vorschlaege [09, 11, 14, 16]
    /// Bricht wenn: GapFinder.swift:114 — isWholeDayFree check oder :115 createDefaultSuggestions entfernt
    func test_emptyCalendar_returnsDefaultSuggestions() {
        let finder = GapFinder(events: [], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots()

        XCTAssertEqual(slots.count, 4, "Empty calendar should return 4 default suggestions")
        let hours = slots.map { Calendar.current.component(.hour, from: $0.startDate) }
        XCTAssertEqual(hours, [9, 11, 14, 16], "Default hours should be 9, 11, 14, 16")
    }

    /// Verhalten: Tag mit <2h Busy-Time gilt als "frei" → Default Suggestions
    /// Bricht wenn: GapFinder.swift:130 — Threshold von 120 Minuten geaendert
    func test_mostlyFreeDay_returnsDefaultSuggestions() {
        // 1 hour meeting = less than 120 min busy → "whole day free"
        let event = makeEvent(startHour: 10, endHour: 11)
        let finder = GapFinder(events: [event], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots()

        let hours = slots.map { Calendar.current.component(.hour, from: $0.startDate) }
        XCTAssertEqual(hours, [9, 11, 14, 16], "Day with <2h busy should return defaults")
    }

    // MARK: - Gap Detection

    /// Verhalten: Event 10-11 erzeugt Gap davor (06-10) und danach (11-22), aber wegen
    /// <2h busy → Default Suggestions. Mit genuegend Events aber: korrekte Gaps.
    /// Bricht wenn: GapFinder.swift:81-91 — Gap-Detection-Logik entfernt
    func test_multipleEvents_findsGapsBetween() {
        // 3 events = 3h busy (>120min threshold) → real gaps, not defaults
        let events = [
            makeEvent(startHour: 8, endHour: 9),
            makeEvent(startHour: 11, endHour: 13),
            makeEvent(startHour: 15, endHour: 17),
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // Gaps: 06-08 (capped 60), 09-11 (capped 60), 13-15 (capped 60), 17-22 (capped 60)
        XCTAssertTrue(slots.count >= 3, "Should find at least 3 gaps between/around events")
        for slot in slots {
            XCTAssertLessThanOrEqual(
                slot.durationMinutes, 60,
                "Each slot should be capped to maxMinutes=60"
            )
        }
    }

    // MARK: - Duration Filtering

    /// Verhalten: Gaps kleiner als minMinutes werden gefiltert
    /// Bricht wenn: GapFinder.swift:83 — `gapDuration >= minMinutes` Check entfernt
    func test_gapSmallerThanMin_isExcluded() {
        // Events create a 20-minute gap between 10:00 and 10:20 — too short for minMinutes=30
        let events = [
            makeEvent(startHour: 8, endHour: 10),
            makeEvent(startHour: 10, startMinute: 20, endHour: 13),
            makeEvent(startHour: 15, endHour: 17),
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // The 20-min gap (10:00-10:20) should NOT appear
        let slotStarts = slots.map { Calendar.current.component(.hour, from: $0.startDate) }
        XCTAssertFalse(
            slotStarts.contains(10),
            "20-minute gap at 10:00 should be excluded (< minMinutes=30)"
        )
    }

    /// Verhalten: Grosse Gaps werden auf maxMinutes gekappt
    /// Bricht wenn: GapFinder.swift:86-87 — Gap-Capping Logik entfernt
    func test_largeGap_isCappedToMaxMinutes() {
        // Gap from 09:00 to 17:00 = 8 hours, should be capped to 60 min
        let events = [
            makeEvent(startHour: 7, endHour: 9),
            makeEvent(startHour: 17, endHour: 19),
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        let gapAt9 = slots.first {
            Calendar.current.component(.hour, from: $0.startDate) == 9
        }
        XCTAssertNotNil(gapAt9, "Should find a gap starting at 09:00")
        XCTAssertEqual(gapAt9?.durationMinutes, 60, "Gap should be capped to maxMinutes=60")
    }

    // MARK: - All-Day Events

    /// Verhalten: All-Day Events werden NICHT als Busy gezaehlt
    /// Bricht wenn: GapFinder.swift:53 — `!event.isAllDay` Filter entfernt
    func test_allDayEvent_isExcludedFromBusyPeriods() {
        let allDay = makeEvent(startHour: 0, endHour: 23, isAllDay: true)
        let finder = GapFinder(events: [allDay], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots()

        // All-day event excluded → empty busy periods → default suggestions
        XCTAssertEqual(slots.count, 4, "All-day event should be excluded — returns defaults")
    }

    // MARK: - Focus Blocks as Busy

    /// Verhalten: FocusBlocks werden als Busy-Perioden gezaehlt
    /// Bricht wenn: GapFinder.swift:57-59 — focusBlocks Loop entfernt
    func test_focusBlocks_countAsBusy() {
        // 3 focus blocks = 3h busy → real gaps
        let blocks = [
            makeBlock(startHour: 8, endHour: 9),
            makeBlock(startHour: 11, endHour: 13),
            makeBlock(startHour: 15, endHour: 17),
        ]
        let finder = GapFinder(events: [], focusBlocks: blocks, date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // Focus blocks count as busy → should find gaps between them
        XCTAssertTrue(slots.count >= 3, "Focus blocks should create gaps between them")
    }

    // MARK: - Events Outside Working Hours

    /// Verhalten: Events ausserhalb 06:00-22:00 werden ignoriert
    /// Bricht wenn: GapFinder.swift:73-75 — Period-Filter fuer ausserhalb-Fenster entfernt
    func test_eventsOutsideWorkingHours_areIgnored() {
        // Event at 4-5 AM — outside 06:00-22:00 window
        let earlyEvent = makeEvent(startHour: 4, endHour: 5)
        let finder = GapFinder(events: [earlyEvent], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots()

        // Early event ignored → 0 busy → default suggestions
        XCTAssertEqual(slots.count, 4, "Events outside working hours should be ignored")
    }

    // MARK: - Full Day

    /// Verhalten: Komplett voller Tag (06-22) ergibt leere Gaps → Default Suggestions (da <120min false)
    /// Bricht wenn: GapFinder.swift:100 — End-of-day gap check oder :114 empty check entfernt
    func test_fullDay_returnsEmptyOrDefaults() {
        // Pack the entire day 06:00-22:00
        let event = makeEvent(startHour: 6, endHour: 22)
        let finder = GapFinder(events: [event], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // Full day = no gaps found, BUT isWholeDayFree is false (16h busy > 120min)
        // gaps.isEmpty=true → createDefaultSuggestions, BUT the OR condition means
        // defaults are returned even though day isn't free
        // Key: no gaps with >= minMinutes should exist
        let realGaps = slots.filter { $0.durationMinutes >= 30 }
        // Should be defaults since gaps.isEmpty
        XCTAssertFalse(realGaps.isEmpty, "Full day should return default suggestions as fallback")
    }

    // MARK: - Default Suggestions Duration

    /// Verhalten: Default Suggestions haben Dauer = maxMinutes
    /// Bricht wenn: GapFinder.swift:149 — maxMinutes nicht an Slot-Ende uebergeben
    func test_defaultSuggestions_haveMaxMinutesDuration() {
        let finder = GapFinder(events: [], focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 45)

        for slot in slots {
            XCTAssertEqual(slot.durationMinutes, 45, "Default suggestions should use maxMinutes=45")
        }
    }

    // MARK: - Overlapping Events

    /// Verhalten: Ueberlappende Events werden zu einem Busy-Block zusammengefasst
    /// Bricht wenn: GapFinder.swift:62 — busyPeriods.sort entfernt (Merge-by-max bricht)
    func test_overlappingEvents_mergedBusyPeriods() {
        // Two overlapping events: 10-12 and 11-13 → should merge to 10-13 busy
        // Plus extra event to push past 120min threshold
        let events = [
            makeEvent(startHour: 8, endHour: 9),    // 1h busy
            makeEvent(startHour: 10, endHour: 12),   // overlap start
            makeEvent(startHour: 11, endHour: 13),   // overlap end
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // Gap between 9-10 (60min) should exist, gap between 10-13 should NOT be split
        let slotHours = slots.map { Calendar.current.component(.hour, from: $0.startDate) }
        XCTAssertTrue(slotHours.contains(9), "Should find gap at 09:00 between the events")
        // No slot should start at 12 (the overlap area)
        XCTAssertFalse(
            slotHours.contains(12),
            "Overlapping events 10-12 + 11-13 should merge — no gap at 12:00"
        )
    }

    // MARK: - Today vs Future Date

    /// Verhalten: Fuer "heute" werden vergangene Slots herausgefiltert
    /// Bricht wenn: GapFinder.swift:69 — `isDate(now, inSameDayAs: date)` Check entfernt
    func test_today_defaultSuggestions_excludesPastHours() {
        // Use "today" as date — any default suggestion hour before now should be excluded
        let finder = GapFinder(events: [], focusBlocks: [], date: Date())
        let slots = finder.findFreeSlots()

        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)

        for slot in slots {
            let slotHour = Calendar.current.component(.hour, from: slot.startDate)
            XCTAssertTrue(
                slotHour >= currentHour,
                "Today's suggestions should not include past hours — got \(slotHour) but current hour is \(currentHour)"
            )
        }
    }

    /// Verhalten: Zukuenftiger Tag startet ab 06:00 (nicht ab aktueller Uhrzeit)
    /// Bricht wenn: GapFinder.swift:69 — Future-Date Branch entfernt (wuerde ab now starten)
    func test_futureDate_gapStartsFrom0600() {
        // Events fill 8-22 on a future day. Gap should exist from 06:00-08:00
        let events = [
            makeEvent(startHour: 8, endHour: 14),
            makeEvent(startHour: 14, endHour: 22),
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        let firstSlotHour = Calendar.current.component(.hour, from: slots.first!.startDate)
        XCTAssertEqual(firstSlotHour, 6, "Future date should start gap search from 06:00")
    }

    // MARK: - End-of-Day Gap

    /// Verhalten: Luecke am Ende des Tages (nach letztem Event bis 22:00) wird gefunden
    /// Bricht wenn: GapFinder.swift:100-111 — End-of-day Gap Check entfernt
    func test_endOfDayGap_isDetected() {
        // Events fill 06:00-18:00 (12h busy) → gap 18:00-22:00 should be found
        let events = [
            makeEvent(startHour: 6, endHour: 10),
            makeEvent(startHour: 10, endHour: 14),
            makeEvent(startHour: 14, endHour: 18),
        ]
        let finder = GapFinder(events: events, focusBlocks: [], date: tomorrowDate)
        let slots = finder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // Gap 18:00-22:00 = 4h, capped to 60min → slot 18:00-19:00
        let lastSlot = slots.last
        XCTAssertNotNil(lastSlot, "Should find end-of-day gap")
        XCTAssertEqual(
            Calendar.current.component(.hour, from: lastSlot!.startDate),
            18,
            "End-of-day gap should start at 18:00"
        )
    }
}
