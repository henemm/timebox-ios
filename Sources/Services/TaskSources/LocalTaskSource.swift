import CoreSpotlight
import Foundation
import SwiftData

/// TaskSource implementation for locally stored tasks using SwiftData.
/// Supports CloudKit sync when enabled on the ModelContainer.
@MainActor
final class LocalTaskSource: @preconcurrency TaskSource, @preconcurrency TaskSourceWritable {
    /// Posted after a task is created and saved locally. BacklogView listens to refresh its list.
    nonisolated static let taskCreatedNotification = Notification.Name("LocalTaskSource.taskCreated")
    typealias TaskData = LocalTask

    // MARK: - Static Properties

    nonisolated static var sourceIdentifier: String { "local" }
    nonisolated static var displayName: String { "Lokale Tasks" }

    // MARK: - Properties

    private let modelContext: ModelContext

    nonisolated var isConfigured: Bool { true }

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - TaskSource

    func requestAccess() async throws -> Bool {
        // Local storage always has access
        return true
    }

    func fetchIncompleteTasks() async throws -> [LocalTask] {
        var descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        let allIncomplete = try modelContext.fetch(descriptor)

        // Hide recurring tasks with future dueDate and raw (uncurated) tasks
        return allIncomplete.filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }
    }

    /// Fetch ALL incomplete recurring tasks, ignoring isVisibleInBacklog.
    /// Used by the "Wiederkehrend" filter to show all recurring tasks including future-dated ones.
    func fetchIncompleteRecurringTasks() async throws -> [LocalTask] {
        var descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted && $0.recurrencePattern != "none" }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }

    func fetchCompletedTasks(withinDays days: Int) async throws -> [LocalTask] {
        // Einfaches Predicate - komplexe Date-Logik verursacht SwiftDataError
        var descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.isCompleted }
        )
        descriptor.sortBy = [SortDescriptor(\.completedAt, order: .reverse)]

        let allCompleted = try modelContext.fetch(descriptor)

        // Swift-seitiges Filtern für completedAt (vermeidet Predicate-Problem)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allCompleted.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= cutoffDate
        }
    }

    func markComplete(taskID: String) async throws {
        guard let task = try findTask(byID: taskID) else { return }
        task.isCompleted = true
        try modelContext.save()
        TaskLifecycleLogger.shared.logCompleted(taskID: task.uuid, title: task.title)
    }

    func markIncomplete(taskID: String) async throws {
        guard let task = try findTask(byID: taskID) else { return }
        task.isCompleted = false
        try modelContext.save()
        TaskLifecycleLogger.shared.logUncompleted(taskID: task.uuid, title: task.title)
    }

    // MARK: - TaskSourceWritable

    func createTask(
        title: String,
        tags: [String] = [],
        dueDate: Date? = nil,
        importance: Int? = nil,
        estimatedDuration: Int? = nil,
        urgency: String? = nil,
        taskType: String = "maintenance",
        recurrencePattern: String = "none",
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        recurrenceInterval: Int? = nil,
        description: String? = nil,
        blockerTaskID: String? = nil,
        lifecycleStatus: String = "active"
    ) async throws -> LocalTask {
        let nextSortOrder = try await getNextSortOrder()
        let cleanedTitle = TaskTitleEngine.stripKeywords(title)

        // Deterministic keyword extraction BEFORE task creation (from original title)
        let deterministicUrgency = urgency ?? TaskTitleEngine.extractDeterministicUrgency(from: title)
        let deterministicImportance = importance ?? TaskTitleEngine.extractDeterministicImportance(from: title)
        let deterministicDuration = estimatedDuration ?? TaskTitleEngine.extractDeterministicDuration(from: title)
        let deterministicDueDate = dueDate ?? TaskTitleEngine.extractDeterministicDueDate(from: title)

        let task = LocalTask(
            title: cleanedTitle,
            importance: deterministicImportance,
            tags: tags.map { $0.lowercased() },
            dueDate: deterministicDueDate,
            sortOrder: nextSortOrder,
            estimatedDuration: deterministicDuration,
            urgency: deterministicUrgency,
            taskType: taskType,
            recurrencePattern: recurrencePattern,
            recurrenceWeekdays: recurrenceWeekdays,
            recurrenceMonthDay: recurrenceMonthDay,
            recurrenceInterval: recurrenceInterval,
            taskDescription: description,
            sourceSystem: "local"
        )
        task.blockerTaskID = blockerTaskID
        task.lifecycleStatus = lifecycleStatus
        modelContext.insert(task)
        try modelContext.save()

        // AI enrichment: fill REMAINING missing attributes (importance, urgency, taskType, energyLevel)
        // Deterministic values from keywords take precedence — AI only fills nil/empty fields
        let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
        let preImportance = task.importance
        let preUrgency = task.urgency
        let preTaskType = task.taskType
        await enrichment.enrichTask(task)

        // Log enrichment changes
        var enrichChanges: [FieldChange] = []
        if task.importance != preImportance {
            enrichChanges.append(FieldChange(field: "importance", oldValue: preImportance.map(String.init) ?? "nil", newValue: task.importance.map(String.init) ?? "nil"))
        }
        if task.urgency != preUrgency {
            enrichChanges.append(FieldChange(field: "urgency", oldValue: preUrgency ?? "nil", newValue: task.urgency ?? "nil"))
        }
        if task.taskType != preTaskType {
            enrichChanges.append(FieldChange(field: "taskType", oldValue: preTaskType, newValue: task.taskType))
        }
        if !enrichChanges.isEmpty {
            TaskLifecycleLogger.shared.logEnriched(taskID: task.uuid, changes: enrichChanges)
        }

        // Title improvement: deterministic cleanup + AI suggestions for category/duration
        task.needsTitleImprovement = true
        let titleEngine = TaskTitleEngine(modelContext: modelContext)
        await titleEngine.improveTitleIfNeeded(task)
        try modelContext.save()

        // Index new task in Spotlight for system-wide search (nonisolated helpers avoid actor boundary)
        if SpotlightIndexingService.shared.shouldIndex(task),
           let item = try? SpotlightIndexingService.shared.buildSearchableItem(for: task) {
            CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
        }

        // Notify observers (e.g. BacklogView) that a task was created
        NotificationCenter.default.post(name: Self.taskCreatedNotification, object: nil)
        TaskLifecycleLogger.shared.logCreated(taskID: task.uuid, title: task.title)

        return task
    }

    func updateTask(
        taskID: String,
        title: String? = nil,
        tags: [String]? = nil,
        dueDate: Date? = nil,
        importance: Int? = nil,
        estimatedDuration: Int? = nil,
        urgency: String? = nil,
        taskType: String? = nil,
        recurrencePattern: String? = nil,
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        description: String? = nil
    ) async throws {
        guard let task = try findTask(byID: taskID) else { return }

        var changes: [FieldChange] = []
        if let title = title {
            changes.append(FieldChange(field: "title", oldValue: task.title, newValue: title))
            task.title = title
        }
        if let tags = tags {
            task.tags = tags.map { $0.lowercased() }
        }
        if let dueDate = dueDate {
            task.dueDate = dueDate
        }
        if let importance = importance {
            let old = task.importance.map(String.init) ?? "nil"
            changes.append(FieldChange(field: "importance", oldValue: old, newValue: String(importance)))
            task.importance = importance
        }
        if let estimatedDuration = estimatedDuration {
            let old = task.estimatedDuration.map(String.init) ?? "nil"
            changes.append(FieldChange(field: "estimatedDuration", oldValue: old, newValue: String(estimatedDuration)))
            task.estimatedDuration = estimatedDuration
        }
        if let urgency = urgency {
            changes.append(FieldChange(field: "urgency", oldValue: task.urgency ?? "nil", newValue: urgency))
            task.urgency = urgency
        }
        if let taskType = taskType {
            changes.append(FieldChange(field: "taskType", oldValue: task.taskType, newValue: taskType))
            task.taskType = taskType
        }
        if let recurrencePattern = recurrencePattern {
            task.recurrencePattern = recurrencePattern
        }
        if let recurrenceWeekdays = recurrenceWeekdays {
            task.recurrenceWeekdays = recurrenceWeekdays
        }
        if let recurrenceMonthDay = recurrenceMonthDay {
            task.recurrenceMonthDay = recurrenceMonthDay
        }
        if let description = description {
            task.taskDescription = description
        }

        try modelContext.save()
        TaskLifecycleLogger.shared.logUpdated(taskID: task.uuid, changes: changes)
    }

    func deleteTask(taskID: String) async throws {
        guard let task = try findTask(byID: taskID) else { return }
        let uuid = task.uuid
        let title = task.title
        modelContext.delete(task)
        try modelContext.save()
        TaskLifecycleLogger.shared.logDeleted(taskID: uuid, title: title)
    }

    // MARK: - Tag Suggestions

    /// Returns all unique tags used across all tasks, sorted by frequency (most used first)
    func fetchAllUsedTags() throws -> [String] {
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try modelContext.fetch(descriptor)

        var tagCounts: [String: Int] = [:]
        for task in allTasks {
            for tag in task.tags ?? [] {
                tagCounts[tag, default: 0] += 1
            }
        }

        return tagCounts.sorted { $0.value > $1.value }.map(\.key)
    }

    // MARK: - Private Helpers

    private func findTask(byID id: String) throws -> LocalTask? {
        guard let uuid = UUID(uuidString: id) else { return nil }

        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func getNextSortOrder() async throws -> Int {
        var descriptor = FetchDescriptor<LocalTask>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder, order: .reverse)]
        descriptor.fetchLimit = 1

        let tasks = try modelContext.fetch(descriptor)
        return (tasks.first?.sortOrder ?? -1) + 1
    }
}
