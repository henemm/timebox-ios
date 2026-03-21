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
        let task = LocalTask(title: taskTitle)
        task.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        // Bug 97: Deterministic date extraction from title keywords (no AI needed)
        task.dueDate = TaskTitleEngine.extractDeterministicDueDate(from: taskTitle)
        // Flag for deferred AI title cleanup on next app launch
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()
        return .result(dialog: "Task '\(taskTitle)' erstellt.")
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
