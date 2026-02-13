import Foundation

/// Shared due-date formatting used by BacklogRow, MacBacklogRow, and TaskDetailSheet.
/// Replaces 3 identical private dueDateText/dueDateFormatted functions (BACKLOG-010).
extension Date {

    /// Display style for due-date text.
    enum DueDateStyle {
        /// Abbreviated weekday (EEE) + short date — used in compact rows (BacklogRow, MacBacklogRow)
        case compact
        /// Full weekday (EEEE) + medium date — used in detail views (TaskDetailSheet)
        case full
    }

    /// Formats a due date relative to today.
    /// - Returns: "Heute", "Morgen", weekday name, or formatted date string.
    func dueDateText(style: DueDateStyle = .compact) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Heute"
        } else if calendar.isDateInTomorrow(self) {
            return "Morgen"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = style == .compact ? "EEE" : "EEEE"
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = style == .compact ? .short : .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: self)
        }
    }

    /// Whether this date is today. Replaces 3 identical `isDueToday(_:)` helper functions.
    var isDueToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
