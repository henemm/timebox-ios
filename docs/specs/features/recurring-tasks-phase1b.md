---
entity_id: recurring-tasks-phase1b
type: feature
created: 2026-02-17
updated: 2026-02-17
status: draft
version: "1.0"
tags: [recurring, series, delete-dialog, edit-dialog, backlog-filter, cross-platform]
---

# Recurring Tasks Phase 1B/2: Serien-Konzept + Sichtbarkeit + Dialoge

## Approval

- [ ] Approved

## Purpose

Wiederkehrende Tasks brauchen ein Serien-Konzept. Aktuell ist jede Instanz ein eigenstaendiger Task ohne Verbindung zur Serie. Das verhindert "Ganze Serie loeschen/bearbeiten" und fuehrt dazu, dass zukuenftige Instanzen sofort im Backlog erscheinen.

## Context

- **Phase 1A (implementiert):** `RecurrenceService`, Instanz-Generierung bei Completion, iOS Badge
- **Context Doc:** `docs/context/recurring-tasks-phase1b.md`
- **Bug 57 (geloest):** `safeSet`-Pattern fuer CloudKit-Sync existiert bereits

## Gesamtplan: 3 Tickets

Das Feature wird in 3 Tickets umgesetzt. Jedes Ticket bleibt innerhalb der Scoping-Limits (4-5 Dateien, ~250 LoC).

---

## Ticket 1: Fundament (recurrenceGroupID + Sichtbarkeit + macOS)

### Scope

| Metrik | Wert |
|--------|------|
| Dateien | 5 (3 MODIFY, 0 CREATE, + Tests) |
| LoC | ~100 |
| Risiko | MEDIUM (neues Feld auf LocalTask, CloudKit-Sync) |

### Aenderungen

| File | Change | Description |
|------|--------|-------------|
| `Sources/Models/LocalTask.swift` | MODIFY | `var recurrenceGroupID: String?` Feld + init-Parameter |
| `Sources/Services/RecurrenceService.swift` | MODIFY | GroupID kopieren in `createNextInstance()`, GroupID generieren wenn nil |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | MODIFY | `fetchIncompleteTasks()` filtert recurring Tasks mit dueDate > heute |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | Recurrence-Badge (wie iOS BacklogRow) |
| `FocusBloxMac/TaskInspector.swift` | MODIFY | Completion ueber SyncEngine statt direktem Toggle |

### Details

**1. recurrenceGroupID auf LocalTask:**
```
var recurrenceGroupID: String?
```
- Optional mit nil Default → CloudKit-kompatibel, keine Schema-Migration
- Format: UUID-String
- Wird bei erster Erstellung eines recurring Tasks gesetzt
- `createNextInstance()` kopiert die GroupID von der completed Task

**2. Migration bestehender Tasks:**
- Bestehende recurring Tasks haben `recurrenceGroupID = nil`
- Beim naechsten `createNextInstance()`: Wenn `completedTask.recurrenceGroupID == nil`, neue GroupID generieren und auf BEIDEN Tasks setzen (completed + neue Instanz)
- Kein separater Migrations-Schritt noetig

**3. Sichtbarkeits-Filterung:**
```
fetchIncompleteTasks() Predicate:
  !isCompleted
  UND NICHT (recurrencePattern != "none" UND dueDate > startOfTomorrow)
```
- Recurring Tasks mit dueDate in der Zukunft (ab morgen) werden ausgeblendet
- Recurring Tasks OHNE dueDate oder mit dueDate heute/vergangen bleiben sichtbar
- Nicht-recurring Tasks sind nicht betroffen
- Identische Logik auf iOS (fetchIncompleteTasks) und macOS (@Query)

**4. macOS Badge:**
- Gleicher lila Badge wie iOS BacklogRow
- Icon: `arrow.triangle.2.circlepath`
- Text: Pattern displayName ("Taeglich", "Woechentlich" etc.)

