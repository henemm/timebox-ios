import Foundation

// MARK: - TaskSourceData Protocol

/// Protocol for data returned by task sources.
/// Each task source can have its own data type that conforms to this protocol.
protocol TaskSourceData {
    var id: String { get }
    var title: String { get }
    var isCompleted: Bool { get }
    var importance: Int? { get }
    var tags: [String] { get }
    var dueDate: Date? { get }

    // MARK: - Phase 1: Enhanced Task Fields

    /// Urgency level for Eisenhower Matrix (urgent/not_urgent)
    /// nil = not set (TBD concept)
    var urgency: String? { get }

    /// Task categorization type (income/maintenance/recharge)
    var taskType: String { get }

    /// Recurrence pattern (none/daily/weekly/biweekly/monthly)
    var recurrencePattern: String { get }

    /// Weekdays for weekly/biweekly recurrence (1=Mon, 2=Tue, ..., 7=Sun)
    var recurrenceWeekdays: [Int]? { get }

    /// Day of month for monthly recurrence (1-31, or 32=last day)
    var recurrenceMonthDay: Int? { get }

    /// Long-form description/notes for the task
    var taskDescription: String? { get }

    /// External system identifier for sync (e.g., Notion page ID)
    var externalID: String? { get }

    /// Source system identifier (local/notion/todoist)
    var sourceSystem: String { get }
}

// MARK: - TaskSource Protocol

/// Protocol for read-only task sources.
/// Implementations can fetch tasks from various backends (local, Notion, etc.)
protocol TaskSource {
    associatedtype TaskData: TaskSourceData

    /// Unique identifier for this source type
    static var sourceIdentifier: String { get }

    /// Human-readable name for display in UI
    static var displayName: String { get }

    /// Whether the source is configured and ready to use
    var isConfigured: Bool { get }

    /// Request access to the task source (e.g., OAuth, permissions)
    func requestAccess() async throws -> Bool

    /// Fetch all incomplete tasks from this source
    func fetchIncompleteTasks() async throws -> [TaskData]

    /// Mark a task as complete
    func markComplete(taskID: String) async throws

    /// Mark a task as incomplete
    func markIncomplete(taskID: String) async throws
}

// MARK: - TaskSourceWritable Protocol

/// Protocol for task sources that support creating, updating, and deleting tasks.
protocol TaskSourceWritable: TaskSource {
    /// Create a new task
    func createTask(
        title: String,
        tags: [String],
        dueDate: Date?,
        importance: Int?,
        estimatedDuration: Int?,
        urgency: String?,
        taskType: String,
        recurrencePattern: String,
        recurrenceWeekdays: [Int]?,
        recurrenceMonthDay: Int?,
        description: String?
    ) async throws -> TaskData

    /// Update an existing task
    func updateTask(
        taskID: String,
        title: String?,
        tags: [String]?,
        dueDate: Date?,
        importance: Int?,
        estimatedDuration: Int?,
        urgency: String?,
        taskType: String?,
        recurrencePattern: String?,
        recurrenceWeekdays: [Int]?,
        recurrenceMonthDay: Int?,
        description: String?
    ) async throws

    /// Delete a task
    func deleteTask(taskID: String) async throws
}
