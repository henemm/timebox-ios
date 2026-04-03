# Bug: Tier-Jumping Regression (Sort Order)

## Problem
Tasks springen sofort in eine andere Sektion (z.B. von "Später" nach "Dringend") wenn ein Badge getippt wird. Der DeferredSortController friert den Score ein, aber die Tier-Zuweisung in `tasksForTierGroup` ignoriert den Freeze.

## Root Cause
`BacklogView.swift:131` — `tiers.contains($0.priorityTier)` nutzt den Live-Score statt `effectivePriorityTier(for: $0)` (frozen Score).

Eingeführt durch: Commit `5cd3357` (RW_2.4b, 2026-03-31)

## Fix
Zeile 131 in `BacklogView.swift`: `$0.priorityTier` → `effectivePriorityTier(for: $0)`

## Betroffene Dateien
- `Sources/Views/BacklogView.swift` (1 Zeile)

## Nicht betroffen
- macOS (`scoreFor()` nutzt bereits frozen Score)
- DeferredSortController (korrekt)
- Overdue/Geparkt-Sektionen (filtern nicht nach Tier)

## Acceptance Criteria
- [ ] Badge-Tap ändert Score, Task bleibt 3 Sekunden in der gleichen Sektion
- [ ] Nach 3 Sekunden animiert der Task zur neuen Sektion
- [ ] Unit Test beweist frozen Tier-Zuweisung
