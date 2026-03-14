import SwiftUI

/// The 4 Monster Coaches — each with a clear personality and task selection strategy.
/// Replaces the old 6-option IntentionOption system.
enum CoachType: String, Codable, CaseIterable {
    case troll    // "Der Aufräumer" — Konsequenz
    case feuer    // "Der Herausforderer" — Mut
    case eule     // "Der Fokussierer" — Fokus
    case golem    // "Der Balancer" — Ausdauer/Balance

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .troll: "Troll"
        case .feuer: "Feuer"
        case .eule: "Eule"
        case .golem: "Golem"
        }
    }

    var subtitle: String {
        switch self {
        case .troll: "Der Aufräumer"
        case .feuer: "Der Herausforderer"
        case .eule: "Der Fokussierer"
        case .golem: "Der Balancer"
        }
    }

    var shortPitch: String {
        switch self {
        case .troll: "Aufgeschobenes endlich anpacken"
        case .feuer: "Die große Herausforderung suchen"
        case .eule: "Nur das Geplante, nichts anderes"
        case .golem: "Alle Lebensbereiche im Blick"
        }
    }

    var icon: String {
        switch self {
        case .troll: "arrow.trianglehead.counterclockwise"
        case .feuer: "flame"
        case .eule: "scope"
        case .golem: "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .troll: .green
        case .feuer: .red
        case .eule: .blue
        case .golem: .gray
        }
    }

    var monsterImage: String {
        switch self {
        case .troll: "monsterKonsequenz"
        case .feuer: "monsterMut"
        case .eule: "monsterFokus"
        case .golem: "monsterAusdauer"
        }
    }

    /// Maps to the existing Discipline for visual classification.
    var discipline: Discipline {
        switch self {
        case .troll: .konsequenz
        case .feuer: .mut
        case .eule: .fokus
        case .golem: .ausdauer
        }
    }

    /// AI personality description for morning text generation.
    var personality: String {
        switch self {
        case .troll:
            return "Du bist ein grummeliger aber fairer Coach. Direkt, kein Blatt vor dem Mund, trockener Humor. Wie ein strenger Großvater. Du siehst genau, was aufgeschoben wird, und sagst es offen."
        case .feuer:
            return "Du bist energisch, ungeduldig und wettkampflustig. Wie ein Sport-Coach. Kleine Aufgaben langweilen dich. Du wirst aufgeregt bei großen Herausforderungen."
        case .eule:
            return "Du bist ruhig, weise und beobachtend. Wie eine Meditationslehrerin. Du siehst wenn jemand sich verzettelt. Du schätzt Tiefe über Breite. Leicht philosophisch."
        case .golem:
            return "Du bist geduldig, warmherzig und bedächtig. Wie ein alter Wanderbegleiter. Du siehst das große Bild des Lebens. Du merkst sofort wenn ein Bereich zu kurz kommt."
        }
    }

    // MARK: - Task Filtering

    /// Filters tasks relevant for this coach type.
    static func filterTasks(_ tasks: [PlanItem], coach: CoachType) -> [PlanItem] {
        let incomplete = tasks.filter { !$0.isCompleted && !$0.isTemplate }
        switch coach {
        case .troll:
            return filterTroll(incomplete)
        case .feuer:
            return filterFeuer(incomplete)
        case .eule:
            return filterEule(incomplete)
        case .golem:
            return filterGolem(incomplete)
        }
    }

    /// Troll: Procrastinated tasks — rescheduleCount >= 2 OR createdAt > 14 days OR overdue dueDate.
    /// Sorted by highest rescheduleCount first, then oldest tasks.
    private static func filterTroll(_ tasks: [PlanItem]) -> [PlanItem] {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let now = Date()

        return tasks.filter { task in
            task.rescheduleCount >= 2
                || task.createdAt < fourteenDaysAgo
                || (task.dueDate != nil && task.dueDate! < now)
        }
        .sorted { a, b in
            if a.rescheduleCount != b.rescheduleCount {
                return a.rescheduleCount > b.rescheduleCount
            }
            return a.createdAt < b.createdAt
        }
    }

    /// Feuer: Big challenges — importance == 3 OR estimatedDuration >= 60 OR aiEnergyLevel == "high".
    /// Sorted by highest importance first, then longest estimated duration.
    private static func filterFeuer(_ tasks: [PlanItem]) -> [PlanItem] {
        tasks.filter { task in
            task.importance == 3
                || (task.estimatedDuration ?? 0) >= 60
                || task.aiEnergyLevel == "high"
        }
        .sorted { a, b in
            let impA = a.importance ?? 0
            let impB = b.importance ?? 0
            if impA != impB { return impA > impB }
            return (a.estimatedDuration ?? 0) > (b.estimatedDuration ?? 0)
        }
    }

    /// Eule: Only planned tasks — isNextUp == true, max 3 tasks.
    /// Sorted by nextUpSortOrder (existing order).
    private static func filterEule(_ tasks: [PlanItem]) -> [PlanItem] {
        Array(
            tasks.filter { $0.isNextUp }
                .sorted { a, b in
                    (a.nextUpSortOrder ?? Int.max) < (b.nextUpSortOrder ?? Int.max)
                }
                .prefix(3)
        )
    }

    /// Golem: Tasks from the least represented taskType category.
    /// Sorted by priorityScore within the selected category.
    private static func filterGolem(_ tasks: [PlanItem]) -> [PlanItem] {
        let categoryCounts = Dictionary(grouping: tasks, by: { $0.taskType })
            .mapValues { $0.count }

        guard let leastCategory = categoryCounts
            .filter({ !$0.key.isEmpty })
            .min(by: { $0.value < $1.value })?
            .key else {
            return tasks.sorted { $0.priorityScore > $1.priorityScore }
        }

        return tasks.filter { $0.taskType == leastCategory }
            .sorted { $0.priorityScore > $1.priorityScore }
    }
}

// MARK: - Daily Coach Selection

/// Stores the selected coach for a given day. Replaces DailyIntention.
struct DailyCoachSelection: Codable, Equatable {
    var date: String
    var coach: CoachType?

    var isSet: Bool { coach != nil }

    // MARK: - App Group

    private static let appGroupID = "group.com.henning.focusblox"

    private static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Persistence

    func save() {
        let storageKey = "dailyCoach_\(date)"
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.appGroupDefaults.set(data, forKey: storageKey)

        // Also write to AppStorage key for views
        UserDefaults.standard.set(coach?.rawValue ?? "", forKey: "selectedCoach")
    }

    static func load() -> DailyCoachSelection {
        let storageKey = todayKey()
        let defaults = appGroupDefaults

        if let data = defaults.data(forKey: storageKey),
           let selection = try? JSONDecoder().decode(DailyCoachSelection.self, from: data) {
            return selection
        }

        return DailyCoachSelection(date: todayDateString(), coach: nil)
    }

    static func todayKey() -> String {
        "dailyCoach_\(todayDateString())"
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
