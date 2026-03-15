import Foundation

/// 3-tier fulfillment level for evening reflection.
enum FulfillmentLevel: Equatable {
    case fulfilled
    case partial
    case notFulfilled
}

/// Gap types between coach goal and action — determines notification text.
enum CoachGap: Equatable {
    case procrastinatedTasksPending   // Troll: still have procrastinated tasks
    case noBigTaskStarted             // Feuer: no high-importance task started
    case bigTaskNotCompleted          // Feuer: big task started but not done
    case tasksOutsideBlocks           // Eule: completed tasks outside plan
    case noPlannedTasks               // Eule: nothing planned
    case onlySingleCategory           // Golem: only 1-2 categories
    case noTasksCompleted             // General: nothing done yet
}

/// Evaluates whether a daily coach goal is fulfilled based on task and block data.
enum IntentionEvaluationService {

    // MARK: - Fulfillment Check

    static func isFulfilled(
        coach: CoachType,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> Bool {
        let completed = completedToday(tasks, now: now)
        switch coach {
        case .troll:
            // At least 1 procrastinated task (rescheduleCount >= 2) completed
            return completed.contains { $0.rescheduleCount >= 2 }
        case .feuer:
            // The most important/biggest task completed
            return completed.contains { $0.importance == 3 }
        case .eule:
            // Only planned tasks completed, no unplanned
            let hasBlocks = !focusBlocksToday(focusBlocks, now: now).isEmpty
            let onlyPlanned = completed.allSatisfy { $0.isNextUp || $0.assignedFocusBlockID != nil }
            return hasBlocks && !completed.isEmpty && onlyPlanned
        case .golem:
            // Tasks in 3+ different categories
            let categories = Set(completed.map(\.taskType).filter { !$0.isEmpty })
            return categories.count >= 3
        }
    }

    // MARK: - Gap Detection

    static func detectGap(
        coach: CoachType,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> CoachGap? {
        guard !isFulfilled(coach: coach, tasks: tasks, focusBlocks: focusBlocks, now: now) else {
            return nil
        }

        let completed = completedToday(tasks, now: now)

        switch coach {
        case .troll:
            let hasProcrastinated = tasks.contains { !$0.isCompleted && $0.rescheduleCount >= 2 }
            return hasProcrastinated ? .procrastinatedTasksPending : .noTasksCompleted
        case .feuer:
            let hasBigTask = completed.contains { ($0.importance ?? 0) >= 2 }
            if completed.isEmpty { return .noBigTaskStarted }
            return hasBigTask ? .bigTaskNotCompleted : .noBigTaskStarted
        case .eule:
            let todayBlocks = focusBlocksToday(focusBlocks, now: now)
            if todayBlocks.isEmpty { return .noPlannedTasks }
            let hasOutside = completed.contains { $0.assignedFocusBlockID == nil && !$0.isNextUp }
            return hasOutside ? .tasksOutsideBlocks : .noPlannedTasks
        case .golem:
            return .onlySingleCategory
        }
    }

    // MARK: - Evening Reflection

    static func evaluateFulfillment(
        coach: CoachType,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> FulfillmentLevel {
        let completed = completedToday(tasks, now: now)

        switch coach {
        case .troll:
            let procrastinated = completed.filter { $0.rescheduleCount >= 2 }
            if !procrastinated.isEmpty { return .fulfilled }
            if !completed.isEmpty { return .partial }
            return .notFulfilled

        case .feuer:
            if completed.contains(where: { $0.importance == 3 }) { return .fulfilled }
            if !completed.isEmpty { return .partial }
            return .notFulfilled

        case .eule:
            let todayBlocks = focusBlocksToday(focusBlocks, now: now)
            if todayBlocks.isEmpty { return .notFulfilled }
            let completion = blockCompletionPercentage(focusBlocks: focusBlocks, now: now)
            if completion >= 0.7 { return .fulfilled }
            if completion >= 0.4 { return .partial }
            return .notFulfilled

        case .golem:
            let categories = Set(completed.map(\.taskType).filter { !$0.isEmpty })
            if categories.count >= 3 { return .fulfilled }
            if categories.count == 2 { return .partial }
            return .notFulfilled
        }
    }

    /// Calculate block completion percentage across all today's blocks.
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

    /// Fallback template text for evening reflection per coach + fulfillment level.
    static func fallbackTemplate(coach: CoachType, level: FulfillmentLevel) -> String {
        switch (coach, level) {
        case (.troll, .fulfilled):     return "Na also, geht doch. Die aufgeschobenen Dinger sind weg."
        case (.troll, .partial):       return "Ein paar Sachen erledigt — aber die alten Brocken warten noch."
        case (.troll, .notFulfilled):  return "Nichts Aufgeschobenes angepackt. Die warten morgen immer noch."

        case (.feuer, .fulfilled):     return "DAS war ein würdiger Gegner! Gut gemacht."
        case (.feuer, .partial):       return "Tasks erledigt — aber das große Ding wartet noch."
        case (.feuer, .notFulfilled):  return "Noch nicht an die Herausforderung rangegangen. Morgen!"

        case (.eule, .fulfilled):      return "Fokus gehalten. Nur das Geplante, nichts dazwischen. Stark."
        case (.eule, .partial):        return "Teilweise fokussiert — ein bisschen was dazwischen."
        case (.eule, .notFulfilled):   return "Heute nicht nach Plan. Morgen nochmal drei Dinge planen."

        case (.golem, .fulfilled):     return "Schöne Balance heute. Verschiedene Bereiche abgedeckt."
        case (.golem, .partial):       return "Zwei Bereiche — fast ausgeglichen."
        case (.golem, .notFulfilled):  return "Einseitig heute. Morgen mal was anderes probieren?"
        }
    }

    // MARK: - Helpers

    static func completedToday(_ tasks: [LocalTask], now: Date = Date()) -> [LocalTask] {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay
        }
    }

    static func focusBlocksToday(_ blocks: [FocusBlock], now: Date = Date()) -> [FocusBlock] {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return blocks.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
    }

    // MARK: - Weekly Helpers

    static func completedThisWeek(_ tasks: [LocalTask], now: Date = Date()) -> [LocalTask] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= weekInterval.start && completedAt < weekInterval.end
        }
    }

