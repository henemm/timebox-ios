import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates in-character AI pitches for coach selection cards using on-device Apple Intelligence.
/// Falls back to nil when AI is unavailable — caller uses deterministic CoachPreview.teaser instead.
@MainActor
struct CoachPitchService {

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
    struct PitchText {
        @Guide(description: "1-2 kurze Saetze in der Persoenlichkeit des Coaches. Spricht den User direkt an und bezieht sich auf konkrete Task-Titel. Auf Deutsch. Max 120 Zeichen.")
        let text: String
    }
    #endif

    // MARK: - Prompt Building (internal for testing)

    static func buildPrompt(coach: CoachType, allTasks: [PlanItem]) -> String {
        let relevant = CoachType.filterTasks(allTasks, coach: coach)
        let taskNames = relevant.prefix(3).map(\.title)

        var parts: [String] = []
        parts.append("Coach: \(coach.displayName) — \(coach.subtitle)")
        parts.append("Persönlichkeit: \(coach.personality)")

        if taskNames.isEmpty {
            parts.append("Relevante Tasks: keine gefunden")
        } else {
            parts.append("Relevante Tasks: \(taskNames.joined(separator: ", "))")
        }

        parts.append("Aufgabe: Überzeuge den User in 1-2 Sätzen, dich heute als Coach zu wählen. Bezieh dich auf die Tasks.")

        return parts.joined(separator: "\n")
    }

    // MARK: - Public API

    /// Generates an AI pitch for the given coach. Returns nil when AI is unavailable or disabled.
    static func generatePitch(coach: CoachType, allTasks: [PlanItem]) async -> String? {
        guard isAvailable else { return nil }
        guard AppSettings.shared.aiScoringEnabled else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performGeneration(coach: coach, allTasks: allTasks)
        }
        #endif
        return nil
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func performGeneration(coach: CoachType, allTasks: [PlanItem]) async -> String? {
        do {
            let session = LanguageModelSession {
                "Du bist \(coach.displayName), ein Monster-Coach."
                coach.personality
                "Schreib 1-2 kurze Saetze als Pitch, warum der User dich heute waehlen soll."
                "Regeln:"
                "- Bezieh dich auf konkrete Task-Titel wenn vorhanden"
                "- Bleib in deiner Persoenlichkeit"
                "- Immer auf Deutsch"
                "- Max 120 Zeichen"
            }

            let userPrompt = buildPrompt(coach: coach, allTasks: allTasks)

            let response = try await session.respond(
                to: userPrompt,
                generating: PitchText.self
            )
            let generated = response.content.text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !generated.isEmpty else { return nil }
            return String(generated.prefix(150))
        } catch {
            print("[CoachPitch] Failed: \(error)")
            return nil
        }
    }
    #endif
}
