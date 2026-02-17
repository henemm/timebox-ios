import Foundation

struct PlanItem: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    var rank: Int
    var effectiveDuration: Int
    let durationSource: DurationSource

    // TBD Tasks (Optional Fields)
    let importance: Int?
    let urgency: String?
    let estimatedDuration: Int?

    // Enhanced task fields
    let tags: [String]
    let taskType: String
    let dueDate: Date?
    let taskDescription: String?

    // Recurrence fields
    let recurrencePattern: String?
    let recurrenceWeekdays: [Int]?
    let recurrenceMonthDay: Int?
    let recurrenceGroupID: String?

    // AI Task Scoring
    let aiScore: Int?
    let aiEnergyLevel: String?

    /// Whether this task has been scored by AI
    var hasAIScoring: Bool { aiScore != nil }

    // Next Up staging
    let isNextUp: Bool

    /// Sort order within the Next Up section (for drag & drop reordering)
    let nextUpSortOrder: Int?

    /// ID of the Focus Block this task is assigned to (nil = not assigned)
    let assignedFocusBlockID: String?

    /// Timestamp when task was completed (for "completed in last 7 days" filter)
    let completedAt: Date?

    /// Number of times this task was rescheduled
    let rescheduleCount: Int

    /// Task is incomplete (missing importance, urgency, or duration)
    var isTbd: Bool {
        importance == nil || urgency == nil || estimatedDuration == nil
    }

    /// Backwards compatibility for priority-based code
    var priority: TaskPriority {
        guard let imp = importance else { return .low }
        return TaskPriority(rawValue: imp) ?? .low
    }

    init(reminder: ReminderData, metadata: TaskMetadata) {
        self.id = reminder.id
        self.title = reminder.title
        self.isCompleted = reminder.isCompleted
        self.rank = metadata.sortOrder

        // Reminders haben keine TBD-Felder → als definiert behandeln
        self.importance = reminder.priority > 0 ? reminder.priority : nil
        self.urgency = nil  // Reminders haben keine Urgency
        self.estimatedDuration = metadata.manualDuration

        let (duration, source) = Self.resolveDuration(
            manual: metadata.manualDuration,
            title: reminder.title
        )
        self.effectiveDuration = duration
        self.durationSource = source

        // AI scoring (not available for Reminders)
        self.aiScore = nil
        self.aiEnergyLevel = nil

        // Enhanced fields (defaults for Reminders integration)
        self.tags = []
        self.taskType = ""  // Empty = TBD (not set)
        self.dueDate = nil
        self.taskDescription = nil
        self.isNextUp = false
        self.nextUpSortOrder = nil
        self.assignedFocusBlockID = nil
        self.completedAt = nil
        self.rescheduleCount = 0

        // Recurrence fields (Reminders don't have recurrence in this app)
        self.recurrencePattern = nil
        self.recurrenceWeekdays = nil
        self.recurrenceMonthDay = nil
        self.recurrenceGroupID = nil
    }

    init(localTask: LocalTask) {
        self.id = localTask.id
        self.title = localTask.title
        self.isCompleted = localTask.isCompleted
        self.rank = localTask.sortOrder

        // TBD Fields from LocalTask
        self.importance = localTask.importance
        self.urgency = localTask.urgency
        self.estimatedDuration = localTask.estimatedDuration

        let (duration, source) = Self.resolveDuration(
            manual: localTask.estimatedDuration,
            title: localTask.title
        )
        self.effectiveDuration = duration
        self.durationSource = source

        // AI scoring from LocalTask
        self.aiScore = localTask.aiScore
        self.aiEnergyLevel = localTask.aiEnergyLevel

        // Enhanced fields from LocalTask
        self.tags = localTask.tags
        self.taskType = localTask.taskType
        self.dueDate = localTask.dueDate
        self.taskDescription = localTask.taskDescription
        self.isNextUp = localTask.isNextUp
        self.nextUpSortOrder = localTask.nextUpSortOrder
        self.assignedFocusBlockID = localTask.assignedFocusBlockID
        self.completedAt = localTask.completedAt
        self.rescheduleCount = localTask.rescheduleCount

        // Recurrence fields from LocalTask
        self.recurrencePattern = localTask.recurrencePattern
        self.recurrenceWeekdays = localTask.recurrenceWeekdays
        self.recurrenceMonthDay = localTask.recurrenceMonthDay
        self.recurrenceGroupID = localTask.recurrenceGroupID
    }

    private static func resolveDuration(manual: Int?, title: String?) -> (Int, DurationSource) {
        if let manual {
            return (manual, .manual)
        }
        if let title, let parsed = parseDurationFromTitle(title) {
            return (parsed, .parsed)
        }
        return (15, .default)
    }

    private static func parseDurationFromTitle(_ title: String) -> Int? {
        let pattern = #"#(\d+)min"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                  in: title,
                  options: [],
                  range: NSRange(title.startIndex..., in: title)
              ),
              let durationRange = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return Int(title[durationRange])
    }
}

enum DurationSource: Sendable {
    case manual
    case parsed
    case `default`
}

enum TaskPriority: Int, CaseIterable, Hashable, Sendable {
    case low = 1
    case medium = 2
    case high = 3

    var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        }
    }
}
