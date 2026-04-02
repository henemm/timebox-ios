import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates 3 daily intention suggestions using on-device AI or static fallbacks.
@MainActor
final class IntentionSuggestionService {

    static var isAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Generate 3 intention suggestions based on tasks and calendar context.
    static func suggestions(
        topTasks: [PlanItem],
        freeMinutes: Int,
        meetingCount: Int,
        yesterdayIntention: String?
    ) async -> [String] {
        if isAIAvailable {
            let aiSuggestions = await generateWithAI(
                topTasks: topTasks,
                freeMinutes: freeMinutes,
                meetingCount: meetingCount,
                yesterdayIntention: yesterdayIntention
            )
            if let suggestions = aiSuggestions, suggestions.count >= 3 {
                return Array(suggestions.prefix(3))
            }
        }
        return fallbackSuggestions(topTasks: topTasks, freeMinutes: freeMinutes)
    }

    // MARK: - AI Generation

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct IntentionSet {
        @Guide(description: "Erste Tages-Intention: ein persönlicher Vorsatz in 3-8 Worten, z.B. 'Fokus auf das Projekt'")
        let intention1: String

        @Guide(description: "Zweite Tages-Intention: anders als die erste, 3-8 Worte")
        let intention2: String

        @Guide(description: "Dritte Tages-Intention: anders als die anderen, 3-8 Worte")
        let intention3: String
    }
    #endif

    private static func generateWithAI(
        topTasks: [PlanItem],
        freeMinutes: Int,
        meetingCount: Int,
        yesterdayIntention: String?
    ) async -> [String]? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let taskList = topTasks.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")
        let yesterdayLine = yesterdayIntention.map { "Gestrige Intention: \($0)" } ?? "Keine gestrige Intention."

        let prompt = """
        Kontext des Users:
        \(yesterdayLine)
        Freie Zeit heute: \(freeMinutes) Minuten
        Termine heute: \(meetingCount)
        Wichtigste offene Aufgaben:
        \(taskList)

        Generiere 3 verschiedene Tages-Intentionen.
        Formuliere als persönlichen Vorsatz, nicht als To-Do.
        Kurz: 3-8 Worte pro Intention.
        Beispiele: "Fokus auf das Wichtigste", "Präsent sein", "Die große Sache anpacken"
        """

        do {
            let session = LanguageModelSession {
                "Du hilfst einem User, seine Tages-Intention zu formulieren."
                "Eine Intention ist kein Task — sie beschreibt eine Haltung oder ein Ziel für den Tag."
                "Formuliere kurz, warm, persönlich. Keine Floskeln."
            }
            let response = try await session.respond(to: prompt, generating: IntentionSet.self)
            return [response.content.intention1, response.content.intention2, response.content.intention3]
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Fallback

    private static func fallbackSuggestions(topTasks: [PlanItem], freeMinutes: Int) -> [String] {
        var suggestions: [String] = []

        // Task-basierter Vorschlag
        if let topTask = topTasks.first {
            let shortTitle = String(topTask.title.prefix(30))
            suggestions.append("\(shortTitle) anpacken")
        } else {
            suggestions.append("Fokus auf das Wichtigste")
        }

        // Zeit-basierter Vorschlag
        if freeMinutes > 120 {
            suggestions.append("Einen produktiven Tag gestalten")
        } else {
            suggestions.append("Das Wichtigste in wenig Zeit schaffen")
        }

        // Dritter Vorschlag
        suggestions.append("Einen ruhigen, bewussten Tag haben")

        return suggestions
    }
}
