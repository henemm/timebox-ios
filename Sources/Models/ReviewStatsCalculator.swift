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
}
