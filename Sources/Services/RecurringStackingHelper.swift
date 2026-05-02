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
        return planItems
    }
}
