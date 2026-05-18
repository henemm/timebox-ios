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
/// Returns one representative per group with a stackedCount + oldest dueDate.
enum MacBacklogStackingHelper {

    struct StackedItem {
        let task: LocalTask
        /// Number of EXTRA instances (0 = no stacking, 1 = x2 badge, 2+ = x3+ badge)
        let stackedCount: Int
        /// Aeltestes dueDate der Gruppe (fuer Counter-Bar "seit ..."). Nil bei stackedCount=0.
        let oldestDueDate: Date?
    }

    /// Applies virtual stacking to tasks. Path A (grouping by recurrenceGroupID) is removed;
    /// consolidation now happens at migration time. Only Path B (virtual cycle calculation) remains.
    static func applyStacking(_ tasks: [LocalTask]) -> [StackedItem] {
        var result: [StackedItem] = tasks.map {
            StackedItem(task: $0, stackedCount: 0, oldestDueDate: nil)
        }

        // MARK: - Pfad B: Single-Task-Cycle-Auflauf (#279 — bug-stacking-real-data)
        // Auf macOS analog zu iOS: recurring Tasks deren dueDate weit genug in der
        // Vergangenheit liegt, bekommen einen stackedCount aus verpassten Cycles.
        // Hinweis: stackedCount ist hier der EXTRA-Counter (instanceCount - 1).
        for index in result.indices {
            let item = result[index]
            let task = item.task

            // Eligible: recurring, nicht template/completed/nextUp, dueDate in Vergangenheit
            let pattern = task.recurrencePattern
            guard pattern != "none",
                  !pattern.isEmpty,
                  !task.isTemplate,
                  !task.isCompleted,
                  !task.isNextUp,
                  let dueDate = task.dueDate else { continue }

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfDueDate = calendar.startOfDay(for: dueDate)
            guard startOfDueDate < startOfToday else { continue }

            let elapsedDays = calendar.dateComponents([.day], from: startOfDueDate, to: startOfToday).day ?? 0
            let cycleDays = RecurringStackingHelper.cycleDuration(
                for: pattern,
                interval: task.recurrenceInterval
            )
            guard cycleDays > 0 else { continue }

            let missedCycles = (elapsedDays / cycleDays) + 1
            guard missedCycles >= 2 else { continue }

            // Pfad B liefert instanceCount; auf macOS-extraCount mappen: instanceCount - 1
            let pathBExtraCount = missedCycles - 1
            let currentExtraCount = item.stackedCount
            if pathBExtraCount > currentExtraCount {
                let newOldest = item.oldestDueDate ?? dueDate
                result[index] = StackedItem(
                    task: task,
                    stackedCount: pathBExtraCount,
                    oldestDueDate: newOldest
                )
            }
        }

        return result
    }
}
