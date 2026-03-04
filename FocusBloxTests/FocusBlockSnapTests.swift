import XCTest
@testable import FocusBlox

/// Tests for Bug 70a: 15-minute snapping for FocusBlock time selection
/// FocusBlock.snapToQuarterHour() rounds any Date to the nearest 15-minute boundary.
final class FocusBlockSnapTests: XCTestCase {

    private let calendar = Calendar.current

    private func makeTime(hour: Int, minute: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    // MARK: - Already on grid (no change expected)

    /// 09:00 → 09:00
    func testSnapExactHourUnchanged() {
        let time = makeTime(hour: 9, minute: 0)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    /// 09:15 → 09:15
    func testSnapQuarterPastUnchanged() {
        let time = makeTime(hour: 9, minute: 15)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 15)
    }

    /// 09:30 → 09:30
    func testSnapHalfPastUnchanged() {
        let time = makeTime(hour: 9, minute: 30)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
    }

    /// 09:45 → 09:45
    func testSnapThreeQuarterUnchanged() {
        let time = makeTime(hour: 9, minute: 45)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 45)
    }

    // MARK: - Round down (closer to lower boundary)

    /// 09:06 → 09:00 (6 min from :00, 9 min from :15 → round down)
    func testSnapRoundsDownWhenCloserToLower() {
        let time = makeTime(hour: 9, minute: 6)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    /// 09:22 → 09:15 (7 min from :15, 8 min from :30 → round down)
    func testSnapRoundsDownAt22() {
        let time = makeTime(hour: 9, minute: 22)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 15)
    }

    // MARK: - Round up (closer to upper boundary)

    /// 09:08 → 09:15 (8 min from :00, 7 min from :15 → round up)
    func testSnapRoundsUpWhenCloserToUpper() {
        let time = makeTime(hour: 9, minute: 8)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 15)
    }

    /// 09:13 → 09:15 (13 min from :00, 2 min from :15 → round up)
    func testSnapRoundsUpAt13() {
        let time = makeTime(hour: 9, minute: 13)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 15)
    }

    /// 09:38 → 09:45 (8 min from :30, 7 min from :45 → round up)
    func testSnapRoundsUpAt38() {
        let time = makeTime(hour: 9, minute: 38)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 45)
    }

    // MARK: - Exact midpoint (7.5 min → round up per convention)

    /// 09:07 → 09:00 (7 min from :00, 8 min from :15 → round down)
    func testSnapMidpointMinus1RoundsDown() {
        let time = makeTime(hour: 9, minute: 7)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    // MARK: - Hour boundary crossing

    /// 09:53 → 10:00 (8 min from :45, 7 min from :00 → round up to next hour)
    func testSnapRoundsUpAcrossHourBoundary() {
        let time = makeTime(hour: 9, minute: 53)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 0)
    }

    /// 23:53 → 00:00 next day (round up across midnight)
    func testSnapRoundsUpAcrossMidnight() {
        let time = makeTime(hour: 23, minute: 53)
        let snapped = FocusBlock.snapToQuarterHour(time)
        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
    }

    // MARK: - Preserves date (only changes minute component)

    /// Snapping preserves the calendar date (year, month, day)
    func testSnapPreservesDate() {
        let time = makeTime(hour: 14, minute: 22)
        let snapped = FocusBlock.snapToQuarterHour(time)

        let originalDay = calendar.dateComponents([.year, .month, .day], from: time)
        let snappedDay = calendar.dateComponents([.year, .month, .day], from: snapped)

        XCTAssertEqual(originalDay.year, snappedDay.year)
        XCTAssertEqual(originalDay.month, snappedDay.month)
        XCTAssertEqual(originalDay.day, snappedDay.day)
    }

    // MARK: - Idempotent

    /// Snapping an already-snapped time returns the same time
    func testSnapIsIdempotent() {
        let time = makeTime(hour: 10, minute: 30)
        let snapped1 = FocusBlock.snapToQuarterHour(time)
        let snapped2 = FocusBlock.snapToQuarterHour(snapped1)
        XCTAssertEqual(snapped1, snapped2, "Snapping should be idempotent")
    }
}
