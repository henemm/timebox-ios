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
        settings: AppSettings = .shared
    ) async -> String {
        let today = isoDate(Date())

        // Cache hit
        if settings.cachedSuccessStoryDate == today,
           !settings.cachedSuccessStory.isEmpty {
            return settings.cachedSuccessStory
        }

        var story: String
        if isAvailable && !completedTasks.isEmpty {
            story = await generateWithAI(completedTasks: completedTasks, focusBlocks: focusBlocks)
                ?? fallback(completedTasks: completedTasks, focusBlocks: focusBlocks)
        } else {
            story = fallback(completedTasks: completedTasks, focusBlocks: focusBlocks)
        }

        settings.cachedSuccessStory = story
        settings.cachedSuccessStoryDate = today
        return story
    }

    // MARK: - AI Generation

    private static func generateWithAI(
        completedTasks: [PlanItem],
        focusBlocks: [FocusBlock]
    ) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let prompt = buildPrompt(completedTasks: completedTasks, focusBlocks: focusBlocks)

        do {
            let session = LanguageModelSession {
                """
                Du bist ein motivierender persoenlicher Assistent.
                Fasse den Tag des Nutzers positiv zusammen. Schreibe 2-4 Saetze.
                Motivierend, aber authentisch. Keine leeren Floskeln.
                Antworte ausschliesslich mit dem fertigen Text, ohne Einleitung oder Erklaerung.
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

    static func fallback(completedTasks: [PlanItem], focusBlocks: [FocusBlock]) -> String {
        guard !completedTasks.isEmpty else {
            return "Heute war ein ruhiger Tag \u{2013} manchmal braucht es das auch. Morgen ist ein neuer Anfang mit frischer Energie."
        }

        let count = completedTasks.count
        let focusMinutes = totalFocusMinutes(from: focusBlocks)
        let titles = completedTasks.prefix(3).map(\.title).joined(separator: ", ")

        var parts: [String] = []
        parts.append("Du hast heute \(count) Task\(count == 1 ? "" : "s") erledigt, darunter: \(titles).")
        if focusMinutes > 0 {
            parts.append("Du hast \(focusMinutes) Minuten fokussiert gearbeitet.")
        }
        parts.append("Gut gemacht!")

        return parts.joined(separator: " ")
    }

    // MARK: - Prompt Building

    static func buildPrompt(completedTasks: [PlanItem], focusBlocks: [FocusBlock]) -> String {
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

        return """
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
