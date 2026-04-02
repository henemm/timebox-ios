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

        // Cache hit (invalidate if intention changed)
        let cacheKey = "\(today)_\(intention ?? "")"
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

    // MARK: - Fallback

    static func fallback(completedTasks: [PlanItem], focusBlocks: [FocusBlock], intention: String? = nil) -> String {
        guard !completedTasks.isEmpty else {
            if let intention {
                return "Dein Vorsatz war: \(intention). Heute war anders als geplant \u{2013} das ist okay. Morgen ist ein neuer Anfang."
            }
            return "Heute war ein ruhiger Tag \u{2013} manchmal braucht es das auch. Morgen ist ein neuer Anfang mit frischer Energie."
        }

        let titles = completedTasks.prefix(3).map(\.title).joined(separator: ", ")

        if let intention {
            return "Du wolltest heute \(intention). Du hast \(titles) erledigt. Das zählt."
        }

        let count = completedTasks.count
        let focusMinutes = totalFocusMinutes(from: focusBlocks)
        var parts: [String] = []
        parts.append("Du hast heute \(count) Task\(count == 1 ? "" : "s") erledigt, darunter: \(titles).")
        if focusMinutes > 0 {
            parts.append("Du hast \(focusMinutes) Minuten fokussiert gearbeitet.")
        }
        parts.append("Gut gemacht!")
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
