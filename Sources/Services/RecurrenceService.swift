import Foundation
import SwiftData

/// Handles recurring task instance generation when a task is completed.
/// Stateless enum - all methods are static.
enum RecurrenceService {

    /// Calculates the next due date based on recurrence pattern.
    /// - Parameters:
    ///   - pattern: Recurrence pattern string (none/daily/weekly/biweekly/monthly/custom)
    ///   - weekdays: Selected weekdays for weekly/biweekly (1=Mon...7=Sun)
    ///   - monthDay: Day of month for monthly (1-31, 32=last day)
    ///   - interval: Custom interval multiplier (nil or 1 = default). E.g. 3 = "every 3 days"
    ///   - baseDate: Starting date (typically the completed task's dueDate or today)
    /// - Returns: Next due date, or nil if pattern is "none"
    static func nextDueDate(
        pattern: String,
        weekdays: [Int]?,
        monthDay: Int?,
        interval: Int? = nil,
        from baseDate: Date
    ) -> Date? {
        let cal = Calendar.current
        let n = max(interval ?? 1, 1)

        switch pattern {
        case "daily":
            return cal.date(byAdding: .day, value: n, to: baseDate)

        case "weekdays":
            return nextWeekdayDate(from: baseDate, weekdays: [1, 2, 3, 4, 5], weeksToAdd: 0)

        case "weekends":
            return nextWeekdayDate(from: baseDate, weekdays: [6, 7], weeksToAdd: 0)

        case "weekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: n - 1)
                ?? cal.date(byAdding: .day, value: 7 * n, to: baseDate)

        case "biweekly":
            return nextWeekdayDate(from: baseDate, weekdays: weekdays, weeksToAdd: 1)
                ?? cal.date(byAdding: .day, value: 14, to: baseDate)

        case "monthly":
            return nextMonthlyDate(from: baseDate, monthDay: monthDay, monthsToAdd: n)

        case "quarterly":
            return cal.date(byAdding: .month, value: 3, to: baseDate)

        case "semiannually":
            return cal.date(byAdding: .month, value: 6, to: baseDate)

        case "yearly":
            return cal.date(byAdding: .year, value: n, to: baseDate)

        case "custom":
            // Custom pattern stores base frequency in monthDay: 1001=daily, 1002=weekly, 1003=monthly, 1004=yearly
            let basePattern: String
            switch monthDay {
            case 1001: basePattern = "daily"
            case 1002: basePattern = "weekly"
            case 1003: basePattern = "monthly"
            case 1004: basePattern = "yearly"
            default: basePattern = "daily"
            }
            return nextDueDate(pattern: basePattern, weekdays: weekdays, monthDay: nil, interval: interval, from: baseDate)

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
            interval: completedTask.recurrenceInterval,
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

        // Dedup: check if an open instance for this series already exists with the same due date
        if let newDueDate {
            let cal = Calendar.current
            let targetDay = cal.startOfDay(for: newDueDate)
            let descriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate<LocalTask> {
                    $0.recurrenceGroupID == groupID && !$0.isCompleted
                }
            )
            if let openSiblings = try? modelContext.fetch(descriptor),
               openSiblings.contains(where: { task in
                   guard let due = task.dueDate else { return false }
                   return cal.startOfDay(for: due) == targetDay
               }) {
                return nil  // Duplicate - already have an open instance for this date
            }
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
            recurrenceInterval: completedTask.recurrenceInterval,
            recurrenceGroupID: groupID,
            taskDescription: completedTask.taskDescription
        )

        modelContext.insert(instance)
        return instance
    }

    // MARK: - Repair Orphaned Series

    /// Finds completed recurring tasks whose series has no open successor,
    /// and creates the missing next instance for each.
    /// Returns the number of repaired series.
    @MainActor
    @discardableResult
    static func repairOrphanedRecurringSeries(in modelContext: ModelContext) -> Int {
        // 1. Fetch all completed recurring tasks
        let completedDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isCompleted }
        )
        guard let completedTasks = try? modelContext.fetch(completedDescriptor) else { return 0 }

        let recurringCompleted = completedTasks.filter { $0.recurrencePattern != "none" }
        guard !recurringCompleted.isEmpty else { return 0 }

        // 2. Fetch all open tasks to find existing successors
        let openDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted }
        )
        let openTasks = (try? modelContext.fetch(openDescriptor)) ?? []

        var openGroupIDs = Set<String>()
        for task in openTasks {
            if let gid = task.recurrenceGroupID { openGroupIDs.insert(gid) }
        }

        // 3. For each orphaned series, create successor from most recent completion
        var seenGroupIDs = Set<String>()
        var repaired = 0

        let sorted = recurringCompleted.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }

        for task in sorted {
            let groupID = task.recurrenceGroupID ?? task.id
            guard !seenGroupIDs.contains(groupID) else { continue }
            seenGroupIDs.insert(groupID)

            guard !openGroupIDs.contains(groupID) else { continue }

            if let _ = createNextInstance(from: task, in: modelContext) {
                repaired += 1
            }
        }

        if repaired > 0 { try? modelContext.save() }
        return repaired
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
    private static func nextMonthlyDate(from baseDate: Date, monthDay: Int?, monthsToAdd: Int = 1) -> Date? {
        let cal = Calendar.current
        guard let advancedDate = cal.date(byAdding: .month, value: monthsToAdd, to: baseDate) else {
            return nil
        }
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: advancedDate)

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
