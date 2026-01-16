import Foundation

// MARK: - TaskSourceData Protocol

/// Protocol for data returned by task sources.
/// Each task source can have its own data type that conforms to this protocol.
protocol TaskSourceData {
    var id: String { get }
    var title: String { get }
    var isCompleted: Bool { get }
    var priority: Int { get }
    var categoryTitle: String? { get }
    var categoryColorHex: String? { get }
    var dueDate: Date? { get }

    // MARK: - Phase 1: Enhanced Task Fields

    /// Urgency level for Eisenhower Matrix (urgent/not_urgent)
    var urgency: String { get }

    /// Task categorization type (income/maintenance/recharge)
    var taskType: String { get }

    /// Flag for recurring tasks
    var isRecurring: Bool { get }

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
        category: String?,
        dueDate: Date?,
        priority: Int,
        duration: Int?,
        urgency: String,
        taskType: String,
        isRecurring: Bool,
        description: String?
    ) async throws -> TaskData

    /// Update an existing task
    func updateTask(
        taskID: String,
        title: String?,
        category: String?,
        dueDate: Date?,
        priority: Int?,
        duration: Int?,
        urgency: String?,
        taskType: String?,
        isRecurring: Bool?,
        description: String?
    ) async throws

    /// Delete a task
    func deleteTask(taskID: String) async throws
}
