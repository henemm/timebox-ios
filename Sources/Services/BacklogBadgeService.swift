import Foundation

/// Counts tasks for the Backlog tab badge.
///
/// Issues #288/#294/#296 — Overdue-Marker-Rework:
/// Counter basiert auf `isOverdueNow` (uhrzeit-praezise) statt Score-Tier.
/// `countDoNowTasks` bleibt als Alias erhalten — Tests und alte Aufrufer
/// erwarten dieselbe Filterung.
enum BacklogBadgeService {

    /// Count tasks that are overdue right now (uhrzeit-praezise).
    /// Excludes completed, parked, template, NextUp and FocusBlock-assigned tasks.
    ///
    /// Wendet zuerst `RecurringStackingHelper.apply` an, damit mehrere
    /// `recurrenceGroupID`-Instanzen wie EIN Master-Task gezaehlt werden —
    /// analog zur BacklogView. Sichert die Kern-Invariante
    /// "Counter-Zahl == Anzahl roter Punkte im Backlog".
    ///
    /// - Parameter pendingIDs: Task-IDs die aktuell in der `DeferredCompletionController`
    ///   3-Sekunden-Pending-Phase sind. Diese werden aus dem Counter ausgeschlossen
    ///   (AC-13/AC-14), damit der rote Punkt + Counter SOFORT bei Tap auf die
    ///   Checkbox verschwinden — auch wenn der DB-Commit noch nicht erfolgt ist.
    ///   Default `[]` haelt bestehende Aufrufer (Tests, App-Icon-Badge ohne View-Context)
    ///   unveraendert.
    static func countOverdueTasks(
        _ tasks: [PlanItem],
        excludingPendingIDs pendingIDs: Set<String> = []
    ) -> Int {
        let stacked = RecurringStackingHelper.apply(to: tasks)
        return stacked.filter { task in
            guard !task.isCompleted, !task.isParked, !task.isTemplate,
                  !task.isNextUp, task.assignedFocusBlockID == nil,
                  !pendingIDs.contains(task.id) else { return false }
            // Master selbst ueberfaellig?
            if task.isOverdueNow { return true }
            // Edge-Case: Master in der Zukunft, aber aelteste gestapelte Instanz schon ueberfaellig.
            if let oldest = task.stackedOldestDueDate, oldest < Date() { return true }
            return false
        }.count
    }

    /// Alias for `countOverdueTasks` — keeps the historical API stable.
    /// Bedeutung hat sich gewandelt von Score-Tier auf Ueberfaelligkeit (#288/#294/#296).
    static func countDoNowTasks(in tasks: [PlanItem]) -> Int {
        countOverdueTasks(tasks)
    }
}
