import Foundation

/// Aggregates discipline statistics from completed tasks.
/// Used by CoachMeinTagView to show "Dein Disziplin-Profil" breakdown.
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
