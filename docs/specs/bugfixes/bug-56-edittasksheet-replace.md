---
entity_id: bug-56-edittasksheet-replace
type: bugfix
created: 2026-02-17
status: draft
version: "1.0"
tags: [bugfix, datenverlust, metadata, edit]
---

# Bug 56: EditTaskSheet durch TaskFormSheet ersetzen

## Approval

- [ ] Approved

## Purpose

EditTaskSheet hat non-optionale State-Variablen (`priority: TaskPriority`, `duration: Int`) die nil-Importance auf `.low` mappen. Beim Speichern wird importance=1 statt nil uebergeben, wodurch TBD-Tasks ihre Metadaten verlieren. TaskFormSheet macht es bereits korrekt mit `Int?`. Fix: EditTaskSheet eliminieren.

## Root Cause

`Sources/Views/EditTaskSheet.swift:10-11`:
```swift
@State private var priority: TaskPriority  // nil → .low (Zeile 49 in PlanItem)
@State private var duration: Int           // nil → effectiveDuration default
```

Beim Speichern: `priority.rawValue` = Int (nicht Int?), SyncEngine sieht non-nil und ueberschreibt.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/TaskDetailSheet.swift` | MODIFY | EditTaskSheet → TaskFormSheet, onSave Signatur 8→11 Params |
| `Sources/Views/BacklogView.swift` | MODIFY | taskToEdit Callback auf 11-Param Signatur anpassen |
| `Sources/Views/EditTaskSheet.swift` | DELETE | Kaputte Kopie entfernen |

## Implementation Details

### 1. TaskDetailSheet.swift - onSave Signatur erweitern

```swift
// VORHER (8 Params):
let onSave: (String, Int?, Int?, [String], String?, String, Date?, String?) -> Void

// NACHHER (11 Params, wie TaskFormSheet):
let onSave: (String, Int?, Int?, [String], String?, String, Date?, String?, String, [Int]?, Int?) -> Void
```

### 2. TaskDetailSheet.swift - EditTaskSheet durch TaskFormSheet ersetzen

```swift
// VORHER:
.sheet(isPresented: $showEditSheet) {
    EditTaskSheet(task: task, onSave: { ... }, onDelete: { ... })
}

// NACHHER:
.sheet(isPresented: $showEditSheet) {
    TaskFormSheet(task: task, onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay in
        onSave(title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay)
        dismiss()
    }, onDelete: {
        onDelete()
        dismiss()
    })
}
```

### 3. BacklogView.swift - taskToEdit Callback anpassen

```swift
// VORHER (8 Params):
.sheet(item: $taskToEdit) { task in
    TaskDetailSheet(
        task: task,
        onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description in
            updateTask(task, title: title, priority: priority, duration: duration, ...)
        },
        ...

// NACHHER (11 Params):
.sheet(item: $taskToEdit) { task in
    TaskDetailSheet(
        task: task,
        onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay in
            updateTask(task, title: title, priority: priority, duration: duration, ..., recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)
        },
        ...
```

### 4. EditTaskSheet.swift loeschen

Datei komplett entfernen. Keine weiteren Caller vorhanden.

## Scope Assessment

- **Files:** 3 (2 MODIFY, 1 DELETE)
- **Estimated LoC:** +15/-155 (netto ~140 Zeilen weniger)
- **Risk:** LOW - TaskFormSheet ist bereits getestet und funktioniert korrekt

## Test Plan

### Unit Tests (SyncEngine - bestehend)
- Bestehende Tests in `FocusBloxTests/` decken SyncEngine.updateTask() ab

### UI Tests
- Bestehende `TaskDetailUITests` pruefen ob TaskDetailSheet oeffnet und "Bearbeiten" funktioniert
- `EditTaskSheetUITests` muessen auf TaskFormSheet accessibility identifiers angepasst werden (oder entfernt werden, da TaskFormSheet eigene Tests hat)

## Expected Behavior

- TBD-Task (importance=nil) bearbeiten → importance bleibt nil nach Speichern
- Task mit importance=3 bearbeiten → importance bleibt 3
- Recurrence-Felder werden beim Bearbeiten via TaskDetailSheet nicht mehr geloescht
