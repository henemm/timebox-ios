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

    /// Wendet virtuelles Recurring-Stacking auf `items` an.
    /// Berechnet "missed cycles" fuer wiederkehrende Tasks deren dueDate in der Vergangenheit liegt.
    /// Pfad A (echte Gruppierung nach recurrenceGroupID) ist deaktiviert — die Konsolidierung
    /// erfolgt jetzt per Migration (consolidateMultipleInstances), nicht mehr per View-Collapsing.
    static func apply(to items: [PlanItem]) -> [PlanItem] {
        var planItems = items

        // MARK: - Pfad B: Single-Task-Cycle-Auflauf (#279 — bug-stacking-real-data)
        // Berechnet "missed cycles" fuer einzelne wiederkehrende Tasks ohne recurrenceGroupID
        // (echte User-Daten / Bestandsdaten / aus Reminders importiert / manuell angelegt).
        // Wenn dueDate weit genug in der Vergangenheit liegt, dass mindestens 2 Cycles verpasst sind,
        // setzt stackedInstanceCount auf die Anzahl der verpassten Cycles.
        // Setzt stackedInstanceCount auf die Anzahl der verpassten Cycles.
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
