import Foundation
import SwiftData

/// LocalTask model for Watch - must match iOS app's LocalTask exactly.
/// Same class name ensures SwiftData uses the same table in shared App Group.
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
    var recurrencePattern: String?
    var recurrenceWeekdays: [Int]
    var recurrenceMonthDay: Int?
    var taskDescription: String?
    var externalID: String?
    var sourceSystem: String
    var isNextUp: Bool
    var nextUpSortOrder: Int?

    /// String id for compatibility
    var id: String { uuid.uuidString }

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
        taskType: String = "maintenance",
        recurrencePattern: String? = nil,
        recurrenceWeekdays: [Int] = [],
        recurrenceMonthDay: Int? = nil,
        taskDescription: String? = nil,
        externalID: String? = nil,
        sourceSystem: String = "local",
        nextUpSortOrder: Int? = nil
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
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
        self.isNextUp = false
        self.nextUpSortOrder = nextUpSortOrder
    }
}
