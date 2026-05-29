---
entity_id: bug-315-recurring-stumm
type: bugfix
created: 2026-05-20
updated: 2026-05-20
status: draft
version: "1.0"
tags: [recurring, recurrence, regression, swiftdata]
---

# Bug #315 — Wiederkehrende Tasks sterben nach dem Abhaken (3. Auftreten)

## Approval

- [ ] Approved

## Purpose

Wiederkehrende Tasks erzeugen nach dem Abhaken keine neue Instanz mehr. Der Bug ist bereits 2× symptomatisch gefixt worden und kehrt jedes Mal zurück. Dieser Fix führt eine robuste Kern-Funktion `ensureNextInstance(for:in:)` ein, die alle drei Root Causes auf einmal schließt und die fragilen Einzelpfade ersetzt.

## Source

- **File:** `Sources/Services/RecurrenceService.swift`
- **Identifier:** `enum RecurrenceService` — Methoden `createNextInstance`, `repairOrphanedRecurringSeries`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RecurrenceService` | module | Kern-Service; hier liegen alle drei Root Causes |
| `LocalTask` | model | SwiftData-Modell; `dueDate`, `recurrencePattern`, `isTemplate`, `recurrenceGroupID` |
| `SyncEngine` | module | Ruft `createNextInstance` nach Completion auf — muss auf neue Funktion umgestellt werden |
| `FocusBloxTests/RecurrenceServiceTests` | test | Unit-Tests die den Regressions-Schutz sichern |

## Root Causes

### RC-1: `createNextInstance` bricht bei `dueDate == nil` still ab

`RecurrenceService.swift:84`:
```swift
guard let baseDate = completedTask.dueDate else { return nil }
```
Tasks ohne gesetztes Fälligkeitsdatum erzeugen keinen Nachfolger. Das ist ein stilles `nil`-Return, kein Fehler.

**Fix:** Fallback auf `Date()` (heute) wenn `dueDate == nil`.

### RC-2: `repairOrphanedRecurringSeries` überspringt Serien ohne Template

`RecurrenceService.swift:465`:
```swift
guard let template = findTemplate(groupID: groupID, in: modelContext) else { continue }
```
Der Kommentar lautet "kein Template = Nutzer hat Serie absichtlich beendet". Das ist falsch. Eine absichtlich beendete Serie hat `recurrencePattern == "none"` auf allen abgeschlossenen Kindern gesetzt — das ist das einzig verlässliche Signal. Ein fehlendes Template ist ein Datenfehler, kein Intent-Signal.

**Fix:** Guard entfernen. Stattdessen: wenn kein Template existiert, wird es lazy erstellt (analog zu `migrateToTemplateModel`), dann wird die neue Instanz erzeugt.

### RC-3: Regression durch Commit 15aec1dc — Fallback-Loop entfernt

Commit 15aec1dc reduzierte den Selbstheilungs-Loop (max 30 Wiederholungen) auf einen einzelnen Aufruf von `repairOrphanedRecurringSeries`. Damit ist der Fallback-Mechanismus komplett weggefallen. Eine Serie, die beim ersten Reparatur-Versuch nicht geheilt wird (z.B. wegen RC-1 oder RC-2), wird nie wieder repariert.

**Fix:** Der Fallback darf nicht von einer einzelnen Schleifentiefe abhängen. `ensureNextInstance` muss robust genug sein, dass ein einzelner Aufruf reicht — ohne Loop-Abhängigkeit.

## Implementation Details

### Neue Kern-Funktion `ensureNextInstance(for:in:)`

Ersetzt die fragile Logik in `createNextInstance` und wird von allen Completion-Pfaden genutzt:

```
func ensureNextInstance(for task: LocalTask, in context: ModelContext) -> LocalTask?

1. guard task.recurrencePattern != "none" else { return nil }
2. baseDate = task.dueDate ?? Date()          // RC-1: kein nil-Abbruch
3. newDueDate = nextDueDate(pattern:..., from: baseDate)
4. groupID = task.recurrenceGroupID ?? neu generierte UUID (lazy assign)
5. template = findTemplate(groupID:) ?? lazyCreateTemplate(from: task, groupID:)  // RC-2: lazy, kein Guard
6. Dedup-Check: existiert bereits eine offene Instanz am selben Tag? → nil
7. Neue LocalTask-Instanz aus template-Attributen + newDueDate erstellen
8. modelContext.insert(instance)
9. return instance
```

### Anpassungen in `repairOrphanedRecurringSeries`

- Guard auf `findTemplate` wird entfernt (RC-2)
- Ruft `ensureNextInstance` statt `createNextInstance` auf
- Skip-Logik (`lastSkippedDate`) bleibt unverändert

### "Absichtlich beendet" — korrektes Signal

`deleteRecurringTemplate()` setzt `recurrencePattern = "none"` auf allen completed children. Dieser Wert wird bereits korrekt von `recurringCompleted.filter { $0.recurrencePattern != "none" }` ausgeschlossen. Kein weiteres Template-Signal nötig.

## Expected Behavior

- **Task ohne `dueDate` abhaken:** Neue Instanz erscheint mit `dueDate = nextDueDate(from: Date())`
- **Task mit `dueDate` abhaken:** Neue Instanz erscheint mit korrekt berechnetem nächsten Datum
- **Template-lose abgeschlossene Serie beim App-Start:** `repairOrphanedRecurringSeries` erstellt lazy ein Template und erzeugt eine neue Instanz
- **Absichtlich beendete Serie:** Kein Nachfolger (Signal: `recurrencePattern == "none"` auf completed tasks)
- **Regression-Schutz:** Unit-Test schlägt RED wenn der `dueDate == nil`-Fallback entfernt wird

## Acceptance Criteria

| # | Szenario | Erwartetes Ergebnis |
|---|----------|---------------------|
| AC-1 | Task ohne `dueDate` abhaken | Neue Instanz mit `dueDate = nächster Zyklus ab heute` |
| AC-2 | Task mit `dueDate` abhaken | Neue Instanz mit korrekt berechnetem nächsten Datum |
| AC-3 | Serie ohne Template, `repairOrphanedRecurringSeries` | Lazy Template erstellt + neue Instanz vorhanden |
| AC-4 | Absichtlich beendete Serie (`recurrencePattern == "none"`) | Kein Nachfolger erzeugt |
| AC-5 | Jemand entfernt Fallback auf `Date()` in `ensureNextInstance` | Regressions-Unit-Test wird RED |

## Known Limitations

- `lastSkippedDate`-Logik (Schutz vor Reparatur nach manuellem Löschen) bleibt unverändert — kein Scope in diesem Fix
- `consolidateMultipleInstances` und `deduplicateChildInstances` bleiben unverändert
- macOS-Pfade: `SyncEngine` ist shared code — Umstellung auf `ensureNextInstance` gilt für beide Plattformen

## Changelog

- 2026-05-20: Initial spec created
