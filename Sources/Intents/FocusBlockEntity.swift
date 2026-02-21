import AppIntents
import Foundation

// MARK: - FocusBlockEntity

/// AppEntity representing a FocusBlock for use in Shortcuts and Siri.
/// Unlike TaskEntity (SwiftData), FocusBlocks are calendar events
/// accessed via EventKitRepository.
struct FocusBlockEntity: AppEntity {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var durationMinutes: Int
    var taskCount: Int
    var completedTaskCount: Int

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Focus Block")

    var displayRepresentation: DisplayRepresentation {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let timeRange = "\(timeFormatter.string(from: startDate)) – \(timeFormatter.string(from: endDate))"
        let taskInfo = taskCount > 0 ? "\(completedTaskCount)/\(taskCount) Tasks" : "Keine Tasks"
        let subtitle = "\(timeRange) · \(durationMinutes) Min. · \(taskInfo)"

        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)"
        )
    }

    static let defaultQuery = FocusBlockEntityQuery()

    init(id: String, title: String, startDate: Date, endDate: Date, durationMinutes: Int, taskCount: Int = 0, completedTaskCount: Int = 0) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.taskCount = taskCount
        self.completedTaskCount = completedTaskCount
    }

    init(from block: FocusBlock) {
        self.id = block.id
        self.title = block.title
        self.startDate = block.startDate
        self.endDate = block.endDate
        self.durationMinutes = block.durationMinutes
        self.taskCount = block.taskIDs.count
        self.completedTaskCount = block.completedTaskIDs.count
    }
}

// MARK: - EntityQuery

/// Entity query for FocusBlocks using EventKitRepository.
struct FocusBlockEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FocusBlockEntity] {
        let repo = EventKitRepository()
        let idSet = Set(identifiers)
        let blocks = try repo.fetchFocusBlocks(for: Date())
        return blocks.filter { idSet.contains($0.id) }
            .map { FocusBlockEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [FocusBlockEntity] {
        let repo = EventKitRepository()
        let blocks = try repo.fetchFocusBlocks(for: Date())
        return blocks
            .sorted { $0.startDate < $1.startDate }
            .map { FocusBlockEntity(from: $0) }
    }
}
