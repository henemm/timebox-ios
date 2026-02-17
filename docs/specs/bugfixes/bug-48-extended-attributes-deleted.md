---
entity_id: bug-48-extended-attributes-deleted
type: bugfix
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [bugfix, datenverlust, sync, attributes]
---

# Bug 48: Erweiterte Attribute werden wiederholt geloescht

## Approval

- [ ] Approved

## Purpose

Beim Bearbeiten von Tasks (Quick Edit, Full Edit, macOS Quick Capture) werden erweiterte Attribute (Wichtigkeit, Dringlichkeit, Wiederholungen) geloescht oder auf falsche Defaults gesetzt. Dieser Bug tritt auf beiden Plattformen auf und ist ein wiederkehrendes Problem (Bug 18, Bug 32 waren unvollstaendige Fixes).

## Root Causes

### RC1: SyncEngine.updateTask() ueberschreibt IMMER alle Felder
**Datei:** `Sources/Services/SyncEngine.swift:67-83`

`updateTask()` setzt alle Felder bedingungslos - auch optionale. Wenn ein Caller `nil` uebergibt (weil das Feld nicht geaendert werden soll), wird der bestehende Wert geloescht.

Zusaetzlich: Die Quick-Edit-Funktionen in BacklogView uebergeben `recurrencePattern`/`recurrenceWeekdays`/`recurrenceMonthDay` NICHT, wodurch `recurrencePattern ?? "none"` die Wiederholungs-Einstellungen loescht.

### RC2: TaskFormSheet erzwingt Importance = .medium
**Datei:** `Sources/Views/TaskFormSheet.swift:358`

Im EDIT-Modus: `priority.flatMap { TaskPriority(rawValue: $0) } ?? .medium` konvertiert `nil` (TBD) zu `.medium`. Die `onSave`-Signatur erwartet `TaskPriority` (non-optional), wodurch TBD nicht darstellbar ist.

Gleiche Signatur in `TaskDetailSheet.swift:5` und `EditTaskSheet.swift:6`.

### RC3: macOS Quick Capture umgeht Shared Services
**Dateien:** `FocusBloxMac/QuickCapturePanel.swift:175`, `MenuBarView.swift:182`, `ContentView.swift:486`

3x direktes `LocalTask(title:)` ohne `LocalTaskSource.createTask()`. Tasks entstehen ohne erweiterte Attribute. Bei CloudKit-Sync koennen leere Werte bestehende iOS-Werte ueberschreiben.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/SyncEngine.swift` | MODIFY | Optionale Felder nur bei nicht-nil setzen |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | onSave: `TaskPriority` -> `Int?` |
| `Sources/Views/BacklogView.swift` | MODIFY | updateTask() Signatur + Quick-Edit recurrence-Params |
| `Sources/Views/TaskDetailSheet.swift` | MODIFY | onSave: `TaskPriority` -> `Int?`, `Int` -> `Int?` |
| `FocusBloxMac/QuickCapturePanel.swift` | MODIFY | LocalTaskSource.createTask() nutzen |
| `FocusBloxMac/MenuBarView.swift` | MODIFY | LocalTaskSource.createTask() nutzen |
| `FocusBloxMac/ContentView.swift` | MODIFY | LocalTaskSource.createTask() nutzen |

## Implementation Details

### Fix RC1: SyncEngine.updateTask() - Preserve bestehender Werte

```swift
// VORHER (loescht bei nil):
task.importance = importance
task.urgency = urgency
task.recurrencePattern = recurrencePattern ?? "none"
task.recurrenceWeekdays = recurrenceWeekdays
task.recurrenceMonthDay = recurrenceMonthDay

// NACHHER (nil = nicht aendern):
if let importance { task.importance = importance }
if let duration { task.estimatedDuration = duration }
if let urgency { task.urgency = urgency }
if let recurrencePattern { task.recurrencePattern = recurrencePattern }
if let recurrenceWeekdays { task.recurrenceWeekdays = recurrenceWeekdays }
if let recurrenceMonthDay { task.recurrenceMonthDay = recurrenceMonthDay }
```

Nicht-optionale Felder (title, tags, taskType) werden weiterhin immer gesetzt.

**Explizites Loeschen:** Neuer Sentinel-Wert ist NICHT noetig. Wer ein Feld tatsaechlich leeren will, kann `importance: -1` oder `urgency: ""` setzen und der Code prueft das separat. Aktuell gibt es aber KEINEN Use Case fuer explizites Loeschen.

### Fix RC2: TaskFormSheet/TaskDetailSheet Signatur

`onSave`-Signatur aendern: `TaskPriority` -> `Int?` (direkt importance-Wert statt Enum).

In `TaskFormSheet.swift`: Zeile 358 entfernen, `priority` (Int?) direkt uebergeben.
In `BacklogView.swift`: `updateTask()` Signatur von `priority: TaskPriority` zu `importance: Int?` aendern, `priority.rawValue` durch `importance` ersetzen.

### Fix RC3: macOS Quick Capture auf Shared Service

Alle 3 Stellen ersetzen:
```swift
// VORHER:
let task = LocalTask(title: taskTitle)
modelContext.insert(task)

// NACHHER:
let taskSource = LocalTaskSource(modelContext: modelContext)
_ = try await taskSource.createTask(title: taskTitle)
```

## Expected Behavior

- **Quick Edit (Importance/Urgency/Category/Title):** Nur das geaenderte Feld wird aktualisiert, alle anderen Attribute bleiben erhalten
- **Full Edit (TaskFormSheet/TaskDetailSheet):** Importance kann auf TBD (nil) bleiben, wird nicht zu .medium erzwungen
- **macOS Quick Capture:** Tasks werden ueber Shared Service erstellt (konsistent mit iOS)
- **Wiederholungen:** Quick Edits loeschen KEINE Wiederholungs-Einstellungen

## Scope Assessment

- **Files:** 7
- **Estimated LoC:** +60/-30
- **Risk:** MEDIUM (SyncEngine ist zentraler Update-Pfad)

## Test Plan

### Unit Tests (SyncEngine)
1. Task mit importance=3 erstellen, `updateTask(importance: nil)` aufrufen → importance bleibt 3
2. Task mit urgency="urgent" erstellen, `updateTask(urgency: nil)` aufrufen → urgency bleibt "urgent"
3. Task mit recurrencePattern="daily" erstellen, Quick-Edit Title → recurrence bleibt "daily"
4. Task mit importance=nil, `updateTask(importance: 2)` → importance wird 2

### UI Tests (BacklogView)
5. Task mit allen Attributen erstellen, Titel inline aendern → Attribute bleiben erhalten
6. Task bearbeiten, Importance auf TBD lassen, speichern → Importance bleibt nil (nicht .medium)

## Known Limitations

- Explizites Zuruecksetzen eines Feldes auf nil (z.B. "Importance entfernen") ist nach dem Fix nicht mehr ueber `updateTask()` moeglich. Dafuer muss eine separate `clearImportance()` Methode verwendet werden - aktuell gibt es diesen Use Case aber NICHT.

## Changelog

- 2026-02-13: Initial spec created
