import AppIntents
import SwiftData

/// Marks an existing task as completed in FocusBlox.
/// Works WITHOUT opening the app thanks to App Group shared container.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Task erledigen"
    static let description = IntentDescription("Markiert einen Task als erledigt.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var task: TaskEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        guard let uuid = UUID(uuidString: task.id) else {
            throw IntentError.taskNotFound
        }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { localTask in localTask.uuid == uuid }
        )
        guard let localTask = try context.fetch(descriptor).first else {
            throw IntentError.taskNotFound
        }

        localTask.isCompleted = true
        localTask.completedAt = Date()
        localTask.assignedFocusBlockID = nil
        localTask.isNextUp = false

        // Generate next instance for recurring tasks
        if localTask.recurrencePattern != "none" {
            RecurrenceService.createNextInstance(from: localTask, in: context)
        }

        try context.save()

        return .result(dialog: "Task '\(task.title)' erledigt.")
    }
}