    static func focusBlocksThisWeek(_ blocks: [FocusBlock], now: Date = Date()) -> [FocusBlock] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return blocks.filter { $0.startDate >= weekInterval.start && $0.startDate < weekInterval.end }
    }

    // MARK: - Weekly Fulfillment

    static func evaluateWeeklyFulfillment(
        coach: CoachType,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) -> FulfillmentLevel {
        let completed = completedThisWeek(tasks, now: now)

        switch coach {
        case .troll:
            let procrastinated = completed.filter { $0.rescheduleCount >= 2 }
            if procrastinated.count >= 3 { return .fulfilled }
            if !procrastinated.isEmpty { return .partial }
            return .notFulfilled

        case .feuer:
            let important = completed.filter { $0.importance == 3 }
            if important.count >= 3 { return .fulfilled }
            if !important.isEmpty { return .partial }
            return .notFulfilled

        case .eule:
            let weekBlocks = focusBlocksThisWeek(focusBlocks, now: now)
            if weekBlocks.isEmpty { return .notFulfilled }
            let totalTasks = weekBlocks.reduce(0) { $0 + $1.taskIDs.count }
            guard totalTasks > 0 else { return .notFulfilled }
            let completedTasks = weekBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
            let ratio = Double(completedTasks) / Double(totalTasks)
            if ratio >= 0.7 { return .fulfilled }
            if ratio >= 0.4 { return .partial }
            return .notFulfilled

        case .golem:
            let categories = Set(completed.map(\.taskType).filter { !$0.isEmpty })
            if categories.count >= 4 { return .fulfilled }
            if categories.count >= 2 { return .partial }
            return .notFulfilled
        }
    }

    // MARK: - Weekly Fallback Templates

    static func weeklyFallbackTemplate(coach: CoachType, level: FulfillmentLevel) -> String {
        switch (coach, level) {
        case (.troll, .fulfilled):     return "Eine ganze Woche lang hast du dich den Dingen gestellt, die du sonst aufschiebst. Respekt."
        case (.troll, .partial):       return "Ein paar aufgeschobene Sachen angegangen diese Woche. Da geht noch mehr."
        case (.troll, .notFulfilled):  return "Diese Woche hast du die unangenehmen Dinge liegen lassen. Die warten naechste Woche immer noch."

        case (.feuer, .fulfilled):     return "Mehrere grosse Brocken diese Woche erledigt. Das war stark."
        case (.feuer, .partial):       return "Eine Herausforderung gemeistert diese Woche — naechste Woche noch eine?"
        case (.feuer, .notFulfilled):  return "Keine grosse Herausforderung diese Woche angegangen. Naechste Woche mutig sein!"

        case (.eule, .fulfilled):      return "Fokussiert nach Plan gearbeitet diese Woche. So geht das."
        case (.eule, .partial):        return "Teilweise fokussiert diese Woche. Nah dran am guten Rhythmus."
        case (.eule, .notFulfilled):   return "Diese Woche wenig Struktur. Naechste Woche drei Dinge pro Tag planen."

        case (.golem, .fulfilled):     return "Schoene Balance diese Woche. Verschiedene Lebensbereiche abgedeckt."
        case (.golem, .partial):       return "Ein paar Bereiche abgedeckt diese Woche. Fast ausgeglichen."
        case (.golem, .notFulfilled):  return "Einseitige Woche. Naechste Woche bewusst verschiedene Bereiche einplanen."
        }
    }
}
