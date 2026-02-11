import AppIntents
import SwiftData

// MARK: - Cycle Importance (nil → 1 → 2 → 3 → nil)

struct CycleImportanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Wichtigkeit aendern"
    static let isDiscoverable: Bool = false

    @Dependency var captureState: QuickCaptureState

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            switch captureState.importance {
            case nil: captureState.importance = 1
            case 1:   captureState.importance = 2
            case 2:   captureState.importance = 3
            case 3:   captureState.importance = nil
            default:  captureState.importance = nil
            }
        }
        return .result()
    }
}

// MARK: - Cycle Urgency (nil → not_urgent → urgent → nil)

struct CycleUrgencyIntent: AppIntent {
    static let title: LocalizedStringResource = "Dringlichkeit aendern"
    static let isDiscoverable: Bool = false

    @Dependency var captureState: QuickCaptureState

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            switch captureState.urgency {
            case nil:          captureState.urgency = "not_urgent"
            case "not_urgent": captureState.urgency = "urgent"
            case "urgent":     captureState.urgency = nil
            default:           captureState.urgency = nil
            }
        }
        return .result()
    }
}

// MARK: - Cycle Category (maintenance → income → recharge → learning → giving_back → maintenance)

struct CycleCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Kategorie aendern"
    static let isDiscoverable: Bool = false

    @Dependency var captureState: QuickCaptureState

    private static let categories = ["maintenance", "income", "recharge", "learning", "giving_back"]

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let current = captureState.taskType
            if let idx = Self.categories.firstIndex(of: current) {
                let next = (idx + 1) % Self.categories.count
                captureState.taskType = Self.categories[next]
            } else {
                captureState.taskType = "maintenance"
            }
        }
        return .result()
    }
}

// MARK: - Cycle Duration (nil → 15 → 25 → 45 → 60 → nil)

struct CycleDurationIntent: AppIntent {
    static let title: LocalizedStringResource = "Dauer aendern"
    static let isDiscoverable: Bool = false

    @Dependency var captureState: QuickCaptureState

    private static let durations: [Int?] = [nil, 15, 25, 45, 60]

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let current = captureState.estimatedDuration
            if let idx = Self.durations.firstIndex(where: { $0 == current }) {
                let next = (idx + 1) % Self.durations.count
                captureState.estimatedDuration = Self.durations[next]
            } else {
                captureState.estimatedDuration = nil
            }
        }
        return .result()
    }
}

// MARK: - Save Task

struct SaveQuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Task speichern"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Titel")
    var taskTitle: String

    @Dependency var captureState: QuickCaptureState

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let (importance, duration, urgency, taskType) = await MainActor.run {
            let vals = (captureState.importance, captureState.estimatedDuration, captureState.urgency, captureState.taskType)
            captureState.reset()
            return vals
        }

        let task = LocalTask(
            title: taskTitle,
            importance: importance,
            estimatedDuration: duration,
            urgency: urgency,
            taskType: taskType
        )

        context.insert(task)
        try context.save()

        return .result(dialog: "Task '\(taskTitle)' erstellt.")
    }
}

extension SaveQuickCaptureIntent {
    init(taskTitle: String) {
        self.taskTitle = taskTitle
    }
}
