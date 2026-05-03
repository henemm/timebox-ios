---
entity_id: bug-306-reminders-recurrence-groupid
type: bugfix
created: 2026-05-03
updated: 2026-05-03
status: draft
version: "1.0"
tags: [bugfix, reminders, recurrence, stacking]
---

# Bug #306 — Counter-Bar fehlt bei importierten recurring Tasks

## Approval

- [ ] Approved

## Problem

Wiederkehrende Tasks aus Apple Reminders werden ohne `recurrenceGroupID` importiert. Folge: `RecurringStackingHelper` Pfad A (Gruppen-Stacking) greift nie für importierte Tasks → Counter-Bar fehlt bei der erwarteten User-Erfahrung.

`recurrencePattern` selbst wird seit längerem korrekt gemappt (`ReminderData.mapRecurrenceRules()`) — der ursprüngliche Issue-Text ist veraltet.

## Root Cause

`RemindersImportService.swift:83-93` erstellt `LocalTask` ohne `recurrenceGroupID`. Die GroupID wird bisher nur lazy beim ersten `completeRecurringTask()`-Aufruf erzeugt (`RecurrenceService.swift:99`). Damit Pfad A der Stacking-Logik aber überhaupt greifen kann, MUSS die GroupID vor dem ersten Render gesetzt sein.

Zusätzlich: `PlanItem.init(reminder:metadata:)` (`PlanItem.swift:157-200`) ignoriert `reminder.recurrencePattern` und setzt es auf `nil` — mit irreführendem Kommentar "Reminders don't have recurrence" (heute falsch, da Reminders recurring sein können). Wird nur in Tests verwendet, daher kein Production-Symptom — aber konzeptioneller Drift, soll mit gefixt werden.

## Fix-Strategie

### 1) `Sources/Services/RemindersImportService.swift`

Beim Erstellen eines neuen `LocalTask` mit recurring Pattern:

```swift
let task = LocalTask(
    title: reminder.title,
    importance: mapReminderPriority(reminder.priority),
    dueDate: reminder.dueDate,
    recurrencePattern: reminder.recurrencePattern,
    taskDescription: reminder.notes,
    externalID: nil,
    sourceSystem: "local"
)
if reminder.recurrencePattern != "none" {
    task.recurrenceGroupID = UUID().uuidString
}
modelContext.insert(task)
```

Auch im **Enrichment-Pfad** (Zeilen 69-73): Wenn ein bestehender Task von `"none"` auf ein recurring Pattern enriched wird, GroupID nachsetzen falls bisher nil:

```swift
if existing.recurrencePattern == "none" && reminder.recurrencePattern != "none" {
    existing.recurrencePattern = reminder.recurrencePattern
    if existing.recurrenceGroupID == nil {
        existing.recurrenceGroupID = UUID().uuidString
    }
    enrichedRecurrence += 1
    ...
}
```

### 2) `Sources/Models/PlanItem.swift`

`init(reminder:metadata:)` so anpassen dass `recurrencePattern` durchgereicht wird:

- Zeile 195: `self.recurrencePattern = nil` → `self.recurrencePattern = reminder.recurrencePattern == "none" ? nil : reminder.recurrencePattern`
- Den irreführenden Kommentar "Reminders don't have recurrence" durch eine korrekte Notiz ersetzen oder entfernen

## Acceptance Criteria

| Nr | Kriterium |
|----|-----------|
| AC-1 | Importierter recurring Reminder (z.B. weekly) → resultierender LocalTask hat `recurrenceGroupID != nil` |
| AC-2 | Importierter NICHT-recurring Reminder → LocalTask hat `recurrenceGroupID == nil` |
| AC-3 | Bestehender Task wird via Enrichment auf "weekly" geupdated → `recurrenceGroupID` wird gesetzt (war vorher nil) |
| AC-4 | Bestehender Task hat bereits eine GroupID → wird beim Enrichment NICHT überschrieben |
| AC-5 | `PlanItem.init(reminder:metadata:)` mit recurring `ReminderData` setzt `recurrencePattern` korrekt (nicht nil) |
| AC-6 | `PlanItem.init(reminder:metadata:)` mit `recurrencePattern: "none"` setzt `recurrencePattern = nil` (kein "none"-String im PlanItem) |
| AC-7 | `RecurringStackingHelper.apply(...)` mit zwei importierten recurring Tasks gleicher GroupID liefert `stackedInstanceCount == 2` |

## Out-of-Scope

- Edge Cases im Mapping: `interval > 1` (z.B. "alle 3 Wochen"), `daysOfTheWeek` (z.B. "Mo+Mi+Fr"), `.yearly`-Frequenz — separate Backlog-Items
- Bidirektionaler Sync (Reminders ←→ App)
- Änderung an `RecurringStackingHelper` selbst

## Affected Files

1. `Sources/Services/RemindersImportService.swift` (~10 LoC)
2. `Sources/Models/PlanItem.swift` (~3 LoC)
3. `FocusBloxTests/RemindersImportServiceTests.swift` (~30 LoC für AC-1 bis AC-4 + AC-7)
4. `FocusBloxTests/ScheduledTaskModelTests.swift` (existierend, ggf. anpassen für AC-5/6)

## Test-Hinweise

### Unit-Tests (`RemindersImportServiceTests.swift`)

- `test_importAll_setsRecurrenceGroupID_forRecurringReminder` — Mock-ReminderData mit `recurrencePattern: "weekly"` → `task.recurrenceGroupID != nil`
- `test_importAll_doesNotSetGroupID_forNonRecurringReminder` — Mock mit `"none"` → `task.recurrenceGroupID == nil`
- `test_enrichRecurrence_setsGroupID_whenPreviouslyNil` — bestehender Task mit `recurrencePattern = "none"`, GroupID nil → Import mit "weekly" → Pattern UND GroupID gesetzt
- `test_enrichRecurrence_preservesExistingGroupID` — bestehender Task mit GroupID gesetzt → Import → GroupID unverändert
- `test_recurringStackingHelper_appliesToImportedTasks` — Zwei importierte Tasks gleicher GroupID → `stackedInstanceCount == 2`

### Unit-Tests (`ScheduledTaskModelTests.swift` oder neuer Test)

- `test_planItem_reminder_recurringPattern_isPropagated` — `PlanItem(reminder: ReminderData(recurrencePattern: "weekly"), ...).recurrencePattern == "weekly"`

## Changelog

- 2026-05-03: Initial spec