**5. macOS Completion-Fix:**
- TaskInspector nutzt `SyncEngine.completeTask()` statt direktem `task.isCompleted.toggle()`
- Damit wird RecurrenceService automatisch aufgerufen

### CloudKit-Sync Sicherheit

| Risiko | Mitigation |
|--------|------------|
| Neues Feld synct nicht | Optional mit nil Default → CloudKit fuegt automatisch hinzu |
| Doppelte Instanz-Generierung bei gleichzeitigem Completion | Pre-existing Problem aus Phase 1A. Dedup-Logik als separates Ticket |
| macOS alte Version ohne Feld | Ignoriert unbekannte Felder, kein Crash |

---

## Ticket 2: Delete-Dialog "Nur diese / Ganze Serie"

### Scope

| Metrik | Wert |
|--------|------|
| Dateien | 4 (3 MODIFY, 1 CREATE, + Tests) |
| LoC | ~120 |
| Risiko | LOW (UI-Dialog + Batch-Delete) |

### Abhaengigkeit
- **Ticket 1 muss abgeschlossen sein** (recurrenceGroupID muss existieren)

### Aenderungen

| File | Change | Description |
|------|--------|-------------|
| `Sources/Services/SyncEngine.swift` | MODIFY | Neue Methode `deleteRecurringSeries(groupID:)` |
| `Sources/Views/BacklogView.swift` | MODIFY | confirmationDialog bei Swipe-Delete auf recurring Task |
| `FocusBloxMac/ContentView.swift` | MODIFY | confirmationDialog bei Delete auf recurring Task |
| `Sources/Services/RecurrenceService.swift` | MODIFY | Hilfsmethode `fetchSeriesTasks(groupID:)` |

### Details

**1. SyncEngine.deleteRecurringSeries():**
```
func deleteRecurringSeries(groupID: String) throws {
    let tasks = try modelContext.fetch(FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }
    ))
    for task in tasks { modelContext.delete(task) }
    try modelContext.save()
}
```
- Loescht alle OFFENEN Tasks mit gleicher GroupID
- Bereits erledigte Instanzen bleiben erhalten (History)

**2. Confirmation Dialog (iOS):**
- Erscheint NUR bei Tasks mit `recurrencePattern != "none"`
- Zwei Optionen:
  - "Nur diese Aufgabe" → normales `deleteTask()`
  - "Alle offenen dieser Serie" → `deleteRecurringSeries(groupID:)`
- Nicht-recurring Tasks werden wie bisher sofort geloescht

**3. Confirmation Dialog (macOS):**
- Gleiche Logik, `.confirmationDialog` Modifier auf ContentView

---

## Ticket 3: Edit-Dialog "Nur diese / Ganze Serie" + Backlog-Filter

### Scope

| Metrik | Wert |
|--------|------|
| Dateien | 4 (3 MODIFY, 1 CREATE, + Tests) |
| LoC | ~130 |
| Risiko | MEDIUM (Batch-Update ueber CloudKit) |

### Abhaengigkeit
- **Ticket 1 muss abgeschlossen sein** (recurrenceGroupID muss existieren)
- Ticket 2 ist unabhaengig (kann parallel)

### Aenderungen

| File | Change | Description |
|------|--------|-------------|
| `Sources/Services/SyncEngine.swift` | MODIFY | Neue Methode `updateRecurringSeries(groupID:, ...)` |
| `Sources/Views/BacklogView.swift` | MODIFY | confirmationDialog vor Edit auf recurring Task, neuer ViewMode "recurring" |
| `FocusBloxMac/ContentView.swift` | MODIFY | confirmationDialog vor Edit auf recurring Task |
| `Sources/Services/RecurrenceService.swift` | MODIFY | Hilfsmethode `updateSeriesTasks(groupID:, updates:)` |

### Details

