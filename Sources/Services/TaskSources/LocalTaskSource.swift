import Foundation
import SwiftData

/// TaskSource implementation for locally stored tasks using SwiftData.
/// Supports CloudKit sync when enabled on the ModelContainer.
@MainActor
final class LocalTaskSource: @preconcurrency TaskSource, @preconcurrency TaskSourceWritable {
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

        // Hide recurring tasks with future dueDate (uses shared filter on LocalTask)
        return allIncomplete.filter { $0.isVisibleInBacklog }
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
    }

    func markIncomplete(taskID: String) async throws {
        guard let task = try findTask(byID: taskID) else { return }
        task.isCompleted = false
        try modelContext.save()
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
        description: String? = nil
    ) async throws -> LocalTask {
        let nextSortOrder = try await getNextSortOrder()

        let task = LocalTask(
            title: title,
            importance: importance,
            tags: tags,
            dueDate: dueDate,
            sortOrder: nextSortOrder,
            estimatedDuration: estimatedDuration,
            urgency: urgency,
            taskType: taskType,
            recurrencePattern: recurrencePattern,
            recurrenceWeekdays: recurrenceWeekdays,
            recurrenceMonthDay: recurrenceMonthDay,
            taskDescription: description,
            sourceSystem: "local"
        )
        modelContext.insert(task)
        try modelContext.save()
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

        if let title = title {
            task.title = title
        }
        if let tags = tags {
            task.tags = tags
        }
        if let dueDate = dueDate {
            task.dueDate = dueDate
        }
        if let importance = importance {
            task.importance = importance
        }
        if let estimatedDuration = estimatedDuration {
            task.estimatedDuration = estimatedDuration
        }
        if let urgency = urgency {
            task.urgency = urgency
        }
        if let taskType = taskType {
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
    }

    func deleteTask(taskID: String) async throws {
        guard let task = try findTask(byID: taskID) else { return }
        modelContext.delete(task)
        try modelContext.save()
    }

    // MARK: - Tag Suggestions

    /// Returns all unique tags used across all tasks, sorted by frequency (most used first)
    func fetchAllUsedTags() throws -> [String] {
        let descriptor = FetchDescriptor<LocalTask>()
        let allTasks = try modelContext.fetch(descriptor)

        var tagCounts: [String: Int] = [:]
        for task in allTasks {
            for tag in task.tags {
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
