import AppIntents
import SwiftData

/// Creates a new task in FocusBlox via Siri/Spotlight.
/// Saves directly to SwiftData without opening the app.
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Task erstellen"
    static let description = IntentDescription("Erstellt einen neuen Task in FocusBlox.")

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Titel")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        // Deterministic keyword extraction + title cleanup (no AI needed)
        let cleanedTitle = TaskTitleEngine.stripKeywords(taskTitle)
        let task = LocalTask(title: cleanedTitle)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: taskTitle)
        task.urgency = TaskTitleEngine.extractDeterministicUrgency(from: taskTitle)
        task.importance = TaskTitleEngine.extractDeterministicImportance(from: taskTitle)
        task.estimatedDuration = TaskTitleEngine.extractDeterministicDuration(from: taskTitle)
        // Preserve original title for reference
        task.taskDescription = taskTitle
        // Flag for deferred AI enrichment (category, energy level) on next app launch
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()
        return .result(dialog: "Task '\(cleanedTitle)' erstellt.")
    }
}

// MARK: - Intent Error

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case message(String)
    case taskNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return "\(msg)"
        case .taskNotFound:
            return "Task nicht gefunden."
        }
    }
}
