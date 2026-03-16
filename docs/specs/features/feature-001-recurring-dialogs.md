---
entity_id: feature_001_recurring_dialogs
type: feature
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.0"
tags: [coach-backlog, recurring, ios]
---

# FEATURE_001: Coach-Backlog Recurring-Serie-Dialoge

## Approval

- [ ] Approved

## Purpose

CoachBacklogView (iOS) zeigt keine Bestaetigungsdialoge beim Loeschen/Bearbeiten wiederkehrender Tasks. User hat keine Wahl zwischen "Nur diese Aufgabe" und "Alle dieser Serie". Fix portiert die 3 existierenden Dialoge aus BacklogView nach CoachBacklogView.

## Source

- **File:** `Sources/Views/CoachBacklogView.swift`
- **Reference:** `Sources/Views/BacklogView.swift` (Zeilen 67-69, 277-346, 635-733)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SyncEngine | Service | `deleteTask()`, `deleteRecurringSeries()`, `updateRecurringSeries()`, `deleteRecurringTemplate()` |
| BacklogView | View | Referenz-Implementation der 3 Dialoge |
| TaskFormSheet | View | Liefert Recurrence-Parameter im onSave-Callback |

## Implementation Details

### 1. State-Variablen hinzufuegen (CoachBacklogView)

```swift
@State private var taskToDeleteRecurring: PlanItem?
@State private var taskToEditRecurring: PlanItem?
@State private var editSeriesMode: Bool = false
@State private var taskToEndSeries: PlanItem?
```

### 2. deleteTask() mit Recurring-Check

```swift
private func deleteTask(_ task: PlanItem) {
    if let pattern = task.recurrencePattern,
       pattern != "none",
       task.recurrenceGroupID != nil {
        taskToDeleteRecurring = task  // Dialog zeigen
        return
    }
    deleteSingleTask(task)  // Direkt loeschen
}
```

### 3. Drei Confirmation-Dialoge

**Delete-Dialog:** "Nur diese Aufgabe" vs. "Alle offenen dieser Serie"
**Edit-Dialog:** "Nur diese Aufgabe" vs. "Alle offenen dieser Serie"
**Serie-Beenden-Dialog:** "Serie beenden" (bei Template-Tasks)

### 4. Edit-Flow mit editSeriesMode

- Bei Edit-Tap: Recurring-Check → Dialog → editSeriesMode setzen → TaskFormSheet oeffnen
- onSave prueft editSeriesMode: true → `updateRecurringSeries()`, false → `updateTask()`

### 5. Neue Methoden (delegieren an SyncEngine)

- `deleteSingleTask()` — wie bisher, aber als separate Methode
- `deleteRecurringSeries()` — ruft `SyncEngine.deleteRecurringSeries(groupID:)`
- `updateRecurringSeries()` — ruft `SyncEngine.updateRecurringSeries(groupID:, ...)`
- `endSeries()` — ruft `SyncEngine.deleteRecurringTemplate(groupID:)`

## Expected Behavior

- **Loeschen recurring Task:** Dialog mit 2 Optionen (Einzel/Serie) + Abbrechen
- **Bearbeiten recurring Task:** Dialog mit 2 Optionen → TaskFormSheet → Save propagiert je nach Wahl
- **Loeschen Template:** "Serie beenden?"-Dialog
- **Loeschen normaler Task:** Direkt loeschen wie bisher (kein Dialog)
- **Side effects:** Keine — nutzt bestehende SyncEngine-Methoden

## Scope

- **1 Datei:** `Sources/Views/CoachBacklogView.swift`
- **~100-120 LoC Additions**
- **macOS (FEATURE_013) ist NICHT im Scope**

## Known Limitations

- Recurrence-Parameter im Edit-Flow: CoachBacklogView ignoriert aktuell `recPat`, `recWeek`, `recMonth`, `recInterval` aus TaskFormSheet. Dieser Fix adressiert nur den Serien-Modus (alle Instanzen updaten), nicht das Aendern des Wiederholungsmusters selbst.

## Changelog

- 2026-03-16: Initial spec created
