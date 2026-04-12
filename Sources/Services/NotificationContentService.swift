import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates personalized notification content via Foundation Models (on-device AI).
/// Falls back to static templates when AI is unavailable.
/// Pattern: SuccessStoryService (same availability gating + fallback strategy).
///
/// Psychologische Grundlagen: docs/research/psychology-daily-companion.md
/// - Morgens: Implementation Intentions (Gollwitzer) — konkrete Vorschläge, nie Anweisungen
/// - Abends: Progress Principle (Amabile) — Fortschritte sichtbar machen, nie Fehlendes bewerten
/// - Immer: SDT (Deci/Ryan) — Autonomie wahren, Fragen statt Befehle
enum NotificationContentService {

    // MARK: - Types

    struct Content {
        let title: String
        let body: String
        var suggestedTaskID: String?
    }

    // MARK: - Category

    static let dailyCompanionCategoryID = "DAILY_COMPANION"

    // MARK: - Availability

    static var isAIAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Morning Content

    @MainActor
    static func generateMorningContent(
        topTaskTitle: String,
        daysSinceCreated: Int,
        freeMinutes: Int,
        meetingCount: Int,
        suggestedTaskID: String? = nil
    ) async -> Content {
        if isAIAvailable {
            if let aiContent = await generateMorningWithAI(
                topTaskTitle: topTaskTitle,
                daysSinceCreated: daysSinceCreated,
                freeMinutes: freeMinutes,
                meetingCount: meetingCount,
                suggestedTaskID: suggestedTaskID
            ) {
                return aiContent
            }
        }
        return morningFallback(
            topTaskTitle: topTaskTitle,
            daysSinceCreated: daysSinceCreated,
            freeMinutes: freeMinutes,
            suggestedTaskID: suggestedTaskID
        )
    }

    static func morningFallback(
        topTaskTitle: String,
        daysSinceCreated: Int,
        freeMinutes: Int,
        suggestedTaskID: String? = nil
    ) -> Content {
        let body: String
        if daysSinceCreated > 7 {
            body = "\(topTaskTitle) wartet seit \(daysSinceCreated) Tagen. Du hast \(freeMinutes) Min frei heute."
        } else {
            body = "Du hast \(freeMinutes) Min frei heute. \(topTaskTitle) könnte reinpassen."
        }
        return Content(title: "Dein Tag", body: body, suggestedTaskID: suggestedTaskID)
    }

    // MARK: - Evening Content

    @MainActor
    static func generateEveningContent(
        completedTaskTitles: [String],
        focusMinutes: Int,
        hardestTaskTitle: String?,
        hardestTaskDaysOpen: Int
    ) async -> Content {
        if isAIAvailable {
            if let aiContent = await generateEveningWithAI(
                completedTaskTitles: completedTaskTitles,
                focusMinutes: focusMinutes,
                hardestTaskTitle: hardestTaskTitle,
                hardestTaskDaysOpen: hardestTaskDaysOpen
            ) {
                return aiContent
            }
        }
        return eveningFallback(
            completedTaskTitles: completedTaskTitles,
            focusMinutes: focusMinutes,
            hardestTaskTitle: hardestTaskTitle,
            hardestTaskDaysOpen: hardestTaskDaysOpen
        )
    }

    static func eveningFallback(
        completedTaskTitles: [String],
        focusMinutes: Int,
        hardestTaskTitle: String?,
        hardestTaskDaysOpen: Int
    ) -> Content {
        guard !completedTaskTitles.isEmpty else {
            return Content(
                title: "Tagesrückblick",
                body: "Heute war ein ruhiger Tag — manchmal braucht es genau das."
            )
        }

        let body: String
        if let hardest = hardestTaskTitle, hardestTaskDaysOpen > 7 {
            body = "\(hardest) erledigt — seit \(hardestTaskDaysOpen) Tagen offen. Das zählt."
        } else if completedTaskTitles.count == 1 {
            body = "\(completedTaskTitles[0]) erledigt. Gut gemacht."
        } else {
            let first = completedTaskTitles.prefix(2).joined(separator: " und ")
            body = "\(completedTaskTitles.count) Tasks erledigt, darunter \(first). Solider Tag."
        }
        return Content(title: "Tagesrückblick", body: body)
    }

