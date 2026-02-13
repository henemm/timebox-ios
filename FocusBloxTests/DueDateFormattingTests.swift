import Testing
import Foundation
@testable import FocusBlox

/// Regression tests for Date.dueDateText (BACKLOG-010).
/// Verifies that the shared extension returns the same values as the
/// previously hardcoded dueDateText/dueDateFormatted in 3 view files.
struct DueDateFormattingTests {

    // MARK: - Compact Style (BacklogRow / MacBacklogRow behavior)

    @Test func compact_today_returnsHeute() {
        let today = Date()
        #expect(today.dueDateText(style: .compact) == "Heute")
    }

    @Test func compact_tomorrow_returnsMorgen() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.dueDateText(style: .compact) == "Morgen")
    }

    @Test func compact_sameWeek_returnsAbbreviatedWeekday() {
        // Find a date that is in the same week but NOT today or tomorrow
        let calendar = Calendar.current
        let today = Date()
        // Go to 3 days from now — if still same week, test abbreviated weekday
        if let candidate = calendar.date(byAdding: .day, value: 3, to: today),
           calendar.isDate(candidate, equalTo: today, toGranularity: .weekOfYear) {
            let result = candidate.dueDateText(style: .compact)
            // Should be abbreviated German weekday (Mo, Di, Mi, Do, Fr, Sa, So)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "de_DE")
            let expected = formatter.string(from: candidate)
            #expect(result == expected)
        }
        // If 3 days crosses week boundary, skip — other tests cover the logic
    }

    @Test func compact_otherDate_returnsShortDate() {
        // A date far in the future (definitely not this week)
        let farDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let result = farDate.dueDateText(style: .compact)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        let expected = formatter.string(from: farDate)
        #expect(result == expected)
    }

    // MARK: - Full Style (TaskDetailSheet behavior)

    @Test func full_today_returnsHeute() {
        let today = Date()
        #expect(today.dueDateText(style: .full) == "Heute")
    }

    @Test func full_tomorrow_returnsMorgen() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.dueDateText(style: .full) == "Morgen")
    }

    @Test func full_sameWeek_returnsFullWeekday() {
        let calendar = Calendar.current
        let today = Date()
        if let candidate = calendar.date(byAdding: .day, value: 3, to: today),
           calendar.isDate(candidate, equalTo: today, toGranularity: .weekOfYear) {
            let result = candidate.dueDateText(style: .full)
            // Should be full German weekday (Montag, Dienstag, etc.)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "de_DE")
            let expected = formatter.string(from: candidate)
            #expect(result == expected)
        }
    }

    @Test func full_otherDate_returnsMediumDate() {
        let farDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let result = farDate.dueDateText(style: .full)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        let expected = formatter.string(from: farDate)
        #expect(result == expected)
    }

    // MARK: - isDueToday (identical in all 3 files)

    @Test func isDueToday_today_returnsTrue() {
        #expect(Date().isDueToday == true)
    }

    @Test func isDueToday_tomorrow_returnsFalse() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(tomorrow.isDueToday == false)
    }

    @Test func isDueToday_yesterday_returnsFalse() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.isDueToday == false)
    }

    // MARK: - Default style is compact

    @Test func defaultStyle_isCompact() {
        let today = Date()
        // No style parameter should default to compact
        #expect(today.dueDateText() == today.dueDateText(style: .compact))
    }
}
