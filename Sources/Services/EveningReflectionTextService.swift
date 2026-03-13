import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates personalized evening reflection texts using on-device AI (Foundation Models).
/// Falls back to IntentionEvaluationService.fallbackTemplate() when AI is unavailable.
/// Follows the TaskTitleEngine pattern: immediate fallback, async AI replacement.
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

    /// Generates AI text for a single intention.
    /// Returns nil when AI is unavailable or disabled — caller uses fallbackTemplate().
    func generateText(
        intention: IntentionOption,
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
                intention: intention,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )
        }
        #endif
        return nil
    }

    /// Batch: Generates AI texts for all given intentions.
    /// Returns dictionary [IntentionOption: String] — only entries where AI succeeded.
    func generateTexts(
        intentions: [IntentionOption],
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date = Date()
    ) async -> [IntentionOption: String] {
        guard Self.isAvailable else { return [:] }
        guard AppSettings.shared.aiScoringEnabled else { return [:] }

        var results: [IntentionOption: String] = [:]
        for intention in intentions {
            let level = IntentionEvaluationService.evaluateFulfillment(
                intention: intention,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            )
            if let text = await generateText(
                intention: intention,
                level: level,
                tasks: tasks,
                focusBlocks: focusBlocks,
                now: now
            ) {
                results[intention] = text
            }
        }
        return results
    }

    // MARK: - Prompt Building (internal for testing)

    func buildPrompt(
        intention: IntentionOption,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) -> String {
        let completedTasks = IntentionEvaluationService.completedToday(tasks, now: now)
        let todayBlocks = IntentionEvaluationService.focusBlocksToday(focusBlocks, now: now)

        var parts: [String] = []

        // Intention + Ergebnis
        parts.append("Intention: \(intention.label) (\(intention.rawValue))")
        parts.append("Ergebnis: \(levelDescription(level))")

        // Erledigte Tasks (max 5, mit Zeitstempel und Wichtigkeit)
        if !completedTasks.isEmpty {
            let taskLines = completedTasks.prefix(5).map { task -> String in
                let timeStr = formatTime(task.completedAt, now: now)
                let importanceStr = task.importance == 3 ? " [Wichtigkeit: hoch]" : ""
                return "- '\(task.title)'\(timeStr)\(importanceStr)"
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

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performGeneration(
        intention: IntentionOption,
        level: FulfillmentLevel,
        tasks: [LocalTask],
        focusBlocks: [FocusBlock],
        now: Date
    ) async -> String? {
        do {
            let session = LanguageModelSession {
                "Du bist ein sympathisches Monster — Trainingspartner des Users."
                "Schreib 2-3 persoenliche Saetze ueber seinen heutigen Tag."
                "Regeln:"
                "- Nie toxisch positiv ('Du hast das grossartig gemacht!')"
                "- Nie schuldzuweisend ('Du haettest X tun sollen')"
                "- Empathisch und direkt — wie ein ehrlicher Freund"
                "- Bezieh dich auf konkrete Task-Titel wenn vorhanden"
                "- Immer auf Deutsch"
                "- Max 200 Zeichen"
            }

            let userPrompt = buildPrompt(
                intention: intention,
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
