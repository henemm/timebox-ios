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

    /// Formats a due date relative to today, including time if set (not midnight).
    /// - Returns: "Heute, 14:30", "Morgen", weekday name, or formatted date string.
    func dueDateText(style: DueDateStyle = .compact) -> String {
        let calendar = Calendar.current
        let timeSuffix = dueDateTimeSuffix

        if calendar.isDateInToday(self) {
            return "Heute" + timeSuffix
        } else if calendar.isDateInTomorrow(self) {
            return "Morgen" + timeSuffix
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = style == .compact ? "EEE" : "EEEE"
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: self) + timeSuffix
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = style == .compact ? .short : .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "de_DE")
            return formatter.string(from: self) + timeSuffix
        }
    }

    /// Returns ", HH:mm" if time is not midnight (00:00), otherwise empty string.
    /// Midnight is treated as "no time set".
    private var dueDateTimeSuffix: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        guard hour != 0 || minute != 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return ", " + formatter.string(from: self)
    }

    /// Whether this date is today. Replaces 3 identical `isDueToday(_:)` helper functions.
    var isDueToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
