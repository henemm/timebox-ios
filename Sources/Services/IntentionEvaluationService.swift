import Foundation

/// Gap types between intention and action — determines notification text.
enum IntentionGap: Equatable {
    case noBhagBlockCreated
    case bhagTaskNotStarted
    case noFocusBlockPlanned
    case tasksOutsideBlocks
    case onlySingleCategory
    case noLearningTask
    case noConnectionTask
}

/// Evaluates whether a daily intention is fulfilled based on task and block data.
/// Used by Smart Notifications (Phase 3b) and Evening Reflection (Phase 3c).
enum IntentionEvaluationService {

    // MARK: - Public API

    /// Check if the given intention is fulfilled based on today's tasks and blocks.
    static func isFulfilled(
        intention: IntentionOption,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> Bool {
        switch intention {
        case .survival:
            return true
        case .bhag:
            return completedToday(tasks, now: now)
                .contains { $0.importance == 3 }
        case .fokus:
            let hasBlocks = !focusBlocksToday(focusBlocks, now: now).isEmpty
            let hasOutsideTasks = completedToday(tasks, now: now)
                .contains { $0.assignedFocusBlockID == nil }
            return hasBlocks && !hasOutsideTasks
        case .growth:
            return completedToday(tasks, now: now)
                .contains { $0.taskType == "learning" }
        case .connection:
            return completedToday(tasks, now: now)
                .contains { $0.taskType == "giving_back" }
        case .balance:
            let categories = Set(
                completedToday(tasks, now: now)
                    .map(\.taskType)
                    .filter { !$0.isEmpty }
            )
            return categories.count >= 3
        }
    }

    /// Detect the gap between intention and action. Returns nil if fulfilled or survival.
    static func detectGap(
        intention: IntentionOption,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> IntentionGap? {
        guard intention != .survival else { return nil }
        guard !isFulfilled(intention: intention, tasks: tasks, focusBlocks: focusBlocks, now: now) else {
            return nil
        }

        switch intention {
        case .survival:
            return nil
        case .bhag:
            let todayBlocks = focusBlocksToday(focusBlocks, now: now)
            let hour = Calendar.current.component(.hour, from: now)
            if todayBlocks.isEmpty {
                return .noBhagBlockCreated
            }
            if hour >= 13 {
                return .bhagTaskNotStarted
            }
            return .noBhagBlockCreated
        case .fokus:
            let todayBlocks = focusBlocksToday(focusBlocks, now: now)
            if todayBlocks.isEmpty {
                return .noFocusBlockPlanned
            }
            let hasOutsideTasks = completedToday(tasks, now: now)
                .contains { $0.assignedFocusBlockID == nil }
            if hasOutsideTasks {
                return .tasksOutsideBlocks
            }
            return .noFocusBlockPlanned
        case .balance:
            return .onlySingleCategory
        case .growth:
            return .noLearningTask
        case .connection:
            return .noConnectionTask
        }
    }

    // MARK: - Helpers

    /// Filter tasks to those completed today (completedAt >= start of day).
    static func completedToday(_ tasks: [LocalTask], now: Date = Date()) -> [LocalTask] {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay
        }
    }

    /// Filter focus blocks to those starting today.
    static func focusBlocksToday(_ blocks: [FocusBlock], now: Date = Date()) -> [FocusBlock] {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return blocks.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
    }
}
