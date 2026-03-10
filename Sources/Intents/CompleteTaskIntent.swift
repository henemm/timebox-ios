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

        // DEP-4b: Blocked tasks cannot be completed
        if localTask.blockerTaskID != nil {
            return .result(dialog: "Task '\(task.title)' ist blockiert und kann nicht erledigt werden.")
        }

        let taskSource = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: context)
        try syncEngine.completeTask(itemID: localTask.id)

        return .result(dialog: "Task '\(task.title)' erledigt.")
    }
}
