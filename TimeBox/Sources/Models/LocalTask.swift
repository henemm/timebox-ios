import Foundation
import SwiftData

/// SwiftData model for locally stored tasks.
/// Supports CloudKit sync when enabled on the ModelContainer.
/// Note: CloudKit requires all attributes to have default values.
@Model
final class LocalTask {
    /// Unique identifier stored as UUID for SwiftData
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var priority: Int = 1  // Default: Low priority (1=Low, 2=Medium, 3=High)
    var tags: [String] = []  // Multi-select tags (e.g., ["Hausarbeit", "Recherche"])
    var dueDate: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var manualDuration: Int?

    // MARK: - Phase 1: Enhanced Task Fields

    /// Urgency level for Eisenhower Matrix (urgent/not_urgent)
    var urgency: String = "not_urgent"

    /// Task categorization type (income/maintenance/recharge)
    var taskType: String = "maintenance"

    /// Recurrence pattern (none/daily/weekly/biweekly/monthly)
    var recurrencePattern: String = "none"

    /// Weekdays for weekly/biweekly recurrence (1=Mon, 2=Tue, ..., 7=Sun)
    var recurrenceWeekdays: [Int]?

    /// Day of month for monthly recurrence (1-31, or 32=last day)
    var recurrenceMonthDay: Int?

    /// Long-form description/notes for the task
    var taskDescription: String?

    /// Marks task as staged for "Next Up" (ready for assignment to Focus Blocks)
    var isNextUp: Bool = false

    /// External system identifier for sync (e.g., Notion page ID)
    var externalID: String?

    /// Source system identifier (local/notion/todoist)
    var sourceSystem: String = "local"

    /// String id for TaskSourceData protocol conformance
    var id: String { uuid.uuidString }

    init(
        uuid: UUID = UUID(),
        title: String,
        priority: Int = 1,
        isCompleted: Bool = false,
        tags: [String] = [],
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        manualDuration: Int? = nil,
        urgency: String = "not_urgent",
        taskType: String = "maintenance",
        recurrencePattern: String = "none",
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        taskDescription: String? = nil,
        externalID: String? = nil,
        sourceSystem: String = "local"
    ) {
        self.uuid = uuid
        self.title = title
        self.priority = priority
        self.isCompleted = isCompleted
        self.tags = tags
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.manualDuration = manualDuration
        self.urgency = urgency
        self.taskType = taskType
        self.recurrencePattern = recurrencePattern
        self.recurrenceWeekdays = recurrenceWeekdays
        self.recurrenceMonthDay = recurrenceMonthDay
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
    }
}

// MARK: - TaskSourceData Conformance

extension LocalTask: TaskSourceData {
    // All properties already match TaskSourceData protocol
    // No additional computed properties needed
}