    // MARK: - Prompt Building

    static func buildMorningPrompt(
        topTaskTitle: String,
        daysSinceCreated: Int,
        freeMinutes: Int,
        meetingCount: Int
    ) -> String {
        """
        Kontext:
        - Freie Zeit heute: \(freeMinutes) Minuten
        - Längst überfälliger Task: "\(topTaskTitle)" (seit \(daysSinceCreated) Tagen offen)
        - Meeting-Load: \(meetingCount) Termine
        """
    }

    static func buildEveningPrompt(
        completedTaskTitles: [String],
        focusMinutes: Int,
        hardestTaskTitle: String?,
        hardestTaskDaysOpen: Int
    ) -> String {
        let taskLines = completedTaskTitles.prefix(5).map { "- \($0)" }.joined(separator: "\n")
        let hardestLine: String
        if let hardest = hardestTaskTitle, hardestTaskDaysOpen > 0 {
            hardestLine = "Schwierigster Task: \"\(hardest)\" (seit \(hardestTaskDaysOpen) Tagen offen, heute erledigt)"
        } else {
            hardestLine = "Kein besonders schwieriger Task dabei"
        }
        return """
        Erledigte Tasks:
        \(taskLines)
        Focus-Zeit: \(focusMinutes) Minuten
        \(hardestLine)
        """
    }

    // MARK: - AI Generation (Foundation Models)

    private static let morningSystemPrompt = """
        Du bist ein ruhiger, aufmerksamer Tagesbegleiter. Formuliere eine kurze Morgen-Nachricht (max 2 Sätze).
        Nenne den konkreten Task beim Namen. Frage was der User heute anpacken will — zwinge nichts auf.
        Kein "Guten Morgen" (steht schon im Titel). Nie bewertend, nie vorwurfsvoll.
        Antworte ausschließlich mit dem fertigen Text.
        """

    private static let eveningSystemPrompt = """
        Du bist ein wohlwollender Tagesbegleiter. Formuliere einen kurzen, positiven Tagesrückblick (max 2 Sätze).
        Nenne mindestens einen konkreten Task beim Namen. Fokus auf Fortschritt, nicht auf Fehlendes.
        Ehrlich aber warm — kein toxisches Lob. Bei schwachem Tag: anerkennend, nie vorwurfsvoll.
        Antworte ausschließlich mit dem fertigen Text.
        """

    @MainActor
    private static func generateMorningWithAI(
        topTaskTitle: String,
        daysSinceCreated: Int,
        freeMinutes: Int,
        meetingCount: Int,
        suggestedTaskID: String?
    ) async -> Content? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let prompt = buildMorningPrompt(
            topTaskTitle: topTaskTitle,
            daysSinceCreated: daysSinceCreated,
            freeMinutes: freeMinutes,
            meetingCount: meetingCount
        )

        do {
            let session = LanguageModelSession { morningSystemPrompt }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Content(title: "Dein Tag", body: text, suggestedTaskID: suggestedTaskID)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    @MainActor
    private static func generateEveningWithAI(
        completedTaskTitles: [String],
        focusMinutes: Int,
        hardestTaskTitle: String?,
        hardestTaskDaysOpen: Int
    ) async -> Content? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }

        let prompt = buildEveningPrompt(
            completedTaskTitles: completedTaskTitles,
            focusMinutes: focusMinutes,
            hardestTaskTitle: hardestTaskTitle,
            hardestTaskDaysOpen: hardestTaskDaysOpen
        )

        do {
            let session = LanguageModelSession { eveningSystemPrompt }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Content(title: "Tagesrückblick", body: text)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
