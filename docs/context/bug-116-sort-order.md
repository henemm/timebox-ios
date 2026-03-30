# Context: BUG_116 — Sort-Order-Tests fehlschlagen

## Request Summary
Zwei Unit Tests erwarten Sortierung nach `sortOrder`, aber die Implementierung sortiert anders.

## Betroffene Tests

| Test | Datei | Erwartung |
|------|-------|-----------|
| `test_fetchIncompleteTasks_sortsBySortOrder` | `FocusBloxTests/LocalTaskSourceTests.swift:65` | Tasks sortiert nach `sortOrder` aufsteigend (0, 1, 2) |
| `test_sync_sortsByRank` | `FocusBloxTests/SyncEngineTests.swift:45` | PlanItems sortiert nach `rank` (= `sortOrder`) aufsteigend |

## Root Cause Hypothese

### LocalTaskSource (Zeile 41)
```swift
descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
```
Sortiert nach `createdAt` absteigend — **nicht** nach `sortOrder` aufsteigend. Der Test erwartet sortOrder-Sortierung.

### SyncEngine.sync() (Zeile 19)
```swift
return tasks.map { PlanItem(localTask: $0) }
            .sorted { $0.rank > $1.rank }
```
Sortiert nach `rank` **absteigend** (höchster rank zuerst). `PlanItem.rank` = `localTask.sortOrder` (Zeile 201 in PlanItem.swift). Der Test erwartet aufsteigende Reihenfolge (rank 0 = "First").

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `fetchIncompleteTasks()` Zeile 37-46 — sortiert nach `createdAt` statt `sortOrder` |
| `Sources/Services/SyncEngine.swift` | `sync()` Zeile 16-20 — sortiert `rank` absteigend statt aufsteigend |
| `Sources/Models/PlanItem.swift` | `rank` = `localTask.sortOrder` (Zeile 201) |
| `FocusBloxTests/LocalTaskSourceTests.swift` | Test `test_fetchIncompleteTasks_sortsBySortOrder` (Zeile 65) |
| `FocusBloxTests/SyncEngineTests.swift` | Test `test_sync_sortsByRank` (Zeile 45) |

## Analyse-Frage

Zentrale Frage: **Sind die Tests falsch oder die Implementierung?**

- Die Tests wurden vermutlich geschrieben als `sortOrder` noch die primäre Sortierung war
- Inzwischen sortiert das Backlog nach `priorityScore` (siehe `TaskPriorityScoringService`)
- `fetchIncompleteTasks()` sortiert nach `createdAt` — möglicherweise bewusst, weil die View-Schicht die endgültige Sortierung übernimmt
- `SyncEngine.sync()` sortiert nach `rank` absteigend — "höherer Rang = höhere Priorität"

Möglichkeiten:
1. **Tests anpassen** an die aktuelle Sortierung (wenn die Implementierung korrekt ist)
2. **Implementierung anpassen** (wenn `sortOrder` die intendierte DB-Sortierung ist)
3. **Beides** — z.B. DB sortiert nach sortOrder, SyncEngine nach rank aufsteigend

## Dependencies
- Upstream: `LocalTask` Model, `SwiftData` FetchDescriptor
- Downstream: `BacklogView` und alle Views die `SyncEngine.sync()` aufrufen

## Existing Specs
- Keine spezifische Spec für Sort-Logik vorhanden

## Risks & Considerations
- Änderung der Sortierung in `fetchIncompleteTasks()` könnte andere Aufrufer beeinflussen
- Änderung der Sortierung in `sync()` ändert die Backlog-Darstellung
- Muss geprüft werden, ob Views die Sortierung ohnehin überschreiben
