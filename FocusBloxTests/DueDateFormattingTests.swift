import Testing
import Foundation
@testable import FocusBlox

/// Regression tests for Date.dueDateText (BACKLOG-010).
/// Verifies that the shared extension returns the same values as the
/// previously hardcoded dueDateText/dueDateFormatted in 3 view files.
/// Uses midnight dates (00:00) to test date-only formatting without time suffix.
struct DueDateFormattingTests {

    private let calendar = Calendar.current

    /// Helper: midnight of today
    private var todayMidnight: Date {
        calendar.startOfDay(for: Date())
    }

    /// Helper: midnight of tomorrow
    private var tomorrowMidnight: Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
    }

    // MARK: - Compact Style (BacklogRow / MacBacklogRow behavior)

    @Test func compact_today_returnsHeute() {
        #expect(todayMidnight.dueDateText(style: .compact) == "Heute")
    }

    @Test func compact_tomorrow_returnsMorgen() {
        #expect(tomorrowMidnight.dueDateText(style: .compact) == "Morgen")
    }

    @Test func compact_sameWeek_returnsAbbreviatedWeekday() {
        let today = Date()
        if let candidate = calendar.date(byAdding: .day, value: 3, to: today),
           calendar.isDate(candidate, equalTo: today, toGranularity: .weekOfYear) {
            let midnightCandidate = calendar.startOfDay(for: candidate)
            let result = midnightCandidate.dueDateText(style: .compact)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "de_DE")
            let expected = formatter.string(from: midnightCandidate)
            #expect(result == expected)
        }
    }

    @Test func compact_otherDate_returnsShortDate() {
        let farDate = calendar.date(byAdding: .month, value: 2, to: Date())!
        let midnightFar = calendar.startOfDay(for: farDate)
        let result = midnightFar.dueDateText(style: .compact)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        let expected = formatter.string(from: midnightFar)
        #expect(result == expected)
    }

    // MARK: - Full Style (TaskDetailSheet behavior)

    @Test func full_today_returnsHeute() {
        #expect(todayMidnight.dueDateText(style: .full) == "Heute")
    }

    @Test func full_tomorrow_returnsMorgen() {
        #expect(tomorrowMidnight.dueDateText(style: .full) == "Morgen")
    }

    @Test func full_sameWeek_returnsFullWeekday() {
        let today = Date()
        if let candidate = calendar.date(byAdding: .day, value: 3, to: today),
           calendar.isDate(candidate, equalTo: today, toGranularity: .weekOfYear) {
            let midnightCandidate = calendar.startOfDay(for: candidate)
            let result = midnightCandidate.dueDateText(style: .full)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "de_DE")
            let expected = formatter.string(from: midnightCandidate)
            #expect(result == expected)
        }
    }

    @Test func full_otherDate_returnsMediumDate() {
        let farDate = calendar.date(byAdding: .month, value: 2, to: Date())!
        let midnightFar = calendar.startOfDay(for: farDate)
        let result = midnightFar.dueDateText(style: .full)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        let expected = formatter.string(from: midnightFar)
        #expect(result == expected)
    }

    // MARK: - isDueToday (identical in all 3 files)

    @Test func isDueToday_today_returnsTrue() {
        #expect(Date().isDueToday == true)
    }

    @Test func isDueToday_tomorrow_returnsFalse() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.isDueToday == false)
    }

    @Test func isDueToday_yesterday_returnsFalse() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.isDueToday == false)
    }

    // MARK: - Default style is compact

    @Test func defaultStyle_isCompact() {
        // Use midnight to avoid time-dependent results
        #expect(todayMidnight.dueDateText() == todayMidnight.dueDateText(style: .compact))
    }
}
