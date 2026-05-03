import Foundation

/// Recurring-Stacking-Logik (extrahiert aus `BacklogView.applyRecurringStacking`).
///
/// Issue #302 — Counter-Stacking-Konsistenz:
/// `BacklogBadgeService.countOverdueTasks` muss dieselbe Stacking-Logik anwenden
/// wie die `BacklogView`, sonst zaehlt der Counter alle Recurring-Instanzen einzeln,
/// waehrend das Backlog sie zu einem Master kollabiert. Kern-Invariante kaputt.
///
/// Verhalten (1:1 wie `BacklogView.applyRecurringStacking`):
/// - Gruppiert nach `(recurrenceGroupID, isParked)`
/// - Repraesentant: aelteste dueDate (earliest, MIN)
/// - Setzt `stackedInstanceCount` und `stackedOldestDueDate` am Repraesentant
/// - Entfernt die uebrigen Instanzen aus der Liste
enum RecurringStackingHelper {

    /// Wendet Recurring-Stacking auf `items` an: gruppiert nach
    /// (recurrenceGroupID, isParked), waehlt das aelteste Child als Repraesentant,
    /// setzt `stackedInstanceCount` und `stackedOldestDueDate` auf den Repraesentanten
    /// und entfernt die anderen Children.
    static func apply(to items: [PlanItem]) -> [PlanItem] {
        var planItems = items
        var groups: [String: [Int]] = [:]
        for (index, item) in planItems.enumerated() {
            guard let groupID = item.recurrenceGroupID,
                  !item.isTemplate,
                  !item.isCompleted,
                  !item.isNextUp else { continue }
            let key = "\(groupID)_\(item.isParked ? "parked" : "active")"
            groups[key, default: []].append(index)
        }

        var indicesToRemove: Set<Int> = []
        for (_, indices) in groups where indices.count >= 2 {
            // Repraesentant: juengstes Child (groesstes dueDate) — wie #279 fuer Tier-Konsistenz.
            let representativeIndex = indices.max { a, b in
                (planItems[a].dueDate ?? .distantPast) < (planItems[b].dueDate ?? .distantPast)
            } ?? indices[0]

            planItems[representativeIndex].stackedInstanceCount = indices.count
            planItems[representativeIndex].stackedOldestDueDate = indices
                .compactMap { planItems[$0].dueDate }
                .min()
            for idx in indices where idx != representativeIndex {
                indicesToRemove.insert(idx)
            }
        }

        for idx in indicesToRemove.sorted().reversed() {
            planItems.remove(at: idx)
        }

        // MARK: - Pfad B: Single-Task-Cycle-Auflauf (#279 — bug-stacking-real-data)
        // Berechnet "missed cycles" fuer einzelne wiederkehrende Tasks ohne recurrenceGroupID
        // (echte User-Daten / Bestandsdaten / aus Reminders importiert / manuell angelegt).
        // Wenn dueDate weit genug in der Vergangenheit liegt, dass mindestens 2 Cycles verpasst sind,
        // setzt stackedInstanceCount auf die Anzahl der verpassten Cycles.
        // Bei bereits gestackten Items (Pfad A) wird das MAX aus beiden Werten verwendet.
        for index in planItems.indices {
            let item = planItems[index]

            // Eligible fuer Pfad B: recurring, nicht template/completed/nextUp, mit dueDate in der Vergangenheit
            guard let pattern = item.recurrencePattern,
                  pattern != "none",
                  !pattern.isEmpty,
                  !item.isTemplate,
                  !item.isCompleted,
                  !item.isNextUp,
                  let dueDate = item.dueDate else { continue }

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfDueDate = calendar.startOfDay(for: dueDate)

            // Nur ueberfaellige Tasks (dueDate < heute)
            guard startOfDueDate < startOfToday else { continue }

            let elapsedDays = calendar.dateComponents([.day], from: startOfDueDate, to: startOfToday).day ?? 0
            let cycleDays = cycleDuration(for: pattern, interval: item.recurrenceInterval)
            guard cycleDays > 0 else { continue }

            let missedCycles = (elapsedDays / cycleDays) + 1

            // Schwelle: erst ab 2 Cycles wird die Bar gezeigt
            guard missedCycles >= 2 else { continue }

            // Bei bereits gestackten Items: Maximum nehmen, sonst ueberschreiben
            let currentCount = planItems[index].stackedInstanceCount
            if missedCycles > currentCount {
                planItems[index].stackedInstanceCount = missedCycles
                // stackedOldestDueDate setzen, falls noch nicht gesetzt
                // (z.B. einzelne Task ohne Pfad A)
                if planItems[index].stackedOldestDueDate == nil {
                    planItems[index].stackedOldestDueDate = dueDate
                }
            }
        }

        return planItems
    }

    /// Cycle-Dauer in Tagen pro recurrencePattern. Pragmatisch — keine Kalenderarithmetik.
    static func cycleDuration(for pattern: String, interval: Int?) -> Int {
        let baseInterval = interval ?? 1
        switch pattern {
        case "daily":    return 1 * baseInterval
        case "weekly":   return 7 * baseInterval
        case "biweekly": return 14
        case "monthly":  return 30 * baseInterval
        case "custom":   return interval ?? 0  // Custom ohne Intervall → Pfad B inaktiv
        default:         return 0
        }
    }
}
