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

    // MARK: - Date Helper

    /// Maps relative date strings from AI output to actual dates.
    /// Accepts both German and English variants.
    static func relativeDateFrom(_ value: String?) -> Date? {
        switch value?.lowercased() {
        case "today", "heute":    return Calendar.current.startOfDay(for: Date())
        case "tomorrow", "morgen": return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        default:                   return nil
        }
    }

    // MARK: - Structured Output

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ImprovedTask {
        @Guide(description: "Cleaned task title (max 80 chars). Keep ALL original words, names, and abbreviations exactly as they are. Only remove email artifacts (Re:, Fwd:, AW:, WG:) and urgency/deadline phrases (heute, dringend, ASAP, sofort erledigen). Start with verb in infinitive form. Keep the language of the input.")
        let title: String

        @Guide(description: "Relative due date extracted from the text. Return 'heute' if the text says heute/today/sofort, return 'morgen' if morgen/tomorrow. Otherwise return nil.")
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
                "- Beginne mit Verb im Infinitiv wenn moeglich"
                "- Behalte die Sprache des Inputs bei"
                "- Extrahiere Faelligkeit (heute/morgen) und Dringlichkeit separat"
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
