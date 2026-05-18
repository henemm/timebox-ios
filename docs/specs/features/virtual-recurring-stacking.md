---
entity_id: virtual-recurring-stacking
type: feature
created: 2026-05-18
updated: 2026-05-18
status: draft
version: "1.0"
tags: [recurrence, stacking, cloudkit, performance]
---

# Virtuelles Stacking fuer wiederkehrende Tasks

## Approval

- [ ] Approved

## Purpose

Eliminiert mehrfache DB-Instanzen fuer verpasste Wiederholungszyklen derselben Serie. Pro Serie existiert maximal eine offene Instanz in der Datenbank; die Badge-Zahl ("x3") wird rein virtuell aus `(heute - dueDate) / Zykluslaenge` berechnet. Das reduziert CloudKit-Sync-Last und beseitigt Inkonsistenzen zwischen Badge-Zaehler und tatsaechlichen DB-Objekten.

## Source

- **File:** `Sources/Services/RecurrenceService.swift`
- **Identifier:** `enum RecurrenceService`
- **File:** `Sources/Services/RecurringStackingHelper.swift`
- **Identifier:** `enum RecurringStackingHelper`
- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `func completeTask(_:)`
- **File:** `FocusBloxMac/MacBacklogHelpers.swift`
- **Identifier:** `enum MacBacklogStackingHelper`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RecurrenceService.createNextInstance` | function | Erzeugt naechste Instanz nach Abhaken; dueDate = altes + 1 Zyklus — unveraendert |
| `RecurrenceService.repairOrphanedRecurringSeries` | function | Wird auf max-1-Instanz-Logik umgestellt (while-Loop Limit: 30 → 1) |
| `RecurringStackingHelper.apply` | function | Pfad A entfernen; Pfad B wird universell fuer alle recurring Tasks |
| `MacBacklogStackingHelper.applyStacking` | function | Pfad A entfernen; Pfad B wird universell fuer alle recurring Tasks |
| `BacklogView.completeTask` | function | Sibling-Suche entfernen; targetID = item.id (immer nur 1 Instanz) |
| `RecurrenceService.consolidateMultipleInstances` | function | Neue einmalige Migration: pro groupID nur aelteste offene Instanz behalten |
| `FocusBloxApp` | module | Ruft `consolidateMultipleInstances` beim App-Start auf |
| `DeferredCompletionController` | module | Deferred-Completion / Shake-Undo — Verhalten unveraendert |

## Implementation Details

### 1. RecurrenceService — `repairOrphanedRecurringSeries`

Aktueller while-Loop (Zeile ~493) erstellt bis zu 30 Instanzen vorwaerts:

```
while created < 30 {
    guard let instance = createNextInstance(from: currentSource, in: modelContext) else { break }
    created += 1
    if let due = instance.dueDate, due > Date() { break }
    currentSource = instance
}
```

**Aenderung:** Limit von 30 auf 1 setzen und die Schleife nach der ersten erstellten Instanz abbrechen — unabhaengig davon, ob das neue dueDate in der Vergangenheit liegt.

```
// Nur eine Instanz erzeugen — virtuelle Stacking-Berechnung macht den Rest
createNextInstance(from: currentSource, in: modelContext)
```

### 2. RecurringStackingHelper — Pfad A entfernen, Pfad B universell

**Pfad A entfernen** (Zeilen 22-51): Komplette Gruppierungs- und Repraesentanten-Logik nach `recurrenceGroupID` faellt weg.

**Pfad B universell** (Zeilen 59-97): Die Guard-Bedingung, die Pfad B auf Tasks ohne `recurrenceGroupID` einschraenkt (falls vorhanden), wird entfernt. Pfad B laeuft fuer alle recurring Tasks.

Der `stackedOldestDueDate`-Wert wird weiterhin am Item gesetzt (dueDate des einzigen offenen Items = aelteste faellige Instanz).

### 3. BacklogView — `completeTask`

**Aktuell (Zeilen 991-1000):**
```swift
let targetID: String
if item.stackedInstanceCount > 1, let groupID = item.recurrenceGroupID {
    let siblings = planItems.filter {
        $0.recurrenceGroupID == groupID && !$0.isCompleted && !$0.isTemplate
    }
    targetID = siblings
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        .first?.id ?? item.id
} else {
    targetID = item.id
}
```

**Nach Aenderung:**
```swift
let targetID = item.id
```

Die Sibling-Suche ist obsolet, da pro Serie immer nur 1 offene Instanz existiert.

### 4. MacBacklogStackingHelper — Pfad A entfernen, Pfad B universell

Analog zu `RecurringStackingHelper`. Pfad A (Zeilen 44-73: Gruppierung nach `recurrenceGroupID`, Repraesentant = juengstes Child) wird entfernt. `ungrouped`-Sammlung und finale `result`-Zusammenfuehrung vereinfachen sich auf alle Tasks. Pfad B (Zeilen 81-120) laeuft unveraendert fuer alle recurring Tasks.

### 5. RecurrenceService — neue Funktion `consolidateMultipleInstances`

Einmalige Migration beim App-Start. Fuer jede `recurrenceGroupID`:
1. Alle offenen, nicht-template Instanzen fetchen
2. Falls mehr als 1 Instanz vorhanden: die mit dem fruehesten `dueDate` behalten, alle anderen `modelContext.delete()`
3. Nach Durchlauf `try? modelContext.save()`

Idempotent: Wenn nur 1 Instanz vorhanden, passiert nichts.

### 6. FocusBloxApp — App-Start-Reihenfolge

`consolidateMultipleInstances` wird in den bestehenden Migrations-Block eingefuegt, **vor** `repairOrphanedRecurringSeries`:

```swift
RecurrenceService.migrateToTemplateModel(in: ...)
RecurrenceService.deduplicateTemplates(in: ...)
RecurrenceService.deduplicateChildInstances(in: ...)
RecurrenceService.consolidateMultipleInstances(in: ...)   // NEU
RecurrenceService.repairOrphanedRecurringSeries(in: ...)
```

### Deferred Completion / Shake-Undo

Das bestehende `DeferredCompletionController`-System bleibt unveraendert. Da `targetID = item.id` direkt verwendet wird, zeigt die pending-Animation auf die einzige offene Instanz. Shake-Undo (`cancelCompletion`) funktioniert identisch.

### Badge-Berechnung (Pfad B)

```
missedCycles = (elapsedDays / cycleDays) + 1
```

- Badge "x2" ab `missedCycles >= 2`
- Badge "x3" bei 3 verpassten Zyklen usw.
- Nach Abhaken: `createNextInstance` setzt dueDate = altes + 1 Zyklus → missedCycles sinkt um 1

### Nicht veraendert

- `LocalTask`-Modell (`isTemplate`, `recurrenceGroupID`)
- `createNextInstance` Kern-Logik
- `lastSkippedDate`-Logik (Bug #209 Schutz)
- `deleteRecurringSeries()` / `endSeries()`
- `cycleDuration()` Helper

## Acceptance Criteria

**AC-1**: Pro Serie maximal 1 offene Instanz in der DB nach Repair
**AC-2**: Badge "xN" wird virtuell berechnet aus (heute - dueDate) / Zykluslaenge
**AC-3**: Abhaken senkt Badge um 1 (neue Instanz mit dueDate +1 Zyklus)
**AC-4**: Migration reduziert bestehende mehrfache Instanzen auf 1 (aelteste behalten)
**AC-5**: Deferred Completion / Shake-Undo funktioniert unveraendert
**AC-6**: macOS-Paritaet (MacBacklogStackingHelper analog geaendert)

## Expected Behavior

- **Input:** User oeffnet Backlog mit einer recurring Serie, die seit 3 Wochen (weekly) nicht abgehakt wurde
- **Output:** Exakt 1 DB-Instanz vorhanden; Badge zeigt "x3"; beim Abhaken sinkt Badge um 1 pro Haken-Tipp; nach 3 Abhaken kein Badge mehr
- **Side effects:**
  - Beim ersten App-Start nach Update: `consolidateMultipleInstances` loescht ueberzaehlige Instanzen pro Serie
  - CloudKit synchronisiert weniger Objekte (1 statt N pro Serie)
  - `repairOrphanedRecurringSeries` erstellt maximal 1 neue Instanz pro verwaister Serie statt bis zu 30

## Known Limitations

- `cycleDuration()` ist eine Naeherung (monthly = 30 Tage fix, kein Kalender). Bei monatlichen Tasks mit 31-Tage-Monaten kann die Badge-Zahl um 1 abweichen. Bestehendes Verhalten, wird nicht geaendert.
- `quarterly`, `semiannually`, `yearly` haben keinen Entry in `cycleDuration()` (return 0) → Pfad B inaktiv fuer diese Patterns. Bestehendes Verhalten, wird nicht geaendert.

## Changelog

- 2026-05-18: Initial spec created
