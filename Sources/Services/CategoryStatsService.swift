import Foundation

/// Aggregates task category statistics from completed tasks.
/// Provides category-based trend data for review views.
/// Tasks without a category (taskType == "") are counted as "uncategorized".
enum CategoryStatsService {

    /// Compute category breakdown for a list of tasks.
    /// Only completed tasks (isCompleted && completedAt != nil) are counted.
    /// Returns 5 categories + 1 uncategorized, sorted by count descending.
    static func categoryBreakdown(for tasks: [LocalTask]) -> [CategoryCountStat] {
        let completed = tasks.filter { $0.isCompleted && $0.completedAt != nil }

        var counts: [String: Int] = [:]
        for category in TaskCategory.allCases {
            counts[category.rawValue] = 0
        }
        counts[""] = 0 // uncategorized

        for task in completed {
            let key = TaskCategory(rawValue: task.taskType) != nil ? task.taskType : ""
            counts[key, default: 0] += 1
        }

        let total = completed.count
        var stats: [CategoryCountStat] = TaskCategory.allCases.map { category in
            CategoryCountStat(category: category, count: counts[category.rawValue] ?? 0, total: total)
        }
        stats.append(CategoryCountStat(category: nil, count: counts[""] ?? 0, total: total))

        return stats.sorted { $0.count > $1.count }
    }

    // MARK: - Multi-Week History

    /// Compute category distribution for the last N weeks.
    /// Returns exactly `weeksBack` snapshots in chronological order (oldest first).
    static func weeklyCategoryHistory(
        tasks: [LocalTask],
        weeksBack: Int = 6,
        now: Date = Date()
    ) -> [WeeklyCategorySnapshot] {
        let calendar = Calendar.current
        var snapshots: [WeeklyCategorySnapshot] = []

        for weeksAgo in (0..<weeksBack).reversed() {
            guard let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                continue
            }

            let weekTasks = tasks.filter { task in
                guard task.isCompleted, let completedAt = task.completedAt else { return false }
                return completedAt >= weekInterval.start && completedAt < weekInterval.end
            }

            let stats = categoryBreakdown(for: weekTasks)
            snapshots.append(WeeklyCategorySnapshot(weekStart: weekInterval.start, stats: stats))
        }

        return snapshots
    }

    /// Detect trends for each category from weekly snapshots.
    /// A trend is "growing" when the share rises in 3+ consecutive weeks (with data).
    /// A trend is "declining" when the share drops in 3+ consecutive weeks.
    /// Otherwise "stable".
    static func categoryTrends(from snapshots: [WeeklyCategorySnapshot]) -> [CategoryTrend] {
        let allKeys: [TaskCategory?] = TaskCategory.allCases.map { $0 } + [nil]

        return allKeys.map { category in
            let percentages: [(hasData: Bool, pct: Double)] = snapshots.map { snapshot in
                guard let stat = snapshot.stats.first(where: { $0.category == category }) else {
                    return (false, 0)
                }
                let total = snapshot.total
                guard total > 0 else { return (false, 0) }
                return (true, Double(stat.count) / Double(total))
            }

            let withData = percentages.filter { $0.hasData }
            guard withData.count >= 3 else {
                return CategoryTrend(category: category, direction: .stable, consecutiveWeeks: 0)
            }

            var growingCount = 0
            for i in stride(from: withData.count - 1, through: 1, by: -1) {
                if withData[i].pct > withData[i - 1].pct { growingCount += 1 } else { break }
            }
            var decliningCount = 0
            for i in stride(from: withData.count - 1, through: 1, by: -1) {
                if withData[i].pct < withData[i - 1].pct { decliningCount += 1 } else { break }
            }

            if growingCount >= 2 {
                return CategoryTrend(category: category, direction: .growing, consecutiveWeeks: growingCount + 1)
            } else if decliningCount >= 2 {
                return CategoryTrend(category: category, direction: .declining, consecutiveWeeks: decliningCount + 1)
            }
            return CategoryTrend(category: category, direction: .stable, consecutiveWeeks: 0)
        }
    }
}
