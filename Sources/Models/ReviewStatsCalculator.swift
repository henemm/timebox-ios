import Foundation

/// Utility for computing category statistics from tasks and calendar events.
/// Used by DailyReviewView (iOS) and MacReviewView (macOS) to aggregate
/// time spent per category, including both completed tasks and categorized calendar events.
struct ReviewStatsCalculator {

    /// Compute category minutes from calendar events only.
    /// Filters out uncategorized events and FocusBlock events.
    ///
    /// - Parameters:
    ///   - tasks: Unused placeholder for API compatibility
    ///   - calendarEvents: Calendar events to include
    /// - Returns: Dictionary of category rawValue -> total minutes
    func computeCategoryMinutes(tasks: [Any], calendarEvents: [CalendarEvent]) -> [String: Int] {
        var stats: [String: Int] = [:]

        for event in calendarEvents {
            guard !event.isFocusBlock,
                  let category = event.category,
                  !category.isEmpty else { continue }
            stats[category, default: 0] += event.durationMinutes
        }

        return stats
    }

    /// Compute category minutes from pre-aggregated task minutes + calendar events.
    /// Combines task-based stats with event-based stats.
    ///
    /// - Parameters:
    ///   - taskMinutesByCategory: Pre-aggregated minutes per category from tasks
    ///   - calendarEvents: Calendar events to include
    /// - Returns: Combined dictionary of category rawValue -> total minutes
    func computeCategoryMinutes(taskMinutesByCategory: [String: Int], calendarEvents: [CalendarEvent]) -> [String: Int] {
        var stats = taskMinutesByCategory

        for event in calendarEvents {
            guard !event.isFocusBlock,
                  let category = event.category,
                  !category.isEmpty else { continue }
            stats[category, default: 0] += event.durationMinutes
        }

        return stats
    }

    /// Compute planning accuracy stats from focus blocks and tasks.
    /// Compares estimated duration (minutes) with actual time (seconds from taskTimes).
    ///
    /// - Parameters:
    ///   - blocks: FocusBlocks with taskTimes data
    ///   - allTasks: All tasks (to look up estimatedDuration and rescheduleCount)
    /// - Returns: PlanningAccuracyStats with faster/slower/onTime counts
    func computePlanningAccuracy(blocks: [FocusBlock], allTasks: [PlanItem]) -> PlanningAccuracyStats {
        let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })
        var fasterCount = 0
        var slowerCount = 0
        var onTimeCount = 0
        var totalDeviation: Double = 0
        var trackedCount = 0
        var totalReschedules = 0
        var rescheduledTasks = 0

        for block in blocks {
            for (taskID, actualSeconds) in block.taskTimes {
                guard let task = taskMap[taskID] else { continue }
                let estimatedSeconds = task.effectiveDuration * 60

                guard estimatedSeconds > 0 && actualSeconds > 0 else { continue }

                let deviation = Double(actualSeconds - estimatedSeconds) / Double(estimatedSeconds)
                totalDeviation += deviation
                trackedCount += 1

                // ±10% tolerance = "on time"
                if deviation < -0.10 {
                    fasterCount += 1
                } else if deviation > 0.10 {
                    slowerCount += 1
                } else {
                    onTimeCount += 1
                }
            }
        }

        // Reschedule stats from tasks
        for task in allTasks {
            let reschedules = task.rescheduleCount
            totalReschedules += reschedules
            if reschedules > 0 {
                rescheduledTasks += 1
            }
        }

        let avgDeviation = trackedCount > 0 ? totalDeviation / Double(trackedCount) : 0

        return PlanningAccuracyStats(
            fasterCount: fasterCount,
            slowerCount: slowerCount,
            onTimeCount: onTimeCount,
            averageDeviation: avgDeviation,
            trackedTaskCount: trackedCount,
            totalReschedules: totalReschedules,
            rescheduledTaskCount: rescheduledTasks
        )
    }
}

/// Planning accuracy statistics
struct PlanningAccuracyStats {
    let fasterCount: Int
    let slowerCount: Int
    let onTimeCount: Int
    let averageDeviation: Double    // -0.2 = 20% faster, 0.3 = 30% slower
    let trackedTaskCount: Int
    let totalReschedules: Int
    let rescheduledTaskCount: Int

    var hasData: Bool { trackedTaskCount > 0 || totalReschedules > 0 }

    var averageDeviationFormatted: String {
        let pct = Int(abs(averageDeviation) * 100)
        if averageDeviation < -0.05 {
            return "\(pct)% schneller"
        } else if averageDeviation > 0.05 {
            return "\(pct)% langsamer"
        }
        return "im Plan"
    }
}
