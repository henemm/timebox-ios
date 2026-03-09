import Foundation

/// A Focus Block represents a time slot for focused work with assigned tasks
struct FocusBlock: Identifiable, Sendable {
    let id: String              // Calendar Event ID
    let title: String
    let startDate: Date
    let endDate: Date
    var taskIDs: [String]       // Ordered list of assigned task IDs
    var completedTaskIDs: [String]
    var taskTimes: [String: Int] // Task ID -> seconds spent (actual time tracking)

    /// Check if block is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    /// Check if block is in the past
    var isPast: Bool {
        Date() >= endDate
    }

    /// Check if block is in the future
    var isFuture: Bool {
        Date() < startDate
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Create from CalendarEvent if it's a focus block
    init?(from event: CalendarEvent) {
        guard event.isFocusBlock else { return nil }

        self.id = event.id
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.taskIDs = event.focusBlockTaskIDs
        self.completedTaskIDs = event.focusBlockCompletedIDs
        self.taskTimes = event.focusBlockTaskTimes
    }

    /// Create a new focus block
    init(id: String, title: String, startDate: Date, endDate: Date, taskIDs: [String] = [], completedTaskIDs: [String] = [], taskTimes: [String: Int] = [:]) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.taskIDs = taskIDs
        self.completedTaskIDs = completedTaskIDs
        self.taskTimes = taskTimes
    }
}

// MARK: - Resolved Task Counts (Bug 83)

extension FocusBlock {
    /// Count of taskIDs that actually exist in the provided known set.
    /// Prevents orphan IDs (deleted tasks) from inflating the total count.
    func resolvedTaskCount(knownTaskIDs: Set<String>) -> Int {
        taskIDs.filter { knownTaskIDs.contains($0) }.count
    }

    /// Count of completed tasks that both exist AND are in taskIDs.
    func resolvedCompletedCount(knownTaskIDs: Set<String>) -> Int {
        taskIDs.filter { knownTaskIDs.contains($0) && completedTaskIDs.contains($0) }.count
    }
}

// MARK: - Formatting

extension FocusBlock {
    /// Formatted time range string, e.g. "09:00 - 10:30"
    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    /// Generate the default block title from a start time, e.g. "FocusBlox 09:00"
    static func generateTitle(for startDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "FocusBlox \(formatter.string(from: startDate))"
    }
}

// MARK: - Resize

extension FocusBlock {
    /// Minimum block duration in minutes
    static let minDurationMinutes = 15

    /// Calculate new end date from a resize drag gesture.
    /// - Parameters:
    ///   - startDate: The block's fixed start date
    ///   - originalEndDate: The block's end date before resize started
    ///   - dragOffsetY: Vertical drag offset in points (positive = down = longer)
    ///   - hourHeight: Points per hour on the timeline
    /// - Returns: New end date, snapped to 15-min boundaries, clamped to minimum duration
    static func resizedEndDate(
        startDate: Date,
        originalEndDate: Date,
        dragOffsetY: CGFloat,
        hourHeight: CGFloat
    ) -> Date {
        // Convert pixel offset to minutes
        let minutesPerPoint = 60.0 / hourHeight
        let deltaMinutes = Double(dragOffsetY) * minutesPerPoint

        // Calculate raw new end date
        let rawEnd = originalEndDate.addingTimeInterval(deltaMinutes * 60)

        // Snap to nearest 15-minute boundary
        let snappedEnd = snapToQuarterHour(rawEnd)

        // Enforce minimum duration
        let minEnd = startDate.addingTimeInterval(Double(minDurationMinutes) * 60)
        let clampedEnd = snapToQuarterHour(minEnd)

        if snappedEnd <= clampedEnd {
            return clampedEnd
        }
        return snappedEnd
    }
}

// MARK: - Date Normalization

extension FocusBlock {
    /// Normalize endTime to the same calendar day as startTime.
    /// Fixes Bug 14: DatePicker with .hourAndMinute can wrap endTime to the next day
    /// when the user scrolls past midnight, causing duration to show "25 Std" instead of minutes.
    static func normalizeEndTime(startTime: Date, endTime: Date) -> Date {
        let calendar = Calendar.current
        guard !calendar.isDate(startTime, inSameDayAs: endTime) else {
            return endTime
        }
        // Put endTime's hour:minute on startTime's calendar day
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endTime)
        let normalized = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                       minute: endComponents.minute ?? 0,
                                       second: endComponents.second ?? 0,
                                       of: startTime) ?? endTime
        // If normalized is before/equal startTime, it means a midnight crossing
        // (e.g. start 23:00, end 00:25 → add 1 day to get 85 min duration)
        if normalized <= startTime {
            return calendar.date(byAdding: .day, value: 1, to: normalized) ?? normalized
        }
        return normalized
    }

    /// Snap a date to the nearest 15-minute boundary (round-to-nearest).
    /// 09:06 → 09:00, 09:08 → 09:15, 09:53 → 10:00
    static func snapToQuarterHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let snapped = ((minute + 7) / 15) * 15
        let hourOverflow = snapped / 60
        let finalMinute = snapped % 60

        var result = comps
        result.hour = (result.hour ?? 0) + hourOverflow
        result.minute = finalMinute
        result.second = 0
        return calendar.date(from: result) ?? date
    }
}

// MARK: - Notes Serialization

extension FocusBlock {
    /// Serialize focus block metadata to notes string
    /// Format:
    /// focusBlock:true
    /// tasks:id1|id2|id3
    /// completed:id1
    /// times:id1=120|id2=90
    static func serializeToNotes(taskIDs: [String], completedTaskIDs: [String], taskTimes: [String: Int] = [:]) -> String {
        var lines = ["focusBlock:true"]

        if !taskIDs.isEmpty {
            lines.append("tasks:\(taskIDs.joined(separator: "|"))")
        }

        if !completedTaskIDs.isEmpty {
            lines.append("completed:\(completedTaskIDs.joined(separator: "|"))")
        }

        if !taskTimes.isEmpty {
            let timesString = taskTimes.map { "\($0.key)=\($0.value)" }.joined(separator: "|")
            lines.append("times:\(timesString)")
        }

        return lines.joined(separator: "\n")
    }

    /// Generate notes string for this block
    var notesString: String {
        Self.serializeToNotes(taskIDs: taskIDs, completedTaskIDs: completedTaskIDs, taskTimes: taskTimes)
    }
}
