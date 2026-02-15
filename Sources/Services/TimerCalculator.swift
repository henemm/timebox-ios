import Foundation

/// Shared timer calculations for task progress tracking.
/// Used by both iOS (FocusLiveView) and macOS (MacFocusView).
enum TimerCalculator {

    /// Calculate progress (0.0 to 1.0+) for a task based on elapsed time.
    static func taskProgress(startTime: Date?, currentTime: Date, durationMinutes: Int) -> Double {
        guard let startTime else { return 0 }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(durationMinutes * 60)
        return elapsed / estimated
    }

    /// Calculate remaining minutes for a task.
    static func remainingTaskMinutes(startTime: Date?, currentTime: Date, durationMinutes: Int) -> Int {
        guard let startTime else { return durationMinutes }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(durationMinutes * 60)
        let remaining = estimated - elapsed
        return max(0, Int(remaining / 60))
    }

    // MARK: - Planned End Date (Block-relative)

    /// Planned end date for a task = blockStart + cumulative durations of all tasks up to and including this one,
    /// clamped to blockEndDate so overbooked tasks never show times beyond the block.
    static func plannedTaskEndDate(
        blockStartDate: Date,
        blockEndDate: Date,
        taskDurations: [(id: String, durationMinutes: Int)],
        currentTaskID: String
    ) -> Date {
        var cumulativeMinutes = 0
        for task in taskDurations {
            cumulativeMinutes += task.durationMinutes
            if task.id == currentTaskID { break }
        }
        let rawEnd = blockStartDate.addingTimeInterval(Double(cumulativeMinutes * 60))
        return min(rawEnd, blockEndDate)
    }

    /// Remaining seconds until planned task end (negative = overdue).
    static func remainingSeconds(until plannedEnd: Date, now: Date = Date()) -> Int {
        Int(plannedEnd.timeIntervalSince(now))
    }
}
