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
    var tags: [String] = []  // Multi-select tags (e.g., ["Hausarbeit", "Recherche"])
    var dueDate: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    // MARK: - TBD Tasks (Optional Fields - keine Fake-Defaults)

    /// Importance for Eisenhower Matrix (1=Niedrig, 2=Mittel, 3=Hoch)
    /// nil = nicht gesetzt (to be defined)
    var importance: Int?

    /// Urgency level for Eisenhower Matrix (urgent/not_urgent)
    /// nil = nicht gesetzt (to be defined)
    var urgency: String?

    /// Estimated duration in minutes
    /// nil = nicht gesetzt (to be defined)
    var estimatedDuration: Int?

    /// Task is incomplete (missing importance, urgency, or duration)
    var isTbd: Bool {
        importance == nil || urgency == nil || estimatedDuration == nil
    }

    /// Task categorization type (income/maintenance/recharge/learning/giving_back)
    /// Empty string = not set (TBD concept - no defaults)
    var taskType: String = ""

    /// Recurrence pattern (none/daily/weekly/biweekly/monthly)
    var recurrencePattern: String = "none"

    /// Weekdays for weekly/biweekly recurrence (1=Mon, 2=Tue, ..., 7=Sun)
    var recurrenceWeekdays: [Int]?

    /// Day of month for monthly recurrence (1-31, or 32=last day)
    var recurrenceMonthDay: Int?

    /// Groups recurring task instances into a series (UUID string).
    /// All instances of the same recurring task share the same groupID.
    /// nil for non-recurring or legacy tasks (gets assigned on next completion).
    var recurrenceGroupID: String?

    /// Long-form description/notes for the task
    var taskDescription: String?

    /// Marks task as staged for "Next Up" (ready for assignment to Focus Blocks)
    var isNextUp: Bool = false

    /// Sort order within the Next Up section (for drag & drop reordering)
    var nextUpSortOrder: Int?

    /// ID of the Focus Block this task is assigned to (nil = not assigned)
    var assignedFocusBlockID: String?

    /// Number of times this task was rescheduled (moved to a different block)
    var rescheduleCount: Int = 0

    /// Timestamp when task was completed (for "completed in last 7 days" filter)
    var completedAt: Date?

    /// External system identifier for sync (e.g., Notion page ID)
    var externalID: String?

    /// Source system identifier (local/notion/todoist)
    var sourceSystem: String = "local"

    /// String id for TaskSourceData protocol conformance
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
        taskType: String = "",
        recurrencePattern: String = "none",
        recurrenceWeekdays: [Int]? = nil,
        recurrenceMonthDay: Int? = nil,
        recurrenceGroupID: String? = nil,
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
        self.recurrenceGroupID = recurrenceGroupID
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
        self.nextUpSortOrder = nextUpSortOrder
    }
}

// MARK: - Safe Setters (Bug 57: Prevent nil-overwrite of extended attributes)

extension LocalTask {
    /// Sets importance only if new value is non-nil or current value is nil.
    /// Prevents accidental deletion by sync/CloudKit.
    func safeSetImportance(_ value: Int?) {
        guard value != nil || importance == nil else { return }
        importance = value
    }

    /// Sets urgency only if new value is non-nil or current value is nil.
    func safeSetUrgency(_ value: String?) {
        guard value != nil || urgency == nil else { return }
        urgency = value
    }

    /// Sets estimatedDuration only if new value is non-nil or current value is nil.
    func safeSetDuration(_ value: Int?) {
        guard value != nil || estimatedDuration == nil else { return }
        estimatedDuration = value
    }

    /// Sets taskType only if new value is non-empty or current value is empty.
    func safeSetTaskType(_ value: String) {
        guard !value.isEmpty || taskType.isEmpty else { return }
        taskType = value
    }
}

// MARK: - TaskSourceData Conformance

extension LocalTask: TaskSourceData {
    // All properties already match TaskSourceData protocol
    // No additional computed properties needed
}
