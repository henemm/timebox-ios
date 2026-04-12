---
entity_id: bug_209_recurring_delete
type: bugfix
created: 2026-04-12
updated: 2026-04-12
status: draft
version: "1.0"
tags: [recurring, delete, repair, zombie]
---

# Bug #209: Gelöschte Serienelemente erscheinen nach Neustart erneut

## Approval

- [ ] Approved

## Purpose

Verhindert, dass einzeln gelöschte Serien-Instanzen durch den Reparatur-Mechanismus beim App-Start wiederhergestellt werden. Aktuell unterscheidet `repairOrphanedRecurringSeries()` nicht zwischen "letzte Instanz wurde erledigt" (→ Repair korrekt) und "letzte Instanz wurde gelöscht" (→ Repair falsch).

## Root Cause

1. User löscht einzelne Serien-Instanz via "Nur diese Aufgabe"
2. `SyncEngine.deleteTask()` löscht die Instanz physisch, Template bleibt
3. Beim nächsten App-Start: `repairOrphanedRecurringSeries()` findet:
   - Completed Tasks mit `recurrencePattern != "none"` → Repair-Quelle vorhanden
   - Keine offene Instanz für diese GroupID → Serie gilt als "verwaist"
   - Template existiert → Guard (Zeile 464) greift nicht
4. → Erzeugt neue Instanz für dasselbe Datum → Zombie

## Source

- **Primäre Dateien:**
  - `Sources/Models/LocalTask.swift` — neues Feld
  - `Sources/Services/RecurrenceService.swift` — Repair + createNextInstance
  - `Sources/Views/BacklogView.swift` — Lösch-Pfad iOS
  - `FocusBloxMac/ContentView.swift` — Lösch-Pfad macOS

## Fix-Ansatz: `lastSkippedDate` auf Template

Statt einer `[Date]`-Liste (skipDates) ein einzelnes `lastSkippedDate: Date?` auf dem Template:

- **Beim Löschen:** Wenn eine einzelne Serien-Instanz gelöscht wird → `lastSkippedDate` auf dem Template auf `Date()` setzen
- **Beim Repair:** `repairOrphanedRecurringSeries()` prüft: Wenn `lastSkippedDate` neuer ist als `completedAt` der jüngsten completed Task → NICHT reparieren (User hat bewusst gelöscht NACH der letzten Completion)
- **Beim Completion:** `completeTask()` setzt `lastSkippedDate = nil` auf dem Template zurück → nächste reguläre Instanz wird normal erzeugt

### Warum `lastSkippedDate` statt `skipDates: [Date]`

- 1 Feld statt Array-Management
- Keine List-Cleanup-Logik nötig
- SwiftData Lightweight Migration: optionales `Date?` ist trivial
- Ausreichend: Wir müssen nur wissen "wurde NACH der letzten Completion etwas gelöscht?", nicht welche Daten genau

## Implementation Details

### 1. LocalTask.swift — Neues Feld

```swift
/// Date when a single instance was manually deleted from this series.
/// Set on the TEMPLATE when user deletes "only this task".
/// Prevents repairOrphanedRecurringSeries() from resurrecting the instance.
/// Reset to nil when a new instance is completed (normal series flow).
var lastSkippedDate: Date?
```

Position: nach `isTemplate` (Zeile ~74)

### 2. BacklogView.swift — deleteSingleTask() erweitern

VOR dem `modelContext.delete()`: Wenn die gelöschte Task recurring ist, `lastSkippedDate` auf dem Template setzen.

```swift
private func deleteSingleTask(_ task: PlanItem) {
    do {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        
        // Bug #209: Mark template so repair won't resurrect this instance
        if let groupID = task.recurrenceGroupID,
           task.recurrencePattern != nil,
           task.recurrencePattern != "none" {
            if let template = RecurrenceService.findTemplate(groupID: groupID, in: modelContext) {
                template.lastSkippedDate = Date()
            }
        }
        
        try syncEngine.deleteTask(itemID: task.id)
        // ... rest unchanged
    }
}
```

### 3. ContentView.swift (macOS) — gleiche Logik

Im macOS-Lösch-Pfad für "Nur diese Aufgabe" dieselbe Template-Markierung setzen.

### 4. RecurrenceService.swift — repairOrphanedRecurringSeries() Guard erweitern

```swift
// Zeile ~464, nach dem Template-Guard:
guard findTemplate(groupID: groupID, in: modelContext) != nil else { continue }

// NEU: Don't repair if user manually deleted an instance after last completion
if let template = findTemplate(groupID: groupID, in: modelContext),
   let skippedDate = template.lastSkippedDate,
   skippedDate > (task.completedAt ?? .distantPast) {
    continue  // User deleted AFTER completing — don't resurrect
}
```

