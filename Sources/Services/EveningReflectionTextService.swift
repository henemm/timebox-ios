import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates personalized evening reflection texts using on-device AI (Foundation Models).
/// Falls back to IntentionEvaluationService.fallbackTemplate() when AI is unavailable.
@MainActor
final class EveningReflectionTextService {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - @Generable Struct

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ReflectionText {
        @Guide(description: "2-3 persoenliche Saetze ueber den Tag des Users. Empathisch, direkt, nie toxisch positiv, nie schuldzuweisend. Bezieht sich auf konkrete erledigte Task-Titel wenn vorhanden. Auf Deutsch. Max 200 Zeichen.")
        let text: String
    }
    #endif

    // MARK: - Public API

    /// Generates AI text for the selected coach.
    /// Returns nil when AI is unavailable or disabled — caller uses fallbackTemplate().
    func generateText(
        coach: CoachType,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) async -> String? {
        guard Self.isAvailable else { return nil }
        guard AppSettings.shared.aiScoringEnabled else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performGeneration(
                coach: coach,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )
        }
        #endif
        return nil
    }

    /// Generate AI text for the active coach selection.
    func generateTextForCoach(
        coach: CoachType,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) async -> String? {
        let level = IntentionEvaluationService.evaluateFulfillment(
            coach: coach, tasks: tasks, focusBlocks: focusBlocks, now: now
        )
        return await generateText(
            coach: coach, level: level, tasks: tasks, focusBlocks: focusBlocks, now: now
        )
    }

    // MARK: - Prompt Building (internal for testing)

    func buildPrompt(
        coach: CoachType,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) -> String {
        let completedTasks = IntentionEvaluationService.completedToday(tasks, now: now)
        let todayBlocks = IntentionEvaluationService.focusBlocksToday(focusBlocks, now: now)

        var parts: [String] = []

        // Coach + Ergebnis
        parts.append("Coach: \(coach.displayName) — \(coach.subtitle)")
        parts.append("Persönlichkeit: \(coach.personality)")
        parts.append("Ergebnis: \(levelDescription(level))")

        // Coach-spezifische Guidance
        parts.append("Schwerpunkt: \(coachGuidance(coach, completedTasks: completedTasks))")

        // Erledigte Tasks (max 5, nach Coach-Relevanz sortiert)
        let sorted = sortedByRelevance(completedTasks, for: coach)
        if !sorted.isEmpty {
            let taskLines = sorted.prefix(5).map { task -> String in
                let timeStr = formatTime(task.completedAt, now: now)
                let importanceStr = task.importance == 3 ? " [Wichtigkeit: hoch]" : ""
                let rescheduleStr = task.rescheduleCount >= 2 ? " [verschoben: \(task.rescheduleCount)x]" : ""
                return "- '\(task.title)'\(timeStr)\(importanceStr)\(rescheduleStr)"
            }
            parts.append("Erledigte Tasks heute:\n\(taskLines.joined(separator: "\n"))")
        } else {
            parts.append("Erledigte Tasks heute: keine")
        }

        // Focus-Block-Statistik
        let completedBlocks = todayBlocks.filter { !$0.completedTaskIDs.isEmpty }.count
        let totalBlocks = todayBlocks.count
        if totalBlocks > 0 {
            parts.append("Focus-Blocks: \(completedBlocks) von \(totalBlocks) bearbeitet")
        }

        return parts.joined(separator: "\n")
    }

    /// Sorts completed tasks so coach-relevant ones appear first.
    private func sortedByRelevance(_ tasks: [LocalTask], for coach: CoachType) -> [LocalTask] {
        tasks.sorted { a, b in
            let aRelevant = isRelevant(a, for: coach)
            let bRelevant = isRelevant(b, for: coach)
            if aRelevant != bRelevant { return aRelevant }
            return false
        }
    }

    private func isRelevant(_ task: LocalTask, for coach: CoachType) -> Bool {
        switch coach {
        case .troll:
            return task.rescheduleCount >= 2
        case .feuer:
            return task.importance == 3
        case .eule:
            return task.assignedFocusBlockID != nil || task.isNextUp
        case .golem:
            return false // All categories equally relevant
        }
    }

    private func coachGuidance(_ coach: CoachType, completedTasks: [LocalTask]) -> String {
        switch coach {
        case .troll:
            let procrastinated = completedTasks.filter { $0.rescheduleCount >= 2 }
            if procrastinated.isEmpty {
                return "Sprich die aufgeschobenen Tasks an — grummelig aber fair"
            }
            return "Lobe dass aufgeschobene Tasks erledigt wurden — trockener Humor"
        case .feuer:
            return "Beziehe dich auf die große Herausforderung — energisch und wettkampflustig"
        case .eule:
            return "Beziehe dich auf fokussiertes Arbeiten nur am Geplanten — ruhig und weise"
        case .golem:
            return balanceGuidance(completedTasks)
        }
    }

    private func balanceGuidance(_ tasks: [LocalTask]) -> String {
        let categories: [(key: String, label: String)] = [
            ("income", "Geld"),
            ("maintenance", "Pflege"),
            ("recharge", "Energie"),
            ("learning", "Lernen"),
            ("giving_back", "Geben")
        ]

        var active: [String] = []
        var missing: [String] = []

        for cat in categories {
            let count = tasks.filter { $0.taskType == cat.key }.count
            if count > 0 {
                active.append("\(cat.label) (\(count))")
            } else {
                missing.append(cat.label)
            }
        }

        var parts = ["Balance zwischen 5 Bereichen — geduldig und warmherzig."]
        if active.isEmpty {
            parts.append("Heute in keinem Bereich aktiv.")
        } else {
            parts.append("Heute aktiv: \(active.joined(separator: ", ")).")
            if !missing.isEmpty {
                parts.append("Fehlend: \(missing.joined(separator: ", ")).")
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performGeneration(
        coach: CoachType,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) async -> String? {
        do {
            let session = LanguageModelSession {
                "Du bist \(coach.displayName), ein Monster-Coach."
                coach.personality
                "Schreib 2-3 persoenliche Saetze ueber seinen heutigen Tag."
                "Regeln:"
                "- Nie toxisch positiv ('Du hast das grossartig gemacht!')"
                "- Nie schuldzuweisend ('Du haettest X tun sollen')"
                "- Bleib in deiner Persoenlichkeit"
                "- Bezieh dich auf konkrete Task-Titel wenn vorhanden"
                "- Immer auf Deutsch"
                "- Max 200 Zeichen"
            }

            let userPrompt = buildPrompt(
                coach: coach,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )

            let response = try await session.respond(
                to: userPrompt,
                generating: ReflectionText.self
            )
            let generated = response.content.text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !generated.isEmpty else { return nil }
            return String(generated.prefix(300))
        } catch {
            print("[EveningReflection] Failed: \(error)")
            return nil
        }
    }
    #endif

    private func levelDescription(_ level: FulfillmentLevel) -> String {
        switch level {
        case .fulfilled:    return "Erfuellt"
        case .partial:      return "Teilweise erfuellt"
        case .notFulfilled: return "Nicht erfuellt"
        }
    }

    private func formatTime(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return " (\(formatter.string(from: date)))"
    }
}
