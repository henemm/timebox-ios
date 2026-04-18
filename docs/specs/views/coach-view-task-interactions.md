---
entity_id: coach-view-task-interactions
type: bug-fix
created: 2026-04-18
updated: 2026-04-18
status: draft
version: "1.0"
tags: [coach-view, task-interactions, bug-fix]
---

# Coach View — Task Interactions (Bug Fix #248)

## Approval

- [ ] Approved

## Purpose

Alle 13 Task-Interaktionen im Coach View funktionieren aktuell nicht, weil `taskWithActions()` die `BacklogRow` ohne Callbacks erstellt. Dieser Fix bringt Coach View auf Parität mit dem Backlog View, indem dieselben Handler-Patterns übernommen werden.

## Source

- **File:** `Sources/Views/CoachView.swift`
- **Identifier:** `func taskWithActions()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `BacklogRow` | view | Empfänger aller Callbacks — keine Änderung nötig, Callbacks existieren bereits |
| `BacklogView.backlogRowWithSwipe()` | function | Referenz-Implementation für Swipe + Callbacks (~Zeile 1079) |
| `BacklogView.nextUpListSection()` | function | Referenz-Implementation für Kontext-Callbacks (~Zeile 1011) |
| `DeferredCompletionController` | service | Verwaltet das 3-Sekunden-Undo-Fenster bei Checkbox-Aktionen |

## Implementation Details

**Root Cause:** `CoachView.taskWithActions()` (Zeile 822) übergibt `BacklogRow` nur `item` und `isCompletionPending`. Alle Callback-Parameter (`onComplete`, `onCancelCompletion`, `onDelete`, `onEdit`, usw.) bleiben nil/leer — die Row rendert zwar, reagiert aber nicht auf Interaktionen.

**Fix-Strategie:** `taskWithActions()` wird analog zu `BacklogView.backlogRowWithSwipe()` + `nextUpListSection()` erweitert:

1. `DeferredCompletionController` in CoachView injizieren (analog BacklogView)
2. `onComplete` — Task-Completion Handler mit Model-Update und Deferred-Controller-Trigger
3. `onCancelCompletion` — Undo-Handler über DeferredCompletionController
4. Swipe-Actions links/rechts — "Heute einplanen", Löschen, Bearbeiten
5. Kontextmenü — Verschieben, weitere Aktionen
6. Badge-Callbacks — Duration, Importance, Urgency, Category
7. `onEdit` — Edit-Sheet öffnen
8. `onDelete` — Task löschen mit Model-Context
9. Focus Sprint starten
10. Inline-Titel-Edit (Double-Tap)

**Scope-Grenze:** Nur `CoachView.swift` wird geändert (ggf. max. 1-2 weitere Dateien). `BacklogRow.swift` bleibt unverändert.

## Expected Behavior

- **Input:** Nutzer interagiert mit einem Task-Row im Coach View (Tap, Swipe, Long Press, Badge-Tap)
- **Output:** Dieselbe Reaktion wie im Backlog View — Checkbox markiert Task als erledigt, Undo-Fenster erscheint, Swipe-Aktionen funktionieren, Badges öffnen Picker, Edit-Sheet öffnet sich
- **Side effects:** Änderungen werden in SwiftData persistiert; `NotificationCenter.taskDataChanged` wird gepostet (macOS Cross-View Refresh)

## Known Limitations

- iOS und macOS sind beide betroffen (Shared Code in `Sources/`) — Fix muss auf beiden Plattformen validiert werden
- Bestehendes Verhalten in BacklogView darf nicht brechen

## Changelog

- 2026-04-18: Initial spec created — Bug #248, erweiterter Scope (alle 13 Interaktionen)
