import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates 2-3 AI-powered task idea suggestions based on existing tasks.
/// Pattern: IntentionSuggestionService (same FoundationModels approach).
@MainActor
final class TaskIdeaSuggestionService {

    static var isAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Generate task idea suggestions based on existing tasks.
    /// Returns empty array if AI is not available (no fallback dummy content).
    static func suggestions(existingTasks: [LocalTask]) async -> [String] {
        guard !existingTasks.isEmpty else { return [] }

        if isAIAvailable {
            let aiSuggestions = await generateWithAI(existingTasks: existingTasks)
            if let ideas = aiSuggestions, ideas.count >= 2 {
                return Array(ideas.prefix(3))
            }
        }
        return []
    }

    // MARK: - AI Generation

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct TaskIdeaSet {
        @Guide(description: "Erste Task-Idee: eine kurze Aufgabe in 3-7 Worten, z.B. 'Wohnung aufräumen'")
        let idea1: String

        @Guide(description: "Zweite Task-Idee: anders als die erste, 3-7 Worte")
        let idea2: String

        @Guide(description: "Dritte Task-Idee: anders als die anderen, 3-7 Worte")
        let idea3: String
    }
    #endif

    private static func generateWithAI(existingTasks: [LocalTask]) async -> [String]? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let taskTitles = existingTasks
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(10)
            .map { "- \($0.title)" }
            .joined(separator: "\n")

        let prompt = """
        Bestehende Aufgaben des Users:
        \(taskTitles)

        Schlage 3 neue, kurze Aufgaben vor die dazu passen könnten.
        Keine Duplikate der bestehenden Tasks.
        Kurz: 3-7 Worte pro Idee.
        Konkret und alltagsnah, keine Floskeln wie "Strategie überprüfen".
        """

        do {
            let session = LanguageModelSession {
                "Du hilfst einem User, neue Aufgaben-Ideen zu finden."
                "Schlage konkrete, alltagsnahe Aufgaben vor — wie Haftnotizen."
                "Kurz, beiläufig, nützlich. Keine Werbung, keine Floskeln."
            }
            let response = try await session.respond(to: prompt, generating: TaskIdeaSet.self)
            return [response.content.idea1, response.content.idea2, response.content.idea3]
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
