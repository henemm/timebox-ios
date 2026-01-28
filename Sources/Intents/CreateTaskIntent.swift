import AppIntents
import SwiftData

/// Creates a new task in FocusBlox using shared SwiftData container.
/// Works WITHOUT opening the app thanks to App Group shared container.
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Task erstellen"
    static let description = IntentDescription("Erstellt einen neuen Task in FocusBlox.")

    // Can work without opening app thanks to shared SwiftData container
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Titel")
    var taskTitle: String

    @Parameter(title: "Wichtigkeit", default: .medium)
    var importance: TaskImportanceEnum?

    @Parameter(title: "Dringlichkeit", default: .notUrgent)
    var urgency: TaskUrgencyEnum?

    @Parameter(title: "Dauer (Minuten)")
    var duration: Int?

    @Parameter(title: "Kategorie", default: .maintenance)
    var category: TaskCategoryEnum?

    @Parameter(title: "Faelligkeitsdatum")
    var dueDate: Date?

    @Parameter(title: "Beschreibung")
    var taskDescription: String?

    func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity> & ProvidesDialog {
        // Use shared App Group container
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let task = LocalTask(
            title: taskTitle,
            importance: importance?.intValue,
            estimatedDuration: duration,
            urgency: urgency?.stringValue,
            taskType: category?.stringValue ?? "maintenance",
            taskDescription: taskDescription
        )
        task.dueDate = dueDate

        context.insert(task)
        try context.save()

        let entity = TaskEntity(from: task)
        return .result(
            value: entity,
            dialog: "Task '\(taskTitle)' erstellt."
        )
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
