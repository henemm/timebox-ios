import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// POC: AI-powered task splitting using Apple Foundation Models.
/// Takes a task title and generates concrete sub-task suggestions.
@MainActor
enum TaskSplitService {

    // MARK: - Structured Output

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct TaskSplitResult {
        @Guide(description: "List of 3-5 concrete, actionable sub-tasks that together complete the original task. Each sub-task should be a single clear action.")
        let subtasks: [SubTask]
    }

    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct SubTask {
        @Guide(description: "Short, actionable title for the sub-task (max 60 chars)")
        let title: String

        @Guide(description: "Estimated duration in minutes: 5, 15, 30, or 60")
        let estimatedMinutes: Int
    }
    #endif

    // MARK: - Availability

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Split

    /// Generate sub-task suggestions for a given task title.
    /// Returns an array of (title, estimatedMinutes) tuples, or empty if AI unavailable.
    static func suggestSplit(for taskTitle: String) async -> [(title: String, minutes: Int)] {
        guard isAvailable else {
            print("[TaskSplit] Apple Intelligence not available")
            return []
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await performSplit(taskTitle: taskTitle)
        }
        #endif
        return []
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func performSplit(taskTitle: String) async -> [(title: String, minutes: Int)] {
        do {
            let session = LanguageModelSession {
                "Du hilfst beim Aufteilen großer Aufgaben in kleinere, machbare Schritte."
                ""
                "Regeln:"
                "- Generiere 3-5 Sub-Tasks"
                "- Jeder Sub-Task ist eine konkrete, einzelne Aktion"
                "- Sub-Tasks zusammen ergeben die vollständige Original-Aufgabe"
                "- Titel kurz und aktionsbasiert (Verb am Anfang)"
                "- Dauer: 5, 15, 30 oder 60 Minuten"
                "- Sprache: Deutsch (wenn Original deutsch ist), sonst Englisch"
                ""
                "Beispiel:"
                "  Original: Wohnung renovieren"
                "  → Farbpalette und Materialien aussuchen (30 min)"
                "  → Farbe und Pinsel im Baumarkt kaufen (60 min)"
                "  → Möbel abdecken und Raum vorbereiten (30 min)"
                "  → Wände streichen (60 min)"
                "  → Aufräumen und Möbel zurückstellen (30 min)"
            }

            let prompt = "Teile diese Aufgabe in kleinere Schritte auf: \(taskTitle)"
            let response = try await session.respond(to: prompt, generating: TaskSplitResult.self)
            let result = response.content

            let validMinutes = [5, 15, 30, 60]
            let suggestions = result.subtasks.map { sub in
                let minutes = validMinutes.contains(sub.estimatedMinutes) ? sub.estimatedMinutes : 15
                return (title: String(sub.title.prefix(60)), minutes: minutes)
            }

            print("[TaskSplit] Generated \(suggestions.count) sub-tasks for '\(taskTitle)':")
            for (i, s) in suggestions.enumerated() {
                print("  \(i + 1). \(s.title) (\(s.minutes) min)")
            }

            return suggestions
        } catch {
            print("[TaskSplit] Failed to split '\(taskTitle)': \(error)")
            return []
        }
    }
    #endif

    // MARK: - Persist Split

    /// Creates sub-tasks from suggestions and marks the original task as completed.
    /// Returns the number of sub-tasks created.
    @discardableResult
    static func persistSplit(
        originalTaskID: String,
        suggestions: [(title: String, minutes: Int)],
        taskType: String,
        modelContext: ModelContext
    ) -> Int {
        let valid = suggestions.filter { !$0.title.isEmpty }
        guard !valid.isEmpty else { return 0 }

        for suggestion in valid {
            let newTask = LocalTask(title: suggestion.title)
            newTask.estimatedDuration = suggestion.minutes
            newTask.taskType = taskType
            newTask.parentTaskID = originalTaskID
            modelContext.insert(newTask)
        }

        if let uuid = UUID(uuidString: originalTaskID) {
            let descriptor = FetchDescriptor<LocalTask>(
                predicate: #Predicate<LocalTask> { $0.uuid == uuid }
            )
            if let original = try? modelContext.fetch(descriptor).first {
                original.isCompleted = true
                original.completedAt = Date()
                original.modifiedAt = Date()
            }
        }

        try? modelContext.save()
        return valid.count
    }
}
