import Foundation
import SwiftUI

/// Data for a coach's daily mission card.
struct CoachMission {
    let headline: String
    let detail: String
    let progressDone: Int
    let progressTotal: Int
    let progressLabel: String
    let isEmpty: Bool
}

/// Generates coach-specific daily missions based on real task data.
struct CoachMissionService {

    static func generateMission(coach: CoachType, allTasks: [PlanItem]) -> CoachMission {
        switch coach {
        case .troll: trollMission(allTasks)
        case .feuer: feuerMission(allTasks)
        case .eule: euleMission(allTasks)
        case .golem: golemMission(allTasks)
        }
    }

    // MARK: - Troll: Aufgeschobenes anpacken

    private static func trollMission(_ tasks: [PlanItem]) -> CoachMission {
        let open = CoachType.filterTasks(tasks, coach: .troll)
        let doneToday = completedToday(tasks).filter { matchesTrollCriteria($0) }
        let total = open.count + doneToday.count

        guard total > 0 else {
            return CoachMission(headline: "Nichts Aufgeschobenes",
                                detail: "Saubere Sache.",
                                progressDone: 0, progressTotal: 0,
                                progressLabel: "angepackt", isEmpty: true)
        }

        let detail: String
        if let top = open.first {
            let days = daysSince(top.createdAt)
            if days > 7 {
                detail = "\(top.title) liegt seit \(days) Tagen rum — pack die heute an."
            } else {
                detail = "\(top.title) schon \(top.rescheduleCount)\u{00D7} verschoben — wird Zeit."
            }
        } else {
            detail = "Alles angepackt. Weiter so."
        }

        return CoachMission(headline: "\(total) aufgeschobene\(total == 1 ? "r" : "") Task\(total == 1 ? "" : "s")",
                            detail: detail,
                            progressDone: doneToday.count, progressTotal: total,
                            progressLabel: "angepackt", isEmpty: false)
    }

    // MARK: - Feuer: Größte Herausforderung

    private static func feuerMission(_ tasks: [PlanItem]) -> CoachMission {
        let open = CoachType.filterTasks(tasks, coach: .feuer)
        let doneToday = completedToday(tasks).filter { matchesFeuerCriteria($0) }

        guard !open.isEmpty || !doneToday.isEmpty else {
            return CoachMission(headline: "Keine große Herausforderung",
                                detail: "Langweilig.",
                                progressDone: 0, progressTotal: 0,
                                progressLabel: "", isEmpty: true)
        }

        let detail: String
        if let top = open.first {
            detail = "Deine größte Herausforderung heute: \(top.title). Das wird kein Spaziergang."
        } else {
            detail = "Große Herausforderung gemeistert. Respekt."
        }

        return CoachMission(headline: open.isEmpty ? "Herausforderung gemeistert" : "1 große Herausforderung",
                            detail: detail,
                            progressDone: doneToday.isEmpty ? 0 : 1, progressTotal: 1,
                            progressLabel: doneToday.isEmpty ? "wartet noch" : "erledigt",
                            isEmpty: false)
    }

    // MARK: - Eule: Geplante Tasks

    private static func euleMission(_ tasks: [PlanItem]) -> CoachMission {
        let planned = CoachType.filterTasks(tasks, coach: .eule)
        let doneToday = completedToday(tasks).filter { $0.isNextUp }
        let total = planned.count + doneToday.count

        guard total > 0 else {
            return CoachMission(headline: "Noch nichts geplant",
                                detail: "Wähl 3 Tasks aus.",
                                progressDone: 0, progressTotal: 0,
                                progressLabel: "erledigt", isEmpty: true)
        }

        let allNames = (planned.map(\.title) + doneToday.map(\.title)).prefix(3)
        let detail = "Dein Plan für heute: \(allNames.joined(separator: ", ")). Mehr brauchst du nicht."

        return CoachMission(headline: "\(total) geplante\(total == 1 ? "r" : "") Task\(total == 1 ? "" : "s")",
                            detail: detail,
                            progressDone: doneToday.count, progressTotal: min(total, 3),
                            progressLabel: "erledigt", isEmpty: false)
    }

    // MARK: - Golem: Lebensbalance

    private static func golemMission(_ tasks: [PlanItem]) -> CoachMission {
        let incomplete = tasks.filter { !$0.isCompleted && !$0.isTemplate }
        let doneToday = completedToday(tasks)

        let allCategories = Set(incomplete.map(\.taskType) + doneToday.map(\.taskType))
            .filter { !$0.isEmpty }
        let coveredCategories = Set(doneToday.map(\.taskType)).filter { !$0.isEmpty }
        let missingCategories = allCategories.subtracting(coveredCategories)

        guard !allCategories.isEmpty else {
            return CoachMission(headline: "Keine Tasks",
                                detail: "Füge Tasks in verschiedenen Bereichen hinzu.",
                                progressDone: 0, progressTotal: 0,
                                progressLabel: "Bereiche abgedeckt", isEmpty: true)
        }

        if missingCategories.isEmpty {
            return CoachMission(headline: "Alle Bereiche abgedeckt",
                                detail: "Schöne Balance.",
                                progressDone: coveredCategories.count,
                                progressTotal: allCategories.count,
                                progressLabel: "Bereiche abgedeckt", isEmpty: true)
        }

        let dominantKey = Dictionary(grouping: doneToday, by: \.taskType)
            .max(by: { $0.value.count < $1.value.count })?.key
        let dominantName = dominantKey.flatMap { TaskCategory(rawValue: $0)?.displayName }
        let missingTask = incomplete.first { missingCategories.contains($0.taskType) }

        let detail: String
        if let dominant = dominantName, let task = missingTask {
            detail = "Bisher nur \(dominant). Du hast noch \(task.title) auf der Liste."
        } else if let task = missingTask {
            let name = TaskCategory(rawValue: task.taskType)?.displayName ?? task.taskType
            detail = "\(name) kommt zu kurz. \(task.title) wartet auf dich."
        } else {
            detail = "Schau dass alle Bereiche drankommen."
        }

        return CoachMission(headline: "\(coveredCategories.count) von \(allCategories.count) Bereichen",
                            detail: detail,
                            progressDone: coveredCategories.count,
                            progressTotal: allCategories.count,
                            progressLabel: "Bereiche abgedeckt", isEmpty: false)
    }

    // MARK: - Helpers

    private static func completedToday(_ tasks: [PlanItem]) -> [PlanItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfToday && !task.isTemplate
        }
    }

    private static func matchesTrollCriteria(_ task: PlanItem) -> Bool {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return task.rescheduleCount >= 2
            || task.createdAt < fourteenDaysAgo
            || (task.dueDate != nil && task.dueDate! < Date())
    }

    private static func matchesFeuerCriteria(_ task: PlanItem) -> Bool {
        task.importance == 3
            || (task.estimatedDuration ?? 0) >= 60
            || task.aiEnergyLevel == "high"
    }

    private static func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}
