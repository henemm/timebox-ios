import Foundation
import SwiftData

@Observable
@MainActor
final class SyncEngine {
    private let taskSource: LocalTaskSource
    private let modelContext: ModelContext

    init(taskSource: LocalTaskSource, modelContext: ModelContext) {
        self.taskSource = taskSource
        self.modelContext = modelContext
    }

    func sync() async throws -> [PlanItem] {
        let tasks = try await taskSource.fetchIncompleteTasks()
        return tasks.map { PlanItem(localTask: $0) }
                    .sorted { $0.rank > $1.rank }
    }

    func syncCompletedTasks(days: Int) async throws -> [PlanItem] {
        let tasks = try await taskSource.fetchCompletedTasks(withinDays: days)
        return tasks.map { PlanItem(localTask: $0) }
                    .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func updateSortOrder(for items: [PlanItem]) throws {
        for (index, item) in items.enumerated() {
            if let task = try findTask(byID: item.id) {
                task.sortOrder = index
            }
        }
        try modelContext.save()
    }

    func updateDuration(itemID: String, minutes: Int?) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        task.estimatedDuration = minutes
        try modelContext.save()
    }

    func updateNextUp(itemID: String, isNextUp: Bool) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        task.isNextUp = isNextUp
        // Assign sort order when adding to Next Up
        if isNextUp && task.nextUpSortOrder == nil {
            task.nextUpSortOrder = Int.max  // Add to end
        } else if !isNextUp {
            task.nextUpSortOrder = nil  // Clear when removing
            task.assignedFocusBlockID = nil  // Bug 52: Clear stale block assignment
        }
        try modelContext.save()
    }

    func updateNextUpSortOrder(for items: [PlanItem]) throws {
        for (index, item) in items.enumerated() {
            if let task = try findTask(byID: item.id) {
                task.nextUpSortOrder = index
            }
        }
        try modelContext.save()
    }

    func updateTask(itemID: String, title: String, importance: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        task.title = title
        task.tags = tags
        task.taskType = taskType
        task.dueDate = dueDate
        task.taskDescription = description
        // Optional fields: nil = keep existing value (Bug 48 fix)
        if let importance { task.importance = importance }
        if let duration { task.estimatedDuration = duration }
        if let urgency { task.urgency = urgency }
        if let recurrencePattern { task.recurrencePattern = recurrencePattern }
        if let recurrenceWeekdays { task.recurrenceWeekdays = recurrenceWeekdays }
        if let recurrenceMonthDay { task.recurrenceMonthDay = recurrenceMonthDay }
        try modelContext.save()
    }

    func deleteTask(itemID: String) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        modelContext.delete(task)
        try modelContext.save()
    }

    func completeTask(itemID: String) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        task.isCompleted = true
        task.completedAt = Date()
        // Clear assignment when completing
        task.assignedFocusBlockID = nil
        task.isNextUp = false

        // Generate next instance for recurring tasks
        if task.recurrencePattern != "none" {
            RecurrenceService.createNextInstance(from: task, in: modelContext)
        }

        try modelContext.save()
    }

    func uncompleteTask(itemID: String) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        task.isCompleted = false
        task.completedAt = nil
        try modelContext.save()
    }

    func updateAssignedFocusBlock(itemID: String, focusBlockID: String?) throws {
        guard let task = try findTask(byID: itemID) else {
            return
        }
        // Track reschedules: if moving from one block to a different block
        if let oldBlock = task.assignedFocusBlockID,
           let newBlock = focusBlockID,
           oldBlock != newBlock {
            task.rescheduleCount += 1
        }
        task.assignedFocusBlockID = focusBlockID
        try modelContext.save()
    }

    private func findTask(byID id: String) throws -> LocalTask? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try modelContext.fetch(descriptor).first
    }
}
