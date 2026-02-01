import AppIntents
import SwiftData

// MARK: - Shared ModelContainer for App Group

/// Centralized ModelContainer that uses App Group.
/// Used by both main app and Intents to share the same SwiftData database.
enum SharedModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    /// Creates a ModelContainer pointing to the App Group container.
    /// Both main app and Intents use this for shared data access.
    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])

        // Check if App Group is available
        let appGroupAvailable = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil

        let config: ModelConfiguration
        if appGroupAvailable {
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .automatic
            )
        } else {
            // Fallback for unit tests without code signing
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - App Group Migration

/// Handles one-time migration from default container to App Group container.
enum AppGroupMigration {
    private static let migrationKey = "appGroupMigrationDone"
    private static let appGroupID = "group.com.henning.focusblox"

    /// Returns true if migration has not yet been performed
    static func needsMigration() -> Bool {
        return !UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Migrates all data from default container to App Group container (if needed)
    static func migrateIfNeeded() throws {
        // Skip if already migrated
        guard needsMigration() else { return }

        // Skip if App Group not available (unsigned builds/tests)
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return
        }

        let schema = Schema([LocalTask.self, TaskMetadata.self])

        // 1. Open default container and read all data
        let defaultConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        let defaultContainer = try ModelContainer(for: schema, configurations: [defaultConfig])
        let defaultContext = ModelContext(defaultContainer)

        let taskDescriptor = FetchDescriptor<LocalTask>()
        let existingTasks = try defaultContext.fetch(taskDescriptor)

        let metadataDescriptor = FetchDescriptor<TaskMetadata>()
        let existingMetadata = try defaultContext.fetch(metadataDescriptor)

        // 2. If no data to migrate, just mark as done
        guard !existingTasks.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // 3. Open App Group container
        let appGroupContainer = try SharedModelContainer.create()
        let appGroupContext = ModelContext(appGroupContainer)

        // 4. Copy all tasks
        for task in existingTasks {
            let newTask = LocalTask(
                uuid: task.uuid,
                title: task.title,
                importance: task.importance,
                isCompleted: task.isCompleted,
                tags: task.tags,
                dueDate: task.dueDate,
                createdAt: task.createdAt,
                sortOrder: task.sortOrder,
                estimatedDuration: task.estimatedDuration,
                urgency: task.urgency,
                taskType: task.taskType,
                recurrencePattern: task.recurrencePattern,
                recurrenceWeekdays: task.recurrenceWeekdays,
                recurrenceMonthDay: task.recurrenceMonthDay,
                taskDescription: task.taskDescription,
                externalID: task.externalID,
                sourceSystem: task.sourceSystem,
                nextUpSortOrder: task.nextUpSortOrder
            )
            newTask.isNextUp = task.isNextUp
            appGroupContext.insert(newTask)
        }

        // 5. Copy all metadata
        for metadata in existingMetadata {
            let newMetadata = TaskMetadata(
                reminderID: metadata.reminderID,
                sortOrder: metadata.sortOrder
            )
            newMetadata.manualDuration = metadata.manualDuration
            appGroupContext.insert(newMetadata)
        }

        // 6. Save and mark migration as complete
        try appGroupContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
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
