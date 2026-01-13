import Foundation
import SwiftData

@Observable
@MainActor
final class SyncEngine {
    private let eventKitRepo: EventKitRepository
    private let modelContext: ModelContext

    init(eventKitRepo: EventKitRepository, modelContext: ModelContext) {
        self.eventKitRepo = eventKitRepo
        self.modelContext = modelContext
    }

    func sync() async throws -> [PlanItem] {
        let reminders = try await eventKitRepo.fetchIncompleteReminders()
        let existingMetadata = try fetchAllMetadata()
        let metadataByID = Dictionary(uniqueKeysWithValues: existingMetadata.map { ($0.reminderID, $0) })
        let reminderIDs = Set(reminders.map(\.id))
        var planItems: [PlanItem] = []
        var maxSortOrder = existingMetadata.map(\.sortOrder).max() ?? -1

        for reminder in reminders {
            let reminderID = reminder.id
            let metadata: TaskMetadata
            if let existing = metadataByID[reminderID] {
                metadata = existing
            } else {
                maxSortOrder += 1
                metadata = TaskMetadata(reminderID: reminderID, sortOrder: maxSortOrder)
                modelContext.insert(metadata)
            }
            planItems.append(PlanItem(reminder: reminder, metadata: metadata))
        }

        for metadata in existingMetadata where !reminderIDs.contains(metadata.reminderID) {
            modelContext.delete(metadata)
        }

        try modelContext.save()
        return planItems.sorted { $0.rank < $1.rank }
    }

    func updateSortOrder(for items: [PlanItem]) throws {
        let allMetadata = try fetchAllMetadata()
        let metadataByID = Dictionary(uniqueKeysWithValues: allMetadata.map { ($0.reminderID, $0) })

        for (index, item) in items.enumerated() {
            if let metadata = metadataByID[item.id] {
                metadata.sortOrder = index
            }
        }

        try modelContext.save()
    }

    func updateDuration(itemID: String, minutes: Int?) throws {
        let allMetadata = try fetchAllMetadata()
        guard let metadata = allMetadata.first(where: { $0.reminderID == itemID }) else {
            return
        }
        metadata.manualDuration = minutes
        try modelContext.save()
    }

    private func fetchAllMetadata() throws -> [TaskMetadata] {
        let descriptor = FetchDescriptor<TaskMetadata>()
        return try modelContext.fetch(descriptor)
    }
}
