//
//  MacBacklogHelpers.swift
//  FocusBloxMac
//
//  MAC_028: Parkdeck filter + Stacking grouping helpers.
//  Pure functions extracted for testability.
//

import Foundation

// MARK: - Parkdeck Filter Helper

/// Determines if a task belongs in the "Geparkt" section.
/// RW 2.4b: NUR manuell geparkt, nicht mehr Score-basiert.
enum MacBacklogFilterHelper {

    /// A task is "geparkt" only if manually parked (isParked == true).
    static func isInParkdeck(task: LocalTask, score: Int) -> Bool {
        task.isParked
    }
}

// MARK: - Stacking Grouping Helper

/// Groups recurring task instances by recurrenceGroupID.
/// Returns one representative per group with a stackedCount.
enum MacBacklogStackingHelper {

    struct StackedItem {
        let task: LocalTask
        /// Number of EXTRA instances (0 = no stacking, 1 = x2 badge, 2+ = x3+ badge)
        let stackedCount: Int
    }

    /// Groups tasks by recurrenceGroupID. The oldest instance (earliest dueDate)
    /// becomes the representative. Non-recurring tasks pass through with stackedCount=0.
    static func applyStacking(_ tasks: [LocalTask]) -> [StackedItem] {
        var grouped: [String: [LocalTask]] = [:]
        var ungrouped: [LocalTask] = []

        for task in tasks {
            if let gid = task.recurrenceGroupID, !gid.isEmpty,
               !task.isTemplate, !task.isCompleted, !task.isNextUp {
                grouped[gid, default: []].append(task)
            } else {
                ungrouped.append(task)
            }
        }

        var result: [StackedItem] = ungrouped.map { StackedItem(task: $0, stackedCount: 0) }

        for (_, group) in grouped {
            let sorted = group.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            let representative = sorted[0]
            let extraCount = sorted.count - 1
            result.append(StackedItem(task: representative, stackedCount: extraCount))
        }

        return result
    }
}
