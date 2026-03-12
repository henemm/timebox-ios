import Foundation

/// 3-tier fulfillment level for evening reflection (Phase 3c).
enum FulfillmentLevel: Equatable {
    case fulfilled
    case partial
    case notFulfilled
}

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

    // MARK: - Evening Reflection (Phase 3c)

    /// Evaluate fulfillment level for the evening reflection card.
    /// Returns fulfilled/partial/notFulfilled based on intention-specific criteria.
    static func evaluateFulfillment(
        intention: IntentionOption,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> FulfillmentLevel {
        let completed = completedToday(tasks, now: now)

        switch intention {
        case .survival:
            return completed.isEmpty ? .notFulfilled : .fulfilled

        case .fokus:
            let completion = blockCompletionPercentage(focusBlocks: focusBlocks, now: now)
            let hasBlocks = !focusBlocksToday(focusBlocks, now: now).isEmpty
            if !hasBlocks { return .notFulfilled }
            if completion >= 0.7 { return .fulfilled }
            if completion >= 0.4 { return .partial }
            return .notFulfilled

        case .bhag:
            let hasBhag = completed.contains { $0.importance == 3 }
            if hasBhag { return .fulfilled }
            if !completed.isEmpty { return .partial }
            return .notFulfilled

        case .balance:
            let categories = Set(completed.map(\.taskType).filter { !$0.isEmpty })
            if categories.count >= 3 { return .fulfilled }
            if categories.count == 2 { return .partial }
            return .notFulfilled

        case .growth:
            return completed.contains(where: { $0.taskType == "learning" })
                ? .fulfilled : .notFulfilled

        case .connection:
            return completed.contains(where: { $0.taskType == "giving_back" })
                ? .fulfilled : .notFulfilled
        }
    }

    /// Calculate block completion percentage across all today's blocks.
    /// Returns 0.0 if no blocks or no tasks in blocks.
    static func blockCompletionPercentage(
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> Double {
        let todayBlocks = focusBlocksToday(focusBlocks, now: now)
        let totalTasks = todayBlocks.reduce(0) { $0 + $1.taskIDs.count }
        guard totalTasks > 0 else { return 0.0 }
        let completedTasks = todayBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
        return Double(completedTasks) / Double(totalTasks)
    }

    /// Fallback template text for evening reflection (used until Foundation Models in Phase 3d).
    static func fallbackTemplate(intention: IntentionOption, level: FulfillmentLevel) -> String {
        switch (intention, level) {
        case (.survival, .fulfilled):    return "Du hast es geschafft. Auch das zaehlt."
        case (.survival, .notFulfilled): return "Manchmal reicht es zu atmen. Morgen ist ein neuer Tag."
        case (.fokus, .fulfilled):       return "Du bist bei der Sache geblieben. Stark."
        case (.fokus, .partial):         return "Nicht perfekt fokussiert — aber du warst dran."
        case (.fokus, .notFulfilled):    return "Viel dazwischen gekommen heute. Passiert."
        case (.bhag, .fulfilled):        return "DU HAST ES GETAN! Weisst du was das bedeutet?!"
        case (.bhag, .partial):          return "Tasks erledigt — aber das grosse Ding wartet noch."
        case (.bhag, .notFulfilled):     return "Noch nicht dran gewesen. Morgen ist die Chance."
        case (.balance, .fulfilled):     return "Was fuer ein runder Tag."
        case (.balance, .partial):       return "Zwei Bereiche abgedeckt — fast ausgeglichen."
        case (.balance, .notFulfilled):  return "Einseitig heute. Morgen mal was anderes probieren?"
        case (.growth, .fulfilled):      return "Du bist heute klueger als gestern."
        case (.growth, .notFulfilled):   return "Kein Lernen heute — auch okay. Neugier kommt wieder."
        case (.connection, .fulfilled):  return "Du hast jemandem den Tag besser gemacht."
        case (.connection, .notFulfilled): return "Fuer dich heute. Fuer andere morgen."
        default:                         return ""
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
