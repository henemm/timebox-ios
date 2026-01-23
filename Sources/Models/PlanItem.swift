import Foundation

struct PlanItem: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priorityValue: Int
    var rank: Int
    var effectiveDuration: Int
    let durationSource: DurationSource

    // Enhanced task fields (Phase 2)
    let tags: [String]
    let urgency: String
    let taskType: String
    let dueDate: Date?
    let taskDescription: String?

    // Next Up staging (Phase 3)
    let isNextUp: Bool

    var priority: TaskPriority {
        TaskPriority(rawValue: priorityValue) ?? .low
    }

    init(reminder: ReminderData, metadata: TaskMetadata) {
        self.id = reminder.id
        self.title = reminder.title
        self.isCompleted = reminder.isCompleted
        self.priorityValue = reminder.priority
        self.rank = metadata.sortOrder

        let (duration, source) = Self.resolveDuration(
            manual: metadata.manualDuration,
            title: reminder.title
        )
        self.effectiveDuration = duration
        self.durationSource = source

        // Enhanced fields (defaults for Reminders integration)
        self.tags = []
        self.urgency = "not_urgent"
        self.taskType = "maintenance"
        self.dueDate = nil
        self.taskDescription = nil
        self.isNextUp = false
    }

    init(localTask: LocalTask) {
        self.id = localTask.id
        self.title = localTask.title
        self.isCompleted = localTask.isCompleted
        self.priorityValue = localTask.priority
        self.rank = localTask.sortOrder

        let (duration, source) = Self.resolveDuration(
            manual: localTask.manualDuration,
            title: localTask.title
        )
        self.effectiveDuration = duration
        self.durationSource = source

        // Enhanced fields from LocalTask
        self.tags = localTask.tags
        self.urgency = localTask.urgency
        self.taskType = localTask.taskType
        self.dueDate = localTask.dueDate
        self.taskDescription = localTask.taskDescription
        self.isNextUp = localTask.isNextUp
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
