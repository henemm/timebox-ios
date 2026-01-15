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
                    .sorted { $0.rank < $1.rank }
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
        task.manualDuration = minutes
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
