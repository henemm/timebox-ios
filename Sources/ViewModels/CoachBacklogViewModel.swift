import Foundation

/// Shared business logic for Coach Backlog views (iOS + macOS).
/// Filters and sections tasks based on the selected CoachType.
enum CoachBacklogViewModel {

    // MARK: - Coach Selection Parsing

    /// Parses the `selectedCoach` AppStorage string into a CoachType.
    static func parseCoach(_ raw: String) -> CoachType? {
        guard !raw.isEmpty else { return nil }
        return CoachType(rawValue: raw)
    }

    // MARK: - Task Sectioning

    /// Returns incomplete, non-template tasks with isNextUp == true, sorted by nextUpSortOrder.
    /// Shown in a dedicated "Next Up" section above the coach-filtered sections.
    static func nextUpTasks(from tasks: [PlanItem]) -> [PlanItem] {
        tasks.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate }
            .sorted { ($0.nextUpSortOrder ?? Int.max) < ($1.nextUpSortOrder ?? Int.max) }
    }

    /// Returns incomplete, non-template tasks matching the active coach filter,
    /// excluding NextUp tasks (they have their own section).
    static func relevantTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        guard let coach = parseCoach(selectedCoach) else { return [] }
        let nextUpIDs = Set(nextUpTasks(from: tasks).map(\.id))
        return CoachType.filterTasks(tasks, coach: coach)
            .filter { !nextUpIDs.contains($0.id) }
    }

    /// Returns incomplete, non-template tasks NOT matching the active coach filter
    /// and NOT in NextUp (they have their own section).
    static func otherTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        let nextUpIDs = Set(nextUpTasks(from: tasks).map(\.id))
        guard let coach = parseCoach(selectedCoach) else {
            return tasks.filter { !$0.isCompleted && !$0.isTemplate && !nextUpIDs.contains($0.id) }
        }
        let relevantIDs = Set(CoachType.filterTasks(tasks, coach: coach).map(\.id))
        return tasks.filter {
            !$0.isCompleted && !$0.isTemplate &&
            !relevantIDs.contains($0.id) && !nextUpIDs.contains($0.id)
        }
    }
}
