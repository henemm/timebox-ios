import XCTest
@testable import FocusBlox

/// Tests for Bug 70c-2: FocusBlock Resize per Drag am unteren Rand.
/// Tests the pure resize logic: snapped end date calculation, minimum duration enforcement.
///
/// TDD RED: These tests FAIL because FocusBlock.resizedEndDate() and
/// FocusBlock.minDurationMinutes do not exist yet.
final class FocusBlockResizeTests: XCTestCase {

    private let calendar = Calendar.current

    private func makeBlock(hour: Int = 10, durationMinutes: Int = 60) -> FocusBlock {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .hour, value: hour, to: today)!
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start)!
        return FocusBlock(id: "block-1", title: "Test", startDate: start, endDate: end)
    }

    // MARK: - Minimum Duration Constant

    /// Verhalten: FocusBlock hat eine Minimum-Dauer Konstante von 15 Minuten
    /// Bricht wenn: minDurationMinutes fehlt oder != 15
    func testMinDurationMinutes_is15() {
        XCTAssertEqual(FocusBlock.minDurationMinutes, 15)
    }

    // MARK: - resizedEndDate()

    /// Verhalten: Drag um +30px (= +30 Min bei 60pt/h) verlaengert Block um 30 Min
    /// Bricht wenn: resizedEndDate() fehlt oder berechnet falsch
    func testResize_dragDown30px_extends30Minutes() {
        let block = makeBlock(hour: 10, durationMinutes: 60)
        // 60pt/h = 1pt/min, drag 30px down = +30 minutes
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: 30,
            hourHeight: 60
        )
        let expectedEnd = calendar.date(byAdding: .minute, value: 90, to: block.startDate)!
        XCTAssertEqual(
            calendar.component(.minute, from: newEnd),
            calendar.component(.minute, from: expectedEnd),
            "Dragging 30px down should extend block to 90 minutes (snapped to 30 min)"
        )
    }

    /// Verhalten: Drag um -30px (= -30 Min) verkuerzt Block um 30 Min
    /// Bricht wenn: Negative Offsets nicht korrekt verarbeitet werden
    func testResize_dragUp30px_shortens30Minutes() {
        let block = makeBlock(hour: 10, durationMinutes: 60)
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: -30,
            hourHeight: 60
        )
        let expectedEnd = calendar.date(byAdding: .minute, value: 30, to: block.startDate)!
        XCTAssertEqual(
            calendar.component(.minute, from: newEnd),
            calendar.component(.minute, from: expectedEnd),
            "Dragging 30px up should shorten block to 30 minutes"
        )
    }

    /// Verhalten: Drag-Ergebnis wird auf 15-Min-Grenzen gerundet
    /// Bricht wenn: Snapping fehlt
    func testResize_snapsTo15MinBoundaries() {
        let block = makeBlock(hour: 10, durationMinutes: 60)
        // Drag 22px = 22 min → snapped: 60+22=82 → snapped to 75 or 90
        // 82 → nearest 15: (82+7)/15*15 = 89/15*15 = 5*15 = 75 → 75 min
        // Wait: snap applies to the END TIME, not duration.
        // originalEnd = 11:00, +22min = 11:22 → snapped to 11:15 (nearest quarter)
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: 22,
            hourHeight: 60
        )
        let minute = calendar.component(.minute, from: newEnd)
        XCTAssertTrue(
            minute % 15 == 0,
            "End time must be snapped to 15-minute boundary, got minute=\(minute)"
        )
    }

    /// Verhalten: Minimum-Dauer von 15 Minuten wird erzwungen
    /// Bricht wenn: Block kann auf < 15 Min verkuerzt werden
    func testResize_enforces15MinMinimum() {
        let block = makeBlock(hour: 10, durationMinutes: 30)
        // Try to drag up by 20 min → would result in 10 min duration
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: -20,
            hourHeight: 60
        )
        let durationMinutes = Int(newEnd.timeIntervalSince(block.startDate) / 60)
        XCTAssertGreaterThanOrEqual(
            durationMinutes, FocusBlock.minDurationMinutes,
            "Duration must not go below \(FocusBlock.minDurationMinutes) minutes"
        )
    }

    /// Verhalten: Extreme negative Drags clippen auf Minimum
    /// Bricht wenn: Kein Clamp bei extremem Drag nach oben
    func testResize_extremeNegativeDrag_clipsToMinimum() {
        let block = makeBlock(hour: 10, durationMinutes: 60)
        // Drag -120px (2 hours up) on a 60-min block → should clamp to 15 min
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: -120,
            hourHeight: 60
        )
        let durationMinutes = Int(newEnd.timeIntervalSince(block.startDate) / 60)
        XCTAssertEqual(durationMinutes, FocusBlock.minDurationMinutes,
                       "Extreme negative drag must clamp to minimum duration")
    }

    /// Verhalten: Drag um 0px aendert nichts
    /// Bricht wenn: Zero-Drag veraendert End-Time
    func testResize_zeroDrag_noChange() {
        let block = makeBlock(hour: 10, durationMinutes: 60)
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: 0,
            hourHeight: 60
        )
        XCTAssertEqual(
            calendar.component(.hour, from: newEnd),
            calendar.component(.hour, from: block.endDate)
        )
        XCTAssertEqual(
            calendar.component(.minute, from: newEnd),
            calendar.component(.minute, from: block.endDate)
        )
    }

    /// Verhalten: Ergebnis-EndDate liegt immer nach StartDate
    /// Bricht wenn: EndDate kann vor StartDate liegen
    func testResize_endDateAlwaysAfterStartDate() {
        let block = makeBlock(hour: 10, durationMinutes: 15)
        // Try to drag block smaller than start
        let newEnd = FocusBlock.resizedEndDate(
            startDate: block.startDate,
            originalEndDate: block.endDate,
            dragOffsetY: -60,
            hourHeight: 60
        )
        XCTAssertTrue(newEnd > block.startDate, "End date must always be after start date")
    }
}
