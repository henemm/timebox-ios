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

    // MARK: - Priority View Sections (Coach-Boost + Tiers)

    /// Coach-Boost: Tasks matching the coach filter, excluding NextUp.
    /// These appear in a dedicated coach section above the tier sections.
    static func coachBoostedTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        relevantTasks(from: tasks, selectedCoach: selectedCoach)
    }

    /// All incomplete, non-template tasks MINUS NextUp MINUS Coach-Boost.
    /// Used as the pool for overdue + tier sections.
    static func remainingTasks(from tasks: [PlanItem], selectedCoach: String) -> [PlanItem] {
        let nextUpIDs = Set(nextUpTasks(from: tasks).map(\.id))
        let boostIDs = Set(coachBoostedTasks(from: tasks, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter {
            !$0.isCompleted && !$0.isTemplate &&
            !nextUpIDs.contains($0.id) && !boostIDs.contains($0.id)
        }
    }

    /// Overdue tasks (dueDate < start of today) from the given pool.
    static func overdueTasks(from tasks: [PlanItem]) -> [PlanItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks.filter { !$0.isCompleted && !$0.isTemplate }
            .filter { item in
                guard let due = item.dueDate else { return false }
                return due < startOfToday
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Tasks matching a specific PriorityTier, excluding a set of IDs (e.g. overdue tasks).
    static func tierTasks(from tasks: [PlanItem], tier: TaskPriorityScoringService.PriorityTier, excludeIDs: Set<String>) -> [PlanItem] {
        tasks.filter { !$0.isCompleted && !$0.isTemplate && !excludeIDs.contains($0.id) }
            .filter { $0.priorityTier == tier }
            .sorted { $0.priorityScore > $1.priorityScore }
    }

    // MARK: - Alternative View Modes

    /// Recent tasks sorted by most recent date (createdAt or modifiedAt).
    static func recentTasks(from tasks: [PlanItem]) -> [PlanItem] {
        tasks.filter { !$0.isCompleted && !$0.isTemplate }
            .sorted { a, b in
                let aDate = max(a.createdAt, a.modifiedAt ?? .distantPast)
                let bDate = max(b.createdAt, b.modifiedAt ?? .distantPast)
                return aDate > bDate
            }
    }

    /// Only completed tasks.
    static func completedTasks(from tasks: [PlanItem]) -> [PlanItem] {
        tasks.filter { $0.isCompleted }
    }

    /// Only template tasks (recurring series).
    static func recurringTasks(from tasks: [PlanItem]) -> [PlanItem] {
        tasks.filter { $0.isTemplate && !$0.isCompleted }
    }

    // MARK: - Coach Section Title

    /// Formatted section title: "Coach.displayName — Coach.subtitle"
    static func coachSectionTitle(for selectedCoach: String) -> String? {
        guard let coach = parseCoach(selectedCoach) else { return nil }
        return "\(coach.displayName) — \(coach.subtitle)"
    }
}
