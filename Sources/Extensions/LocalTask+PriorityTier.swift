//
//  LocalTask+PriorityTier.swift
//  FocusBlox
//
//  Bug #290 — Shared priority-score / -tier accessors so macOS- and iOS-Views
//  can ask `task.priorityScore` / `task.priorityTier` without constructing a
//  `PlanItem` wrapper. Delegates to `TaskPriorityScoringService` so values are
//  identical to those exposed by `PlanItem`.
//

import Foundation

extension LocalTask {
    /// Deterministic priority score (0-100). Delegates to `PlanItem.priorityScore`
    /// so the value is always identical to what the main backlog view shows —
    /// including future Blocker- and Stacking-Bonus.
    var priorityScore: Int {
        PlanItem(localTask: self).priorityScore
    }

    /// Priority tier derived from `priorityScore` — identical to PlanItem.priorityTier.
    var priorityTier: TaskPriorityScoringService.PriorityTier {
        PlanItem(localTask: self).priorityTier
    }
}
