import Foundation
import SwiftData

/// LocalTask model for Watch - must match iOS app's LocalTask exactly.
/// Same class name ensures SwiftData uses the same table in shared App Group.
/// Note: CloudKit requires all attributes to have default values.
@Model
final class LocalTask {
    var uuid: UUID = UUID()
    var title: String = ""
    var importance: Int?
    var isCompleted: Bool = false
    var tags: [String] = []
    var dueDate: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var estimatedDuration: Int?
    var urgency: String?
    var taskType: String = ""
    var recurrencePattern: String = "none"
    var recurrenceWeekdays: [Int]?
    var recurrenceMonthDay: Int?
    var recurrenceInterval: Int?
    var recurrenceGroupID: String?
    var isTemplate: Bool = false
    var taskDescription: String?
    var externalID: String?
    var sourceSystem: String = "local"
    var isNextUp: Bool = false
    var nextUpSortOrder: Int?

    // MARK: - Fields synced from iOS (must exist for CloudKit schema parity)

    var assignedFocusBlockID: String?
    var rescheduleCount: Int = 0
    var completedAt: Date?
    var aiScore: Int?
    var aiEnergyLevel: String?
    var needsTitleImprovement: Bool = false
    var sourceURL: String?
    var modifiedAt: Date?

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
        recurrenceInterval: Int? = nil,
        recurrenceGroupID: String? = nil,
        taskDescription: String? = nil,
        externalID: String? = nil,
        sourceSystem: String = "local",
        nextUpSortOrder: Int? = nil,
        assignedFocusBlockID: String? = nil,
        rescheduleCount: Int = 0,
        completedAt: Date? = nil,
        aiScore: Int? = nil,
        aiEnergyLevel: String? = nil,
        needsTitleImprovement: Bool = false,
        sourceURL: String? = nil,
        modifiedAt: Date? = nil
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
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceGroupID = recurrenceGroupID
        self.isTemplate = false
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
        self.needsTitleImprovement = needsTitleImprovement
        self.sourceURL = sourceURL
        self.modifiedAt = modifiedAt
    }
}
