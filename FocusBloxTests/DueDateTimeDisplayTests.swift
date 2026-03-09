import Testing
import Foundation
@testable import FocusBlox

/// Bug 85-A: Verify that dueDateText() includes time when set (not midnight).
/// Tests should FAIL before implementation (TDD RED).
struct DueDateTimeDisplayTests {

    private let calendar = Calendar.current

    /// Helper: Create a date for today at a specific hour:minute
    private func todayAt(hour: Int, minute: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    /// Helper: Create a date for tomorrow at a specific hour:minute
    private func tomorrowAt(hour: Int, minute: Int) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let start = calendar.startOfDay(for: tomorrow)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
    }

    /// Helper: Create a date far in the future at a specific hour:minute
    private func farDateAt(hour: Int, minute: Int) -> Date {
        let farDate = calendar.date(byAdding: .month, value: 2, to: Date())!
        let start = calendar.startOfDay(for: farDate)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)!
    }

    // MARK: - Today with time

    @Test func today_withTime_includesTime() {
        let date = todayAt(hour: 14, minute: 30)
        let result = date.dueDateText()
        #expect(result.contains("14:30"), "Bug 85-A: 'Heute' must include time when set")
        #expect(result.hasPrefix("Heute"), "Should still start with 'Heute'")
    }

    @Test func today_atMidnight_noTime() {
        let date = todayAt(hour: 0, minute: 0)
        let result = date.dueDateText()
        #expect(result == "Heute", "Midnight means no time set — just 'Heute'")
    }

    // MARK: - Tomorrow with time

    @Test func tomorrow_withTime_includesTime() {
        let date = tomorrowAt(hour: 9, minute: 0)
        let result = date.dueDateText()
        #expect(result.contains("09:00"), "Bug 85-A: 'Morgen' must include time when set")
        #expect(result.hasPrefix("Morgen"), "Should still start with 'Morgen'")
    }

    @Test func tomorrow_atMidnight_noTime() {
        let date = tomorrowAt(hour: 0, minute: 0)
        let result = date.dueDateText()
        #expect(result == "Morgen", "Midnight means no time set — just 'Morgen'")
    }

    // MARK: - Far date with time

    @Test func farDate_withTime_includesTime() {
        let date = farDateAt(hour: 16, minute: 45)
        let result = date.dueDateText()
        #expect(result.contains("16:45"), "Bug 85-A: Far date must include time when set")
    }

    @Test func farDate_atMidnight_noTime() {
        let date = farDateAt(hour: 0, minute: 0)
        let result = date.dueDateText()
        #expect(!result.contains("00:00"), "Midnight should NOT show time")
    }

    // MARK: - Full style with time

    @Test func full_today_withTime_includesTime() {
        let date = todayAt(hour: 10, minute: 15)
        let result = date.dueDateText(style: .full)
        #expect(result.contains("10:15"), "Bug 85-A: Full style 'Heute' must include time")
        #expect(result.hasPrefix("Heute"))
    }

    @Test func full_farDate_withTime_includesTime() {
        let date = farDateAt(hour: 8, minute: 0)
        let result = date.dueDateText(style: .full)
        #expect(result.contains("08:00"), "Bug 85-A: Full style far date must include time")
    }

    // MARK: - Format consistency

    @Test func timeFormat_isHHmm() {
        let date = todayAt(hour: 9, minute: 5)
        let result = date.dueDateText()
        // Should use HH:mm format (zero-padded)
        #expect(result.contains("09:05"), "Time should be zero-padded HH:mm")
    }

    @Test func timeSeparator_isCommaSpace() {
        let date = todayAt(hour: 14, minute: 30)
        let result = date.dueDateText()
        #expect(result.contains(", 14:30"), "Time should be separated by ', '")
    }
}
