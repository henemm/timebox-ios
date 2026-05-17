---
entity_id: bug-recurring-task-lastskippeddate-falle
type: bug-fix
created: 2026-05-17
updated: 2026-05-17
status: approved
version: "1.0"
tags: [recurring, repair, lastSkippedDate]
---

# Bug: Wiederkehrender Task startet nach manuellem Löschen nicht mehr

## Approval

- [ ] Approved

## Problem

Ein wiederkehrender Task (z.B. "Klavier spielen") erscheint dauerhaft nicht mehr im Backlog und kann nicht gestartet werden. Der Bug tritt auf wenn der User eine einzelne Instanz manuell löscht (nicht abhakt) und danach nie eine andere Instanz der Serie regulär abschließt.

## Root Cause

Beim manuellen Löschen einer einzelnen Instanz wird `template.lastSkippedDate = Date()` gesetzt (iOS: `BacklogView.swift:756`, macOS: `ContentView.swift:1189`).

`repairOrphanedRecurringSeries()` prüft beim App-Start:

```swift
if let skippedDate = template.lastSkippedDate,
   skippedDate > (task.completedAt ?? .distantPast) {
    continue  // Repair übersprungen
}
```

`lastSkippedDate` wird NUR in `SyncEngine.completeTask()` zurückgesetzt (`= nil`). Wenn nach dem Löschen nie eine Instanz dieser Serie regulär abgeschlossen wird, bleibt `lastSkippedDate` dauerhaft gesetzt → Repair wird bei jedem App-Start übersprungen → keine neue Instanz entsteht → Serie ist permanent eingefroren.

## Betroffene Dateien

- `Sources/Services/RecurrenceService.swift` — Kernfix in `repairOrphanedRecurringSeries()`
- `Tests/FocusBloxTests/RecurrenceServiceRepairTests.swift` (neu) — Unit Tests

## Acceptance Criteria

**AC-1**: Einmaliges Löschen blockiert nicht dauerhaft

**Gegeben:** Ein wiederkehrender Task "Klavier spielen" (weekly), eine Instanz wurde manuell gelöscht (`lastSkippedDate = heute`).  
**Wenn:** Ein voller Recurrence-Zyklus vergangen ist (7 Tage bei weekly).  
**Dann:** `repairOrphanedRecurringSeries()` erstellt eine neue Instanz und setzt `lastSkippedDate = nil`.

**AC-2**: Zeitnahes erneutes Löschen wird korrekt blockiert

**Gegeben:** Ein weekly-Task, letzte Completion vor 3 Tagen, `lastSkippedDate = heute`.  
**Wenn:** App-Start am selben Tag.  
**Dann:** Keine neue Instanz — der Zyklus ist noch nicht abgelaufen (Bug #209 Schutz bleibt aktiv).

**AC-3**: Serie ohne jede Completion wird nach Zyklus repariert

**Gegeben:** Ein weekly-Task, `completedAt == nil` (noch nie abgeschlossen), `lastSkippedDate = vor 8 Tagen`.  
**Wenn:** App-Start heute.  
**Dann:** `repairOrphanedRecurringSeries()` erstellt eine neue Instanz (kein "distantPast"-Fallback blockiert mehr).

**AC-4**: iOS und macOS verhalten sich identisch

**Gegeben:** Derselbe Datenzustand auf beiden Plattformen.  
**Dann:** Beide erstellen eine neue Instanz beim nächsten fälligen Zyklus.

## Fix-Ansatz

In `repairOrphanedRecurringSeries()` die `lastSkippedDate`-Prüfung um eine Zeitdimension erweitern:

**Vorher (buggy):**
```swift
if let skippedDate = template.lastSkippedDate,
   skippedDate > (task.completedAt ?? .distantPast) {
    continue
}
```

**Nachher:**
```swift
if let skippedDate = template.lastSkippedDate,
   skippedDate > (task.completedAt ?? .distantPast) {
    // Nur blockieren wenn der Zyklus noch nicht abgelaufen ist
    let oneInterval = RecurrenceService.nextDueDate(
        pattern: template.recurrencePattern,
        weekdays: template.recurrenceWeekdays,
        monthDay: template.recurrenceMonthDay,
        interval: template.recurrenceInterval,
        from: skippedDate
    ) ?? skippedDate.addingTimeInterval(86400)
    
    if oneInterval > Date() {
        continue  // Noch im Schon-gelöscht-Zyklus — blockieren
    }
    // Zyklus abgelaufen → lastSkippedDate zurücksetzen und reparieren
    template.lastSkippedDate = nil
}
```

**Logik:** `lastSkippedDate` schützt nur für EINEN Zyklus. Wenn das nächste Fälligkeitsdatum nach dem letzten Löschen bereits in der Vergangenheit liegt, ist der Schutz abgelaufen → Repair erlaubt.

## Scope

- **Dateien:** 2 (RecurrenceService.swift, neue Testdatei)
- **LoC:** ≤ 30 (Additions + Tests)
- **Keine Seiteneffekte:** Nur `repairOrphanedRecurringSeries()` wird geändert. `lastSkippedDate`-Setz-Logik bleibt unverändert.

## Tests

Unit Tests in `Tests/FocusBloxTests/RecurrenceServiceRepairTests.swift`:

1. `testRepairAfterSingleDeletion_weeklyTask_repairsAfterOneCycle()` — AC-1
2. `testRepairAfterSingleDeletion_weeklyTask_blocksWithinSameCycle()` — AC-2
3. `testRepairWithNilCompletedAt_repairsAfterOneCycle()` — AC-3

## Changelog

- 2026-05-17: Spec erstellt (Bug-Analyse Phase 2)