### 5. SyncEngine.swift — completeTask() Reset

Nach erfolgreicher Completion: `lastSkippedDate = nil` auf Template setzen, damit die Serie normal weiterläuft.

```swift
// In completeTask(), nach createNextInstance():
if let groupID = task.recurrenceGroupID,
   let template = RecurrenceService.findTemplate(groupID: groupID, in: modelContext) {
    template.lastSkippedDate = nil
}
```

### 6. findTemplate() Sichtbarkeit

`RecurrenceService.findTemplate()` ist aktuell `private`. Muss `internal` oder `static` werden damit BacklogView und ContentView darauf zugreifen können.

## Expected Behavior

- **Input:** User löscht einzelne Serien-Instanz ("Nur diese Aufgabe")
- **Output:** Instanz bleibt gelöscht, auch nach App-Neustart und Background-Return
- **Side effects:**
  - Template erhält `lastSkippedDate`
  - Nächste reguläre Completion der Serie setzt `lastSkippedDate` zurück → Serie läuft normal weiter

### Szenarien

| Szenario | Erwartetes Verhalten |
|----------|---------------------|
| Einzelne Instanz löschen → App-Neustart | Instanz bleibt gelöscht |
| Einzelne Instanz löschen → Background → Foreground | Instanz bleibt gelöscht |
| Einzelne Instanz löschen → nächste Instanz erscheint bei Fälligkeit | Nächste Instanz wird normal erzeugt (via Completion der vorherigen) |
| Einzelne Instanz löschen → dann andere Instanz erledigen | `lastSkippedDate` wird zurückgesetzt, Serie läuft normal |
| Serie beenden ("Serie beenden") | Unverändert — Template wird gelöscht, Guard auf Zeile 464 greift |
| Alle offenen löschen ("Alle offenen dieser Serie") | Unverändert — nutzt `deleteRecurringSeries()`, nicht `deleteSingleTask()` |

## Acceptance Criteria

1. **AC-1:** Nach Löschen einer einzelnen Serien-Instanz überlebt die Löschung einen App-Neustart
2. **AC-2:** Nach Löschen einer einzelnen Serien-Instanz überlebt die Löschung einen Background-Foreground-Zyklus
3. **AC-3:** Nach Löschen + Erledigen einer anderen Instanz derselben Serie: nächste Instanz wird normal erzeugt
4. **AC-4:** Bestehendes Verhalten "Serie beenden" und "Alle offenen löschen" bleibt unverändert
5. **AC-5:** Bestehendes Verhalten "Task erledigen → nächste Instanz erzeugen" bleibt unverändert
6. **AC-6:** Fix wirkt auf iOS UND macOS

## Test Plan

### Unit Tests (RecurrenceServiceTests)

```
test_repairSkipsSeriesWithLastSkippedDate()
  → Serie mit completed Task + Template mit lastSkippedDate > completedAt
  → repair() erzeugt KEINE neue Instanz

test_repairStillWorksWithoutLastSkippedDate()
  → Serie mit completed Task + Template ohne lastSkippedDate
  → repair() erzeugt neue Instanz (bestehende Logik)

test_completionResetsLastSkippedDate()
  → Template hat lastSkippedDate gesetzt
  → completeTask() → lastSkippedDate wird nil

test_deleteSingleRecurringSetsLastSkippedDate()
  → Lösche einzelne Serien-Instanz
  → Template.lastSkippedDate ist gesetzt

test_deleteRecurringSeriesDoesNotSetLastSkippedDate()
  → "Alle offenen löschen" → lastSkippedDate bleibt nil
```

## Known Limitations

- **CloudKit-Race:** Wenn ein anderes Gerät die gelöschte Instanz vor dem Sync des `lastSkippedDate` zurückbringt, könnte das Element kurzzeitig wieder auftauchen. Wird beim nächsten Startup bereinigt.
- **Einzelnes Feld:** Wenn der User MEHRERE Instanzen nacheinander einzeln löscht, überschreibt das zweite Delete das erste `lastSkippedDate`. Da Repair nur die jüngste completed Task prüft, ist das korrekt — der Guard verhindert Repair solange `lastSkippedDate` neuer ist.

## Scoping

- **4 Dateien** geändert (LocalTask, RecurrenceService, BacklogView, ContentView)
- **~40 LoC** Änderungen
- **1 Test-Datei** (RecurrenceServiceTests)
- Kein UI-Test nötig (reiner Daten-/Logik-Bug, kein visuelles Element)

## Changelog

- 2026-04-12: Initial spec created
