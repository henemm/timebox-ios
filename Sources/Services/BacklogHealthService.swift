import Foundation

/// Identifies stale tasks in the backlog that need attention.
/// A task is "stale" if it's older than a threshold OR has been rescheduled too often.
enum BacklogHealthService {

    /// Finds tasks that are stale based on age or reschedule count.
    /// - Parameters:
    ///   - tasks: All plan items to evaluate
    ///   - staleAgeDays: Days after which a task is considered stale (default: 14)
    ///   - staleRescheduleCount: Reschedule count threshold (default: 3)
    /// - Returns: Stale tasks sorted oldest first
    static func findStaleTasks(
        in tasks: [PlanItem],
        staleAgeDays: Int = 14,
        staleRescheduleCount: Int = 3
    ) -> [PlanItem] {
        let now = Date()
        let calendar = Calendar.current

        return tasks
            .filter { task in
                guard !task.isCompleted,
                      !task.isParked,
                      !task.isTemplate else {
                    return false
                }

                let daysSinceCreation = calendar.dateComponents([.day], from: task.createdAt, to: now).day ?? 0

                return daysSinceCreation >= staleAgeDays || task.rescheduleCount >= staleRescheduleCount
            }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
