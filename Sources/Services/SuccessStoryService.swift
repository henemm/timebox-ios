import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum SuccessStoryService {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Generate

    @MainActor
    static func generate(
        completedTasks: [PlanItem],
        focusBlocks: [FocusBlock],
        intention: String? = nil,
        settings: AppSettings = .shared
    ) async -> String {
        let today = isoDate(Date())

        // Cache hit (invalidate if intention or task count changed)
        let cacheKey = "\(today)_\(intention ?? "")_\(completedTasks.count)"
        if settings.cachedSuccessStoryDate == cacheKey,
           !settings.cachedSuccessStory.isEmpty {
            return settings.cachedSuccessStory
        }

        var story: String
        if isAvailable && !completedTasks.isEmpty {
            story = await generateWithAI(completedTasks: completedTasks, focusBlocks: focusBlocks, intention: intention)
                ?? fallback(completedTasks: completedTasks, focusBlocks: focusBlocks, intention: intention)
        } else {
            story = fallback(completedTasks: completedTasks, focusBlocks: focusBlocks, intention: intention)
        }

        settings.cachedSuccessStory = story
        settings.cachedSuccessStoryDate = cacheKey
        return story
    }

    // MARK: - AI Generation

    private static func generateWithAI(
        completedTasks: [PlanItem],
        focusBlocks: [FocusBlock],
        intention: String? = nil
    ) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let prompt = buildPrompt(completedTasks: completedTasks, focusBlocks: focusBlocks, intention: intention)

        do {
            let session = LanguageModelSession {
                """
                Du bist ein warmherziger Tagesbegleiter.
                Fasse den Tag des Nutzers im Licht seiner Morgen-Intention zusammen.
                Schreibe 2-3 Saetze. Nicht was fehlt, sondern was getan wurde.
                Wenn die Intention teilweise gelebt wurde: anerkennen.
                Wenn gar nicht: sanft, ohne Vorwurf.
                Antworte ausschliesslich mit dem fertigen Text.
                """
            }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Daytime Motivation

    static func daytimeMotivation(completedCount: Int, totalPlanned: Int) -> String {
        switch completedCount {
        case 0:
            if totalPlanned > 0 {
                return "Du hast \(totalPlanned) Tasks für heute geplant. Der erste Schritt ist der schwerste — aber danach kommt der Flow."
            }
            return "Dein Tag liegt noch vor dir. Schau in die Vorschläge und nimm dir eine Sache vor — mehr braucht es nicht."
        case 1:
            let remaining = totalPlanned - completedCount
            if remaining > 0 {
                return "Der Anfang ist gemacht! Noch \(remaining) Tasks offen — du bist im Rhythmus."
            }
            return "Der erste Task ist geschafft — ein guter Anfang. Was kommt als Nächstes?"
        case 2...3:
            return "\(completedCount) Tasks erledigt — du bist produktiv unterwegs. Weiter so, der Schwung ist auf deiner Seite."
        default:
            if totalPlanned > 0 && completedCount >= totalPlanned {
                return "Alles geschafft! \(completedCount) Tasks erledigt — du hast dein Tagesziel erreicht. Zeit für dich."
            }
            return "\(completedCount) Tasks erledigt — beeindruckend! Du bist heute richtig im Flow."
        }
    }

    // MARK: - Fallback

    static func fallback(completedTasks: [PlanItem], focusBlocks: [FocusBlock], intention: String? = nil) -> String {
        guard !completedTasks.isEmpty else {
            return "Heute steht noch alles offen — morgen ist ein neuer Anfang."
        }

        let count = completedTasks.count
        let focusMinutes = totalFocusMinutes(from: focusBlocks)
        let totalEstimated = completedTasks.compactMap(\.estimatedDuration).reduce(0, +)

        // Kategorien sammeln
        var categoryCounts: [String: Int] = [:]
        for task in completedTasks {
            if let cat = TaskCategory(rawValue: task.taskType) {
                categoryCounts[cat.localizedName, default: 0] += 1
            }
        }
        let categorySummary = categoryCounts
            .sorted { $0.value > $1.value }
            .map { "\($0.value)x \($0.key)" }
            .joined(separator: ", ")

        var parts: [String] = []

        // Headline
        switch count {
        case 1:
            parts.append("Eine Sache erledigt — das zählt.")
        case 2...3:
            parts.append("\(count) Tasks geschafft — solider Tag!")
        case 4...6:
            parts.append("\(count) Tasks erledigt — richtig produktiv!")
        default:
            parts.append("\(count) Tasks abgearbeitet — beeindruckend!")
        }

        // Zeit-Investment
        if totalEstimated > 0 {
            parts.append("Insgesamt \(totalEstimated) Minuten investiert.")
        }
        if focusMinutes > 0 && focusMinutes != totalEstimated {
            parts.append("\(focusMinutes) Minuten davon in fokussierter Arbeit.")
        }

        // Kategorien
        if !categorySummary.isEmpty {
            parts.append("Aufgeteilt auf: \(categorySummary).")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Prompt Building

    static func buildPrompt(completedTasks: [PlanItem], focusBlocks: [FocusBlock], intention: String? = nil) -> String {
        let taskLines = completedTasks.prefix(10).map { task in
            let category = task.taskType.isEmpty ? "allgemein" : task.taskType
            return "- \(task.title) (\(category))"
        }.joined(separator: "\n")

        let focusMinutes = totalFocusMinutes(from: focusBlocks)

        let blockades = completedTasks.filter { $0.rescheduleCount > 0 }
        let blockadeText: String
        if blockades.isEmpty {
            blockadeText = "Keine"
        } else {
            blockadeText = blockades.map(\.title).joined(separator: ", ")
        }

        let intentionLine = intention.map { "Morgen-Intention: \($0)" } ?? "Keine Intention gesetzt."

        return """
        \(intentionLine)
        Erledigte Tasks:
        \(taskLines)
        Focus-Zeit: \(focusMinutes) Minuten
        Ueberwundene Blockaden: \(blockadeText)
        """
    }

    // MARK: - Helpers

    static func totalFocusMinutes(from focusBlocks: [FocusBlock]) -> Int {
        focusBlocks.reduce(0) { $0 + $1.durationMinutes }
    }

    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
