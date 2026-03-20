import SwiftUI

/// Options for the daily morning intention question.
enum IntentionOption: String, Codable, CaseIterable {
    case survival
    case fokus
    case bhag
    case balance
    case growth
    case connection

    var label: String {
        switch self {
        case .survival: "Egal, Tag überleben"
        case .fokus: "Nicht verzetteln"
        case .bhag: "Das große Ding anpacken"
        case .balance: "In allen Bereichen leben"
        case .growth: "Etwas Neues lernen"
        case .connection: "Für andere da sein"
        }
    }

    var icon: String {
        switch self {
        case .survival: "shield"
        case .fokus: "scope"
        case .bhag: "flame"
        case .balance: "equal"
        case .growth: "book"
        case .connection: "heart.circle"
        }
    }

    var color: Color {
        switch self {
        case .survival: .gray
        case .fokus: .blue
        case .bhag: .red
        case .balance: .green
        case .growth: .purple
        case .connection: .pink
        }
    }

}

// MARK: - Intention Filter Logic

extension IntentionOption {
    /// Determines if a task should be visible given the active intention filters.
    /// - Survival overrides everything (all tasks pass).
    /// - Empty activeOptions means no filter (all tasks pass).
    /// - Multiple options use OR logic (task passes if it matches ANY option).
    /// - Balance has no task-level filter (only changes UI grouping).
    static func matchesFilter(activeOptions: [IntentionOption], task: PlanItem) -> Bool {
        guard !activeOptions.isEmpty else { return true }
        if activeOptions.contains(.survival) { return true }

        return activeOptions.contains { option in
            switch option {
            case .survival:
                return true
            case .fokus:
                return task.isNextUp
            case .bhag:
                return task.importance == 3 || task.rescheduleCount >= 2
            case .balance:
                return true // No task-level filter — UI handles grouping
            case .growth:
                return task.taskType == "learning"
            case .connection:
                return task.taskType == "giving_back"
            }
        }
    }
}

/// Daily intention stored per day in App Group UserDefaults.
struct DailyIntention: Codable, Equatable {
    var date: String
    var selections: [IntentionOption]

    var isSet: Bool { !selections.isEmpty }

    // MARK: - App Group

    private static let appGroupID = "group.com.henning.focusblox"

    private static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Persistence

    func save(key: String? = nil) {
        let storageKey = key ?? "dailyIntention_\(date)"
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.appGroupDefaults.set(data, forKey: storageKey)
    }

    static func load(key: String? = nil) -> DailyIntention {
        let storageKey = key ?? todayKey()
        let defaults = appGroupDefaults

        // Try App Group first
        if let data = defaults.data(forKey: storageKey),
           let intention = try? JSONDecoder().decode(DailyIntention.self, from: data) {
            return intention
        }

        // Migrate from .standard if data exists there but not in App Group
        if let standardData = UserDefaults.standard.data(forKey: storageKey),
           let intention = try? JSONDecoder().decode(DailyIntention.self, from: standardData) {
            defaults.set(standardData, forKey: storageKey)
            UserDefaults.standard.removeObject(forKey: storageKey)
            return intention
        }

        return DailyIntention(date: todayDateString(), selections: [])
    }

    static func todayKey() -> String {
        "dailyIntention_\(todayDateString())"
    }

    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
