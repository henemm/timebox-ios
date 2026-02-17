import Foundation
import SwiftData

/// LocalTask model for Watch - must match iOS app's LocalTask exactly.
/// Same class name ensures SwiftData uses the same table in shared App Group.
/// Note: CloudKit requires all attributes to have default values.
@Model
final class LocalTask {
    var uuid: UUID
    var title: String
    var importance: Int?
    var isCompleted: Bool
    var tags: [String]
    var dueDate: Date?
    var createdAt: Date
    var sortOrder: Int
    var estimatedDuration: Int?
    var urgency: String?
    var taskType: String
    var recurrencePattern: String
    var recurrenceWeekdays: [Int]?
    var recurrenceMonthDay: Int?
    var recurrenceGroupID: String?
    var taskDescription: String?
    var externalID: String?
    var sourceSystem: String
    var isNextUp: Bool
    var nextUpSortOrder: Int?

    // MARK: - Fields synced from iOS (must exist for CloudKit schema parity)

    var assignedFocusBlockID: String?
    var rescheduleCount: Int
    var completedAt: Date?
    var aiScore: Int?
    var aiEnergyLevel: String?

    /// String id for compatibility
    var id: String { uuid.uuidString }

    /// Task is incomplete (missing importance, urgency, or duration)
    var isTbd: Bool {
        importance == nil || urgency == nil || estimatedDuration == nil
    }

    init(
        uuid: UUID = UUID(),
        title: String,
        importance: Int? = nil,
        isCompleted: Bool = false,
        tags: [String] = [],
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        estimatedDuration: Int? = nil,
        urgency: String? = nil,
        taskType: String = "",
        recurrencePattern: String = "none",
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        recurrenceGroupID: String? = nil,
        taskDescription: String? = nil,
        externalID: String? = nil,
        sourceSystem: String = "local",
        nextUpSortOrder: Int? = nil,
        assignedFocusBlockID: String? = nil,
        rescheduleCount: Int = 0,
        completedAt: Date? = nil,
        aiScore: Int? = nil,
        aiEnergyLevel: String? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.importance = importance
        self.isCompleted = isCompleted
        self.tags = tags
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.estimatedDuration = estimatedDuration
        self.urgency = urgency
        self.taskType = taskType
        self.recurrencePattern = recurrencePattern
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceMonthDay = recurrenceMonthDay
        self.recurrenceGroupID = recurrenceGroupID
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
        self.isNextUp = false
        self.nextUpSortOrder = nextUpSortOrder
        self.assignedFocusBlockID = assignedFocusBlockID
        self.rescheduleCount = rescheduleCount
        self.completedAt = completedAt
        self.aiScore = aiScore
        self.aiEnergyLevel = aiEnergyLevel
    }
}