**1. SyncEngine.updateRecurringSeries():**
```
func updateRecurringSeries(groupID: String, title: String?, importance: Int?, ...) throws {
    let tasks = try modelContext.fetch(FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }
    ))
    for task in tasks {
        if let title { task.title = title }
        if let importance { task.importance = importance }
        // ... alle editierbaren Felder
    }
    try modelContext.save()
}
```
- Aendert alle OFFENEN Tasks mit gleicher GroupID
- Nutzt `safeSet`-Pattern (Bug 57) wo sinnvoll

**2. Edit-Dialog:**
- Erscheint NACH "Bearbeiten" antippen, VOR TaskFormSheet
- Zwei Optionen:
  - "Nur diese Aufgabe" → normales `updateTask()`
  - "Alle offenen dieser Serie" → `updateRecurringSeries()`
- Nicht-recurring Tasks oeffnen direkt TaskFormSheet

**3. Backlog-Filter "Wiederkehrend":**
- Neuer ViewMode `.recurring` in BacklogView.ViewMode enum
- Zeigt nur Tasks mit `recurrencePattern != "none"`
- Icon: `arrow.triangle.2.circlepath`
- Name: "Wiederkehrend"

---

## Umsetzungsreihenfolge

```
Ticket 1 (Fundament)     ─────────────────►  ZUERST
                                                │
                              ┌─────────────────┤
                              ▼                 ▼
Ticket 2 (Delete-Dialog)  ────►    Ticket 3 (Edit-Dialog + Filter)  ────►  FERTIG
         (unabhaengig voneinander)
```

## Test-Strategie pro Ticket

### Ticket 1 Tests
| Test | Typ | Prueft |
|------|-----|--------|
| `testRecurrenceGroupID_copiedOnNewInstance` | Unit | GroupID wird bei createNextInstance kopiert |
| `testRecurrenceGroupID_generatedWhenNil` | Unit | Neue GroupID bei Migration |
| `testFetchIncompleteTasks_hidesForwardDated` | Unit | Recurring Tasks mit dueDate > heute ausgeblendet |
| `testFetchIncompleteTasks_showsDueToday` | Unit | Recurring Tasks mit dueDate heute sichtbar |
| `testMacRecurrenceBadge` | UI (macOS) | Badge sichtbar auf macOS |
| `testMacCompletionCreatesNextInstance` | Unit | TaskInspector nutzt SyncEngine |

### Ticket 2 Tests
| Test | Typ | Prueft |
|------|-----|--------|
| `testDeleteSingleInstance_keepsOthers` | Unit | Nur eine Instanz geloescht |
| `testDeleteSeries_deletesAllOpen` | Unit | Alle offenen geloescht, erledigte bleiben |
| `testDeleteDialog_appearsForRecurring` | UI | Dialog erscheint bei recurring Task |
| `testDeleteDialog_notShownForNormal` | UI | Kein Dialog bei normalem Task |

### Ticket 3 Tests
| Test | Typ | Prueft |
|------|-----|--------|
| `testEditSingleInstance_keepsOthers` | Unit | Nur eine Instanz geaendert |
| `testEditSeries_updatesAllOpen` | Unit | Alle offenen geaendert |
| `testEditDialog_appearsForRecurring` | UI | Dialog erscheint |
| `testBacklogFilter_recurring_showsOnlyRecurring` | UI | Filter zeigt nur wiederkehrende |

## Known Limitations

- **Keine Dedup-Logik:** Gleichzeitiges Completion auf 2 Geraeten kann doppelte Instanzen erzeugen (pre-existing aus Phase 1A, separates Ticket)
- **Kein "Alle kuenftigen Ereignisse" wie Apple Kalender:** Wir haben nur 2 Optionen (diese / alle offenen), nicht 3 (diese / kuenftige / alle). Einfacher und ausreichend.
- **Erledigte Instanzen nicht in Serie:** "Ganze Serie loeschen/bearbeiten" betrifft nur offene Tasks. Erledigte bleiben in der History.

## Changelog

- 2026-02-17: Initial spec created (Gesamtplan mit 3 Tickets)
