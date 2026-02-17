import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for AI-powered task scoring using Apple Intelligence (Foundation Models).
/// Completely invisible on devices without Apple Intelligence support.
@MainActor
final class AITaskScoringService {

    // MARK: - Availability

    /// Whether Apple Intelligence task scoring is available on this device.
    /// Returns false on simulator, older devices, and devices without Apple Intelligence.
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
    struct TaskScore {
        @Guide(description: "Overall priority score 0-100. Consider importance, urgency, deadline proximity, and strategic value.")
        let score: Int

        @Guide(description: "Cognitive energy: high (deep focus) or low (routine)")
        let energyLevel: String

        @Guide(description: "Suggested importance 1-3, only if task has no manual importance set")
        let suggestedImportance: Int

        @Guide(description: "Suggested urgency: true if time-critical, false if flexible")
        let suggestedUrgent: Bool
    }
    #endif

    // MARK: - Properties

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Scoring Methods

    /// Score a single task using Apple Intelligence.
    /// No-op if AI is unavailable or scoring is disabled.
    func scoreTask(_ task: LocalTask) async {
        guard Self.isAvailable else { return }
        guard UserDefaults.standard.bool(forKey: "aiScoringEnabled") else { return }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await performScoring(task)
        }
        #endif
    }

    /// Score a newly created task immediately.
    /// No-op if AI is unavailable or scoring is disabled.
    func scoreNewTask(_ task: LocalTask) async {
        await scoreTask(task)
    }

    /// Score all open (non-completed) tasks in batch.
    /// Skips tasks that were already scored today.
    func scoreAllTasks() async {
        guard Self.isAvailable else { return }
        guard UserDefaults.standard.bool(forKey: "aiScoringEnabled") else { return }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            do {
                let descriptor = FetchDescriptor<LocalTask>(
                    predicate: #Predicate { !$0.isCompleted }
                )
                let tasks = try modelContext.fetch(descriptor)

                for task in tasks {
                    await performScoring(task)
                    // Brief pause between tasks to avoid overwhelming the model
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } catch {
                print("[AIScoring] Failed to fetch tasks: \(error)")
            }
        }
        #endif
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func performScoring(_ task: LocalTask) async {
        let prompt = buildPrompt(for: task)

        do {
            let session = LanguageModelSession {
                "Du bist ein Produktivitaets-Coach. Bewerte Tasks fuer einen Knowledge Worker."
                ""
                "Score (0-100): Kombiniere Wichtigkeit, Dringlichkeit, Deadline-Naehe und strategischen Wert."
                "- 80-100: Kritisch, sofort erledigen"
                "- 60-79: Wichtig, bald einplanen"
                "- 40-59: Mittel, bei Gelegenheit"
                "- 20-39: Niedrig, irgendwann"
                "- 0-19: Kann warten"
                ""
                "Energie: high fuer tiefe Fokus-Arbeit (Programmieren, Schreiben, Analyse), low fuer Routine."
                ""
                "Vorschlaege: Schlage Wichtigkeit (1-3) und Dringlichkeit vor, basierend auf dem Kontext."
            }

            let response = try await session.respond(to: prompt, generating: TaskScore.self)
            let result = response.content

            // Apply score (clamped to valid range)
            task.aiScore = max(0, min(100, result.score))

            // Validate and apply energy level
            let validEnergy = result.energyLevel.lowercased()
            task.aiEnergyLevel = (validEnergy == "high" || validEnergy == "low") ? validEnergy : "low"

            // Apply suggestions ONLY for TBD tasks (manual values take precedence)
            if task.importance == nil {
                task.importance = max(1, min(3, result.suggestedImportance))
            }
            if task.urgency == nil {
                task.urgency = result.suggestedUrgent ? "urgent" : "not_urgent"
            }

            try modelContext.save()
        } catch {
            print("[AIScoring] Failed to score task '\(task.title)': \(error)")
        }
    }
    #endif

    /// Build a prompt string from task properties for the AI model.
    private func buildPrompt(for task: LocalTask) -> String {
        var parts: [String] = []
        parts.append("Task: \(task.title)")

        if !task.taskType.isEmpty {
            parts.append("Kategorie: \(task.taskType)")
        }
        if !task.tags.isEmpty {
            parts.append("Tags: \(task.tags.joined(separator: ", "))")
        }
        if let dueDate = task.dueDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: dueDate, relativeTo: Date())
            parts.append("Frist: \(relative)")
        }
        if let description = task.taskDescription, !description.isEmpty {
            parts.append("Beschreibung: \(description)")
        }
        if let importance = task.importance {
            parts.append("Manuelle Wichtigkeit: \(importance)/3")
        }
        if let urgency = task.urgency {
            parts.append("Manuelle Dringlichkeit: \(urgency)")
        }

        return parts.joined(separator: "\n")
    }
}
