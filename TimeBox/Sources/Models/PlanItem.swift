import Foundation

struct PlanItem: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    var rank: Int
    var effectiveDuration: Int
    let durationSource: DurationSource

    init(reminder: ReminderData, metadata: TaskMetadata) {
        self.id = reminder.id
        self.title = reminder.title
        self.isCompleted = reminder.isCompleted
        self.priority = reminder.priority
        self.rank = metadata.sortOrder

        let (duration, source) = Self.resolveDuration(
            manual: metadata.manualDuration,
            title: reminder.title
        )
        self.effectiveDuration = duration
        self.durationSource = source
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
