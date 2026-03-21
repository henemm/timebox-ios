import Foundation
import SwiftData

// MARK: - TaskLifecycleStatus

/// Lifecycle status of a task: raw (just captured) → refined (reviewed) → active (in backlog).
/// Stored as String rawValue on LocalTask for CloudKit compatibility.
enum TaskLifecycleStatus: String, Codable, CaseIterable {
    case raw       // Gerade erfasst, nicht veredelt
    case refined   // Durch Refiner bestaetigt
    case active    // Im Backlog / Next-Up
}

/// SwiftData model for locally stored tasks.
/// Supports CloudKit sync when enabled on the ModelContainer.
/// Note: CloudKit requires all attributes to have default values.
@Model
final class LocalTask {
    #Index<LocalTask>([\.isCompleted], [\.isNextUp], [\.dueDate], [\.isTemplate])

    /// Unique identifier stored as UUID for SwiftData
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var tags: [String]?  // Multi-select tags — optional to handle NULL from SQLite/CloudKit safely
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

    /// Custom interval for recurrence (e.g. 3 = "every 3 days/weeks/months")
    /// nil or 1 = default interval. Only used with "custom" recurrencePattern.
    var recurrenceInterval: Int?

    /// Groups recurring task instances into a series (UUID string).
    /// All instances of the same recurring task share the same groupID.
    /// nil for non-recurring or legacy tasks (gets assigned on next completion).
    var recurrenceGroupID: String?

    /// Whether this task is a recurring template (mother instance).
    /// Templates represent the series and are only visible in "Wiederkehrend".
    /// Child instances (isTemplate=false) appear in Backlog/Priority when due.
    var isTemplate: Bool = false

    /// Whether this task should be visible in the backlog.
    /// Hides future-dated recurring task instances (due tomorrow or later).
    /// Non-recurring tasks and recurring tasks without dueDate are always visible.
    var isVisibleInBacklog: Bool {
        if isTemplate { return false }
        guard recurrencePattern != "none" else { return true }
        guard let dueDate = dueDate else { return true }
        let startOfTomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
        return dueDate < startOfTomorrow
    }

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

    /// Manual discipline override (rawValue of Discipline enum, e.g. "mut").
    /// nil = use auto-calculation via Discipline.classifyOpen().
    var manualDiscipline: String?

    /// Timestamp when task was completed (for "completed in last 7 days" filter)
    var completedAt: Date?

    /// Timestamp when task was last modified (for "Zuletzt" sort)
    var modifiedAt: Date?

    // MARK: - Task Dependencies

    /// ID of the task that blocks this one (Finish-to-Start dependency).
    /// This task cannot be completed until the blocker is done.
    /// nil = no blocker, task is freely actionable.
    var blockerTaskID: String?

    /// Checks if setting `blockerID` as blocker of `taskID` would create a cycle.
    /// Walks the blocker chain from `blockerID` upward; if it reaches `taskID`, it's a cycle.
    static func wouldCreateCycle(settingBlocker blockerID: String, on taskID: String, allTasks: [LocalTask]) -> Bool {
        if blockerID == taskID { return true }
        let lookup = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0.blockerTaskID) })
        var current: String? = blockerID
        var visited: Set<String> = []
        while let id = current {
            if id == taskID { return true }
            if !visited.insert(id).inserted { break }  // infinite loop guard
            current = lookup[id] ?? nil
        }
        return false
    }

    // MARK: - AI Task Scoring (Apple Intelligence)

    /// AI-generated composite score (0-100, higher = more important/urgent)
    /// nil = not yet scored or AI unavailable
    var aiScore: Int?

    /// AI-assessed cognitive energy level ("high" = deep focus, "low" = routine)
    /// nil = not yet scored or AI unavailable
    var aiEnergyLevel: String?

    /// Whether this task has been scored by AI
    var hasAIScoring: Bool { aiScore != nil }

    /// Whether this task's title should be improved by TaskTitleEngine
    /// Set to true when created from Share Extension, Siri, Watch, etc.
    var needsTitleImprovement: Bool = false

    /// External system identifier for sync (e.g., Notion page ID)
    var externalID: String?

    /// Source system identifier (local/notion/todoist)
    var sourceSystem: String = "local"

    /// Source URL from Share Extension (e.g. Safari link)
    var sourceURL: String?

    /// Lifecycle status: raw (just captured) → refined (reviewed) → active (in backlog)
    /// Default "active" ensures existing tasks remain visible after migration.
    var lifecycleStatus: String = "active"

    /// String id for TaskSourceData protocol conformance
    var id: String { uuid.uuidString }

    init(
        uuid: UUID = UUID(),
        title: String,
        importance: Int? = nil,
        isCompleted: Bool = false,
        tags: [String]? = [],
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
        lifecycleStatus: String = "active"
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
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
        self.nextUpSortOrder = nextUpSortOrder
        self.lifecycleStatus = lifecycleStatus
    }
}

// MARK: - Postpone Helper (Bug 85-C)

extension LocalTask {
    /// Verschiebt das Faelligkeitsdatum um N Tage und speichert.
    /// Caller muss Notifications reschedeln (NotificationService ist nicht in allen Targets verfuegbar).
    /// No-op wenn dueDate nil ist.
    @discardableResult
    static func postpone(_ task: LocalTask, byDays days: Int, context: ModelContext) -> Date? {
        guard let currentDue = task.dueDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let targetDay = Calendar.current.date(byAdding: .day, value: days, to: today)!
        let time = Calendar.current.dateComponents([.hour, .minute, .second], from: currentDue)
        let newDue = Calendar.current.date(bySettingHour: time.hour ?? 0,
                                           minute: time.minute ?? 0,
                                           second: time.second ?? 0,
                                           of: targetDay)!
        task.dueDate = newDue
        task.modifiedAt = Date()
        task.rescheduleCount += 1
        try? context.save()
        return newDue
    }
}

// MARK: - TaskSourceData Conformance

extension LocalTask: TaskSourceData {
    // All properties already match TaskSourceData protocol
    // No additional computed properties needed
}
