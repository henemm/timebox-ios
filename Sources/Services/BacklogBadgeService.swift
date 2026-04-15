import Foundation

/// Counts tasks for the Backlog tab badge.
/// Badge shows "doNow" tasks (priority score >= 60) — tasks that need immediate attention.
enum BacklogBadgeService {

    /// Count tasks with priority tier "doNow" (score >= 60).
    /// Excludes completed, parked, and template tasks.
    static func countDoNowTasks(in tasks: [PlanItem]) -> Int {
        tasks.filter { task in
            !task.isCompleted && !task.isParked && !task.isTemplate
            && !task.isNextUp && task.assignedFocusBlockID == nil
            && task.priorityTier == .doNow
        }.count
    }
}
