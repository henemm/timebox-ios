import XCTest
@testable import FocusBlox

/// Tests for Bug 14: Focus Block duration display showing "25 Std" instead of minutes
/// Root Cause: DatePicker wraps endTime to next day when scrolling past midnight
final class FocusBlockDurationTests: XCTestCase {

    // MARK: - normalizeEndTime Tests

    /// GIVEN: start 10:00, end 11:30 (same day)
    /// WHEN: normalizeEndTime is called
    /// THEN: endTime is unchanged (same day, no wrap)
    func testNormalizeEndTimeSameDayUnchanged() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let end = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: today)!

        let normalized = FocusBlock.normalizeEndTime(startTime: start, endTime: end)

        let minutes = Int(normalized.timeIntervalSince(start) / 60)
        XCTAssertEqual(minutes, 90, "Same-day times should produce 90 min duration")
    }

    /// GIVEN: start 23:00 today, end 00:25 TOMORROW (DatePicker midnight wrap)
    /// WHEN: normalizeEndTime is called
    /// THEN: endTime is normalized to 00:25 TODAY (same calendar day as start)
    func testNormalizeEndTimeMidnightWrapFixesDuration() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let start = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)!
        let end = calendar.date(bySettingHour: 0, minute: 25, second: 0, of: tomorrow)!

        // Without fix: timeIntervalSince would be ~25 hours
        let unfixedMinutes = Int(end.timeIntervalSince(start) / 60)
        XCTAssertGreaterThan(unfixedMinutes, 60, "Unfixed should show hours (proving bug exists)")

        let normalized = FocusBlock.normalizeEndTime(startTime: start, endTime: end)
        let fixedMinutes = Int(normalized.timeIntervalSince(start) / 60)

        // After fix: should be 85 minutes (23:00 to 00:25 = 1h 25min)
        XCTAssertEqual(fixedMinutes, 85, "Normalized midnight wrap should be 85 min")
    }

    /// GIVEN: start 22:00, end 22:30 but next day (DatePicker random day shift)
    /// WHEN: normalizeEndTime is called
    /// THEN: endTime hour/minute preserved on startTime's day
    func testNormalizeEndTimeDayShiftFixesDuration() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let start = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today)!
        let end = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: tomorrow)!

        // Without fix: would be ~24.5 hours
        let unfixedMinutes = Int(end.timeIntervalSince(start) / 60)
        XCTAssertGreaterThan(unfixedMinutes, 1000, "Unfixed should show 24+ hours")

        let normalized = FocusBlock.normalizeEndTime(startTime: start, endTime: end)
        let fixedMinutes = Int(normalized.timeIntervalSince(start) / 60)

        XCTAssertEqual(fixedMinutes, 30, "Normalized should be 30 min")
    }

    /// GIVEN: start and end on same day, end before start (invalid)
    /// WHEN: normalizeEndTime is called
    /// THEN: Returns endTime as-is (UI disables save button for this case)
    func testNormalizeEndTimeBeforeStartUnchanged() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
        let end = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today)!

        let normalized = FocusBlock.normalizeEndTime(startTime: start, endTime: end)

        // Should stay as-is (negative duration) - UI already blocks save
        let components = calendar.dateComponents([.hour, .minute], from: normalized)
        XCTAssertEqual(components.hour, 13)
        XCTAssertEqual(components.minute, 0)
    }
}
