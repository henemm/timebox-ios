# Bug: Tasks werden sofort umsortiert (Tier-Jumping Regression)

## Symptom
Wenn man auf iOS ein Badge tippt (Importance, Urgency etc.), springt der Task sofort in eine andere Sektion (z.B. von "Später" nach "Dringend"), statt 3 Sekunden an Ort und Stelle zu bleiben.

## Root Cause

**Eingeführt durch:** Commit `5cd3357` (RW_2.4b — Backlog-Sektionen-Rework, 2026-03-31)

**Zeile:** `BacklogView.swift:131`

```swift
private func tasksForTierGroup(_ tiers: [TaskPriorityScoringService.PriorityTier]) -> [PlanItem] {
    let overdueIDs = Set(overdueTasks.map(\.id))
    return backlogTasks
        .filter { !$0.isInParkdeck && !overdueIDs.contains($0.id) && tiers.contains($0.priorityTier) }
        //                                                                        ^^^^^^^^^^^^^^^^^^^^
        //                                                                        LIVE Tier (Bug!)
        .sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
        //        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        //        FROZEN Score (korrekt für Sort, aber irrelevant wenn Task schon in falscher Sektion)
}
```

**Problem:** `$0.priorityTier` nutzt `PlanItem.priorityScore` (LIVE Score). Wenn ein Badge-Tap den Score ändert, ändert sich sofort der Tier → Task springt in eine andere Sektion.

**Existierender Fix wird ignoriert:** `effectivePriorityTier(for:)` (Zeile 696-698) nutzt den frozen Score und existiert genau für diesen Zweck — wird aber in `tasksForTierGroup` NICHT aufgerufen.

```swift
// Zeile 696-698 — existiert, wird für Tier-Filterung nicht genutzt
private func effectivePriorityTier(for item: PlanItem) -> TaskPriorityScoringService.PriorityTier {
    TaskPriorityScoringService.PriorityTier.from(score: effectivePriorityScore(for: item))
}
```

## Warum hat es vorher funktioniert?

Vor RW_2.4b gab es eine **2er-Gruppierung** (Aktive Tasks + Parkdeck). Die Tier-basierte Filterung existierte nicht. RW_2.4b hat `tasksForTierGroup` eingeführt und dabei `$0.priorityTier` statt `effectivePriorityTier(for: $0)` verwendet.

## Fix

Eine Zeile ändern in `BacklogView.swift:131`:

```swift
// Vorher (Bug):
.filter { !$0.isInParkdeck && !overdueIDs.contains($0.id) && tiers.contains($0.priorityTier) }

// Nachher (Fix):
.filter { !$0.isInParkdeck && !overdueIDs.contains($0.id) && tiers.contains(effectivePriorityTier(for: $0)) }
```

## Blast Radius

- **macOS ContentView:** Muss geprüft werden ob gleicher Bug dort existiert
- **Overdue/Geparkt-Sektionen:** Nicht betroffen (filtern nicht nach Tier)
- **DeferredSortController:** Korrekt, keine Änderung nötig
- **Unit Tests:** DeferredSortControllerTests alle grün (7/7)

## Betroffene Dateien

1. `Sources/Views/BacklogView.swift` — Zeile 131 (1 Zeile ändern)
2. Ggf. `FocusBloxMac/ContentView.swift` — gleicher Bug prüfen
