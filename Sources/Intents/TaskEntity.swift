import AppIntents
import SwiftData

// MARK: - Shared ModelContainer

/// Centralized ModelContainer for SwiftData shared between app and intents.
/// Uses App Group container for data exchange between main app and Siri/Shortcuts.
enum SharedModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.henning.focusblox"),
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - TaskEntity

/// AppEntity representing a Task for use in Shortcuts and Siri.
struct TaskEntity: AppEntity {
    var id: String
    var title: String
    var importance: TaskImportanceEnum?
    var duration: Int?
    var isCompleted: Bool

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")

    var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        if let importance { parts.append(importance.rawValue) }
        if let duration { parts.append("\(duration) Min.") }
        let subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.map { "\($0)" }
        )
    }

    static let defaultQuery = TaskEntityQuery()

    init(id: String, title: String, importance: TaskImportanceEnum? = nil, duration: Int? = nil, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.importance = importance
        self.duration = duration
        self.isCompleted = isCompleted
    }

    init(from task: LocalTask) {
        self.id = task.uuid.uuidString
        self.title = task.title
        self.importance = task.importance.flatMap { TaskImportanceEnum(intValue: $0) }
        self.duration = task.estimatedDuration
        self.isCompleted = task.isCompleted
    }
}

// MARK: - EntityQuery

/// Entity query for Tasks using shared App Group container.
struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let idSet = Set(identifiers)
        let descriptor = FetchDescriptor<LocalTask>()
        let tasks = try context.fetch(descriptor)
        return tasks.filter { idSet.contains($0.uuid.uuidString) }
            .map { TaskEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let tasks = try context.fetch(descriptor)
        return tasks.prefix(10).map { TaskEntity(from: $0) }
    }
}
