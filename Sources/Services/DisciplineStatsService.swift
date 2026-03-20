import Foundation

/// Aggregates discipline statistics from completed tasks.
/// Aggregates discipline statistics from completed tasks for review.
enum DisciplineStatsService {

    /// Compute discipline breakdown for a list of tasks.
    /// Only completed tasks (isCompleted && completedAt != nil) are counted.
    /// Manual override takes precedence over auto-classification.
    /// Returns all 4 disciplines sorted by count descending.
    static func breakdown(for tasks: [LocalTask]) -> [DisciplineStat] {
        let completed = tasks.filter { $0.isCompleted && $0.completedAt != nil }
        var counts: [Discipline: Int] = [:]
        for d in Discipline.allCases { counts[d] = 0 }

        for task in completed {
            let discipline = resolveDiscipline(for: task)
            counts[discipline, default: 0] += 1
        }

        let total = completed.count
        return Discipline.allCases.map { d in
            DisciplineStat(discipline: d, count: counts[d] ?? 0, total: total)
        }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Multi-Week History

    /// Compute discipline distribution for the last N weeks.
    /// Returns exactly `weeksBack` snapshots in chronological order (oldest first).
    /// Empty weeks have stats with count=0.
    static func weeklyHistory(
        tasks: [LocalTask],
        weeksBack: Int = 6,
        now: Date = Date()
    ) -> [WeeklyDisciplineSnapshot] {
        let calendar = Calendar.current
        var snapshots: [WeeklyDisciplineSnapshot] = []

        for weeksAgo in (0..<weeksBack).reversed() {
            guard let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                continue
            }

            let weekTasks = tasks.filter { task in
                guard task.isCompleted, let completedAt = task.completedAt else { return false }
                return completedAt >= weekInterval.start && completedAt < weekInterval.end
            }

            let stats = breakdown(for: weekTasks)
            snapshots.append(WeeklyDisciplineSnapshot(weekStart: weekInterval.start, stats: stats))
        }

        return snapshots
    }

    /// Detect trends for each discipline from weekly snapshots.
    /// A trend is "growing" when the share rises in 3+ consecutive weeks (with data).
    /// A trend is "declining" when the share drops in 3+ consecutive weeks.
    /// Otherwise "stable".
    static func trends(from snapshots: [WeeklyDisciplineSnapshot]) -> [DisciplineTrend] {
        Discipline.allCases.map { discipline in
            let percentages: [(hasData: Bool, pct: Double)] = snapshots.map { snapshot in
                guard let stat = snapshot.stats.first(where: { $0.discipline == discipline }) else {
                    return (false, 0)
                }
                let total = snapshot.total
                guard total > 0 else { return (false, 0) }
                return (true, Double(stat.count) / Double(total))
            }

            let withData = percentages.filter { $0.hasData }
            guard withData.count >= 3 else {
                return DisciplineTrend(discipline: discipline, direction: .stable, consecutiveWeeks: 0)
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
                return DisciplineTrend(discipline: discipline, direction: .growing, consecutiveWeeks: growingCount + 1)
            } else if decliningCount >= 2 {
                return DisciplineTrend(discipline: discipline, direction: .declining, consecutiveWeeks: decliningCount + 1)
            }
            return DisciplineTrend(discipline: discipline, direction: .stable, consecutiveWeeks: 0)
        }
    }

    /// Resolve discipline for a completed task.
    /// 1. Manual override (manualDiscipline) wins
    /// 2. classify() with task fields (uses estimatedDuration as effectiveDuration fallback)
    private static func resolveDiscipline(for task: LocalTask) -> Discipline {
        if let manual = task.manualDiscipline,
           let discipline = Discipline(rawValue: manual) {
            return discipline
        }
        // For completed tasks: use estimatedDuration as effectiveDuration proxy
        // (LocalTask has no effectiveDuration — only PlanItem does)
        let effectiveDuration = task.estimatedDuration ?? 0
        return Discipline.classify(
            rescheduleCount: task.rescheduleCount,
            importance: task.importance,
            effectiveDuration: effectiveDuration,
            estimatedDuration: task.estimatedDuration
        )
    }
}
