import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Central AI service for improving task titles from raw input.
/// Runs as a batch service at app start — tasks are created immediately with raw titles,
/// the engine improves them asynchronously in the background.
/// Original input is preserved in taskDescription.
@MainActor
final class TaskTitleEngine {

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Deterministic Keyword Stripping

    /// Removes known urgency/deadline keywords from task titles.
    /// Runs synchronously — no AI needed. Handles parenthesized and prefix formats.
    static func stripKeywords(_ title: String) -> String {
        var cleaned = title

        // Parenthesized keywords: "(dringend)", "(urgent)", "(ASAP)", "(sofort)"
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\(\s*(?:dringend|urgent|asap|sofort|eilig)\s*\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Prefix keywords: "dringend:", "urgent:", "ASAP:"
        cleaned = cleaned.replacingOccurrences(
            of: #"^(?:dringend|urgent|asap|sofort|eilig)\s*:\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Date Helper

    /// Maps relative date strings from AI output to actual dates.
    /// Accepts German and English variants, weekdays, and extended phrases.
    static func relativeDateFrom(_ value: String?) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        switch value?.lowercased() {
        case "today", "heute":
            return today
        case "tomorrow", "morgen":
            return cal.date(byAdding: .day, value: 1, to: today)
        case "uebermorgen", "übermorgen":
            return cal.date(byAdding: .day, value: 2, to: today)
        case "naechste woche", "nächste woche", "next week":
            return nextWeekday(2, after: today) // Monday
        case "montag", "monday":
            return nextWeekday(2, after: today)
        case "dienstag", "tuesday":
            return nextWeekday(3, after: today)
        case "mittwoch", "wednesday":
            return nextWeekday(4, after: today)
        case "donnerstag", "thursday":
            return nextWeekday(5, after: today)
        case "freitag", "friday":
            return nextWeekday(6, after: today)
        case "samstag", "saturday":
            return nextWeekday(7, after: today)
        case "sonntag", "sunday":
            return nextWeekday(1, after: today)
        default:
            return nil
        }
    }

    /// Returns the next occurrence of the given weekday (1=Sun .. 7=Sat).
    /// Always returns a future date (never today).
    private static func nextWeekday(_ weekday: Int, after date: Date) -> Date {
        let cal = Calendar.current
        let current = cal.component(.weekday, from: date)
        var daysAhead = weekday - current
        if daysAhead <= 0 { daysAhead += 7 }
        return cal.date(byAdding: .day, value: daysAhead, to: date)!
    }

    // MARK: - Structured Output

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ImprovedTask {
        @Guide(description: "Cleaned task title (max 80 chars). Keep ALL original words, names, and abbreviations exactly as they are. Remove: email artifacts (Re:, Fwd:, AW:, WG:), urgency/deadline phrases (heute, dringend, ASAP, sofort), and introductory phrases like 'Erinnere mich daran', 'Ich muss noch', 'Vergiss nicht'. The title should describe the ACTION, not the reminder. Example: 'Erinnere mich heute daran Herrn Mueller anzurufen' → 'Herrn Mueller anrufen'. Start with verb in infinitive form. Keep the language of the input.")
        let title: String

        @Guide(description: "Relative due date extracted from the text. Return 'heute' for heute/today/sofort, 'morgen' for morgen/tomorrow, 'uebermorgen' for uebermorgen/day after tomorrow, 'naechste woche' for naechste Woche/next week, or a weekday name like 'montag'/'freitag' if mentioned (e.g. 'bis Freitag' → 'freitag'). Return nil if no date mentioned.")
        let dueDateRelative: String?

        @Guide(description: "True if the text expresses urgency (heute erledigen, dringend, ASAP, sofort, urgent, exclamation marks). False otherwise.")
        let isUrgent: Bool
    }
    #endif

    // MARK: - Properties

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Improve the title of a single task if needed.
    func improveTitleIfNeeded(_ task: LocalTask) async {
        guard Self.isAvailable else { return }
        guard AppSettings.shared.aiScoringEnabled else { return }
        guard task.needsTitleImprovement else { return }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await performImprovement(task)
        }
        #endif
    }

    /// Batch: Improve all tasks with needsTitleImprovement flag.
    /// Returns the number of tasks processed.
    func improveAllPendingTitles() async -> Int {
        guard Self.isAvailable else { return 0 }
        guard AppSettings.shared.aiScoringEnabled else { return 0 }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.needsTitleImprovement && !$0.isCompleted }
        )
        guard let tasks = try? modelContext.fetch(descriptor) else { return 0 }

        var improved = 0
        for task in tasks {
            await improveTitleIfNeeded(task)
            improved += 1
            try? await Task.sleep(for: .milliseconds(500))
        }
        return improved
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performImprovement(_ task: LocalTask) async {
        // Preserve original title in description (if description is empty)
        if task.taskDescription == nil || task.taskDescription?.isEmpty == true {
            task.taskDescription = task.title
        }

        do {
            let session = LanguageModelSession {
                "Du bereinigst Task-Titel und extrahierst Metadaten. Regeln:"
                "- KEINE Woerter, Abkuerzungen oder Namen aendern — Originalwoerter beibehalten"
                "- Nur kuerzen durch Weglassen, NICHT durch Umschreiben"
                "- Entferne E-Mail-Artefakte (Re:, Fwd:, AW:, WG:)"
                "- Entferne Dringlichkeits-Hinweise aus dem Titel (heute erledigen, dringend, ASAP, sofort)"
                "- Entferne Einleitungsfloskeln: 'Erinnere mich daran', 'Ich muss noch', 'Vergiss nicht', 'Denk daran'"
                "- Extrahiere Zeitangaben aus Floskeln: 'heute', 'morgen', 'naechste Woche', 'bis Freitag', 'uebermorgen'"
                "- Der bereinigte Titel soll die AKTION beschreiben, nicht die Erinnerung"
                "- Beispiel: 'Erinnere mich heute daran Herrn Mueller anzurufen' → title='Herrn Mueller anrufen', dueDate='heute'"
                "- Beispiel: 'Ich muss morgen noch Steuern machen' → title='Steuern machen', dueDate='morgen'"
                "- Beginne mit Verb im Infinitiv wenn moeglich"
                "- Behalte die Sprache des Inputs bei"
                "- Extrahiere Faelligkeit und Dringlichkeit separat"
            }

            let prompt = "Bereinige diesen Task-Titel: \(task.title)"
            let response = try await session.respond(to: prompt, generating: ImprovedTask.self)
            let result = response.content
            let improved = result.title.trimmingCharacters(in: .whitespacesAndNewlines)

            if !improved.isEmpty {
                task.title = String(improved.prefix(200))
            }
            if task.dueDate == nil, let date = Self.relativeDateFrom(result.dueDateRelative) {
                task.dueDate = date
            }
            if task.urgency == nil, result.isUrgent {
                task.urgency = "urgent"
            }
            task.needsTitleImprovement = false
            try modelContext.save()
        } catch {
            print("[TaskTitleEngine] Failed for '\(task.title)': \(error)")
        }
    }
    #endif
}
