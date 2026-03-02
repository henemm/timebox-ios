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

    // MARK: - Structured Output

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct ImprovedTitle {
        @Guide(description: "Short, actionable task title (max 80 chars). Start with verb in infinitive form. Keep the language of the input (German if German, English if English). If the title is already good, return it unchanged.")
        let title: String
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
                "Du verbesserst Task-Titel. Regeln:"
                "- Kurz und actionable (max 80 Zeichen)"
                "- Beginne mit Verb im Infinitiv (z.B. 'Antworten auf...', 'Pruefen ob...')"
                "- Entferne E-Mail-Artefakte (Re:, Fwd:, AW:, WG:)"
                "- Behalte die Sprache des Inputs bei"
                "- Wenn der Titel bereits gut ist, gib ihn unveraendert zurueck"
            }

            let prompt = "Verbessere diesen Task-Titel: \(task.title)"
            let response = try await session.respond(to: prompt, generating: ImprovedTitle.self)
            let improved = response.content.title.trimmingCharacters(in: .whitespacesAndNewlines)

            if !improved.isEmpty {
                task.title = String(improved.prefix(200))
            }
            task.needsTitleImprovement = false
            try modelContext.save()
        } catch {
            print("[TaskTitleEngine] Failed for '\(task.title)': \(error)")
        }
    }
    #endif
}
