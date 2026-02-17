import Foundation
import SwiftData

/// Handles recurring task instance generation when a task is completed.
/// Stateless enum - all methods are static.
enum RecurrenceService {

    /// Calculates the next due date based on recurrence pattern.
    /// - Parameters:
    ///   - pattern: Recurrence pattern string (none/daily/weekly/biweekly/monthly)
    ///   - weekdays: Selected weekdays for weekly/biweekly (1=Mon...7=Sun)
    ///   - monthDay: Day of month for monthly (1-31, 32=last day)
    ///   - baseDate: Starting date (typically the completed task's dueDate or today)
    /// - Returns: Next due date, or nil if pattern is "none"
    static func nextDueDate(
        pattern: String,
        weekdays: [Int]?,
        monthDay: Int?,
        from baseDate: Date
    ) -> Date? {
        let cal = Calendar.current

        switch pattern {
        case "daily":
            return cal.date(byAdding: .day, value: 1, to: baseDate)

        case "weekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: 0)
                ?? cal.date(byAdding: .day, value: 7, to: baseDate)

        case "biweekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: 1)
                ?? cal.date(byAdding: .day, value: 14, to: baseDate)

        case "monthly":
            return nextMonthlyDate(from: baseDate, monthDay: monthDay)

        default:
            return nil
        }
    }

    /// Creates a new task instance copying attributes from the completed task.
    /// Returns nil if the task is not recurring (pattern == "none").
    @MainActor
    @discardableResult
    static func createNextInstance(
        from completedTask: LocalTask,
        in modelContext: ModelContext
    ) -> LocalTask? {
        guard completedTask.recurrencePattern != "none" else { return nil }

        let baseDate = completedTask.dueDate ?? Date()
        let newDueDate = nextDueDate(
            pattern: completedTask.recurrencePattern,
            weekdays: completedTask.recurrenceWeekdays,
            monthDay: completedTask.recurrenceMonthDay,
            from: baseDate
        )

        // Lazy migration: generate GroupID if nil (legacy task)
        let groupID: String
        if let existingGroupID = completedTask.recurrenceGroupID {
            groupID = existingGroupID
        } else {
            groupID = UUID().uuidString
            completedTask.recurrenceGroupID = groupID
        }

        let instance = LocalTask(
            title: completedTask.title,
            importance: completedTask.importance,
            tags: completedTask.tags,
            dueDate: newDueDate,
            estimatedDuration: completedTask.estimatedDuration,
            urgency: completedTask.urgency,
            taskType: completedTask.taskType,
            recurrencePattern: completedTask.recurrencePattern,
            recurrenceWeekdays: completedTask.recurrenceWeekdays,
            recurrenceMonthDay: completedTask.recurrenceMonthDay,
            recurrenceGroupID: groupID,
            taskDescription: completedTask.taskDescription
        )

        modelContext.insert(instance)
        return instance
    }

    // MARK: - Private Helpers

    /// Finds the next matching weekday after baseDate.
    /// weeksToAdd: 0 for weekly, 1 for biweekly (adds extra week)
    private static func nextWeekdayDate(from baseDate: Date, weekdays: [Int]?, weeksToAdd: Int) -> Date? {
        guard let weekdays = weekdays, !weekdays.isEmpty else { return nil }

        let cal = Calendar.current
        // Convert our 1=Mon...7=Sun to Calendar weekday (1=Sun, 2=Mon...7=Sat)
        let currentCalWeekday = cal.component(.weekday, from: baseDate)
        // Our system: 1=Mon, 2=Tue, ..., 7=Sun
        // Calendar:   2=Mon, 3=Tue, ..., 7=Sat, 1=Sun
        let currentOurWeekday = currentCalWeekday == 1 ? 7 : currentCalWeekday - 1

        let sorted = weekdays.sorted()

        // First try: find a later day this week
        if let nextDay = sorted.first(where: { $0 > currentOurWeekday }) {
            let daysAhead = nextDay - currentOurWeekday + (weeksToAdd * 7)
            return cal.date(byAdding: .day, value: daysAhead, to: baseDate)
        }

        // Wrap around: first day of next cycle
        if let firstDay = sorted.first {
            let daysAhead = (7 - currentOurWeekday) + firstDay + (weeksToAdd * 7)
            return cal.date(byAdding: .day, value: daysAhead, to: baseDate)
        }

        return nil
    }

    /// Calculates the next monthly date.
    private static func nextMonthlyDate(from baseDate: Date, monthDay: Int?) -> Date? {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: baseDate)

        // Move to next month
        if let month = components.month {
            if month == 12 {
                components.month = 1
                components.year = (components.year ?? 2026) + 1
            } else {
                components.month = month + 1
            }
        }

        if let day = monthDay {
            if day == 32 {
                // Last day of month
                components.day = 1
                if let firstOfMonth = cal.date(from: components),
                   let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) {
                    return endOfMonth
                }
            } else {
                // Specific day, clamped to month length
                components.day = 1
                if let firstOfMonth = cal.date(from: components),
                   let range = cal.range(of: .day, in: .month, for: firstOfMonth) {
                    components.day = min(day, range.count)
                }
            }
        }

        return cal.date(from: components)
    }
}
