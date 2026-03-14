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

    /// Returns incomplete, non-template tasks matching the active coach filter.
    /// Returns empty array when no coach is selected.
    static func relevantTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        guard let coach = parseCoach(selectedCoach) else { return [] }
        return CoachType.filterTasks(tasks, coach: coach)
    }

    /// Returns incomplete, non-template tasks NOT matching the active coach filter.
    /// Returns all incomplete tasks when no coach is selected.
    static func otherTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        guard let coach = parseCoach(selectedCoach) else {
            return tasks.filter { !$0.isCompleted && !$0.isTemplate }
        }
        let relevantIDs = Set(CoachType.filterTasks(tasks, coach: coach).map(\.id))
        return tasks.filter { !$0.isCompleted && !$0.isTemplate && !relevantIDs.contains($0.id) }
    }
}
