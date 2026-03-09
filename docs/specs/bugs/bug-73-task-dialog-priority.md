# Bug 73: "Tasks im Block"-Dialog — keine Prioritaets-Info, schlechte Sortierung

## Problem
Im Dialog "Tasks im Block" (FocusBlockTasksSheet) fehlt jede Prioritaets-Information. Die "Alle Tasks"-Sektion zeigt nur Titel + Dauer. Bei 32+ Tasks ist es reine Raterei, welcher Task wichtig/dringend ist. Tasks sind unsortiert (Reihenfolge aus SyncEngine).

## Root Cause
`SheetNextUpRow` zeigt nur `task.title` + `task.effectiveDuration`. Die vorhandenen Shared Badge Components (`ImportanceBadge`, `UrgencyBadge`, `PriorityScoreBadge` aus `TaskBadges.swift`) werden nicht genutzt. Die `allTasks`-Liste wird unsortiert an das Sheet uebergeben.

## Fix-Ansatz: Bestehende Komponenten wiederverwenden

**Keine neuen Komponenten.** Vorhandene Shared Badges aus `Sources/Views/Components/TaskBadges.swift` einbauen:

### 1. SheetNextUpRow erweitern
Metadata-Zeile unter dem Titel mit bestehenden Badge-Komponenten (read-only, ohne Callbacks):
- `ImportanceBadge(importance:taskId:)` — ohne `onCycle`
- `UrgencyBadge(urgency:taskId:)` — ohne `onToggle`
- `PriorityScoreBadge(score:tier:taskId:)`

### 2. Alle Tasks nach Priority Score sortieren
`allTasksSortedByPriority` computed property: `allTasks.sorted { $0.priorityScore > $1.priorityScore }` — wichtigste Tasks zuerst.

## Betroffene Dateien
- `Sources/Views/FocusBlockTasksSheet.swift` — SheetNextUpRow + allTasksSection (1 Datei, Shared = beide Plattformen)

## Acceptance Criteria
1. SheetNextUpRow zeigt ImportanceBadge, UrgencyBadge und PriorityScoreBadge
2. "Alle Tasks"-Sektion ist nach priorityScore absteigend sortiert
3. Badges sind read-only (keine Callbacks, kein Editieren im Sheet)
4. Beide Plattformen (iOS + macOS) profitieren (Shared View)

## Aufwand
S — ~30 LoC Aenderung in 1 Datei, nur Wiederverwendung bestehender Komponenten
