---
entity_id: bug-import-recurrence-lost
type: bugfix
created: 2026-02-19
status: draft
version: "1.0"
tags: [reminders, import, recurrence, recurring]
---

# Bug: Importierte Reminders verlieren Recurrence-Info

## Approval

- [ ] Approved

## Problem

Wiederkehrende Apple Reminders (z.B. "Zehnagel" woechentlich, "Fahrradkette reinigen" monatlich) werden beim Import nach FocusBlox als normale Tasks ohne `recurrencePattern` importiert. Dadurch greift der `isVisibleInBacklog`-Filter nicht und diese Tasks erscheinen dauerhaft in "Alle Tasks" — auch wenn sie erst in der Zukunft faellig sind.

## Root Cause

`ReminderData` hat kein Feld fuer Recurrence. `RemindersImportService` liest `EKReminder.recurrenceRules` nicht aus. Importierte Tasks bekommen `recurrencePattern = "none"` (Default).

## Fix-Ansatz

`EKReminder.recurrenceRules` beim Import auslesen und auf FocusBlox' `recurrencePattern` mappen.

## Scope

| Metrik | Wert |
|--------|------|
| Dateien | 3 (MODIFY) + Tests |
| LoC | ~40 |
| Risiko | LOW |

## Aenderungen

| File | Change | Description |
|------|--------|-------------|
| `Sources/Models/ReminderData.swift` | MODIFY | Neues Feld `recurrencePattern: String` aus `EKReminder.recurrenceRules` extrahieren |
| `Sources/Services/RemindersImportService.swift` | MODIFY | `recurrencePattern` beim `LocalTask`-Init uebergeben |
| `Sources/Testing/MockEventKitRepository.swift` | MODIFY | Mock-Reminders mit Recurrence fuer UI Tests |

## Details

### 1. ReminderData: Recurrence-Feld hinzufuegen

```swift
struct ReminderData {
    // ... bestehende Felder ...
    let recurrencePattern: String  // "none", "daily", "weekly", "biweekly", "monthly"
}
```

**Mapping von EKRecurrenceRule:**

| EKRecurrenceFrequency | interval | → recurrencePattern |
|-----------------------|----------|---------------------|
| `.daily` | 1 | "daily" |
| `.weekly` | 1 | "weekly" |
| `.weekly` | 2 | "biweekly" |
| `.monthly` | 1 | "monthly" |
| Alles andere | * | "none" |

Aus `recurrenceRules?.first` lesen (Apple Reminders unterstuetzt nur eine Regel pro Reminder).

### 2. RemindersImportService: Pattern uebergeben

```swift
let task = LocalTask(
    title: reminder.title,
    importance: mapReminderPriority(reminder.priority),
    dueDate: reminder.dueDate,
    recurrencePattern: reminder.recurrencePattern,  // NEU
    taskDescription: reminder.notes,
    externalID: nil,
    sourceSystem: "local"
)
```

### 3. Bestehende importierte Tasks (Migration)

Bereits importierte Tasks haben `recurrencePattern = "none"`. Diese werden NICHT automatisch migriert — das waere ein Daten-Eingriff auf bestehende Tasks. Der User kann den Task loeschen und neu importieren, oder manuell das Pattern setzen.

## Expected Behavior

**Vorher:** "Zehnagel" (woechentlich in Reminders) importiert → `recurrencePattern = "none"` → immer sichtbar in "Alle Tasks" → auch wenn naechste Woche faellig

**Nachher:** "Zehnagel" importiert → `recurrencePattern = "weekly"` → `isVisibleInBacklog` filtert → nur sichtbar wenn dueDate <= heute → nach Erledigen erstellt RecurrenceService neue Instanz naechste Woche

## Test Plan

### Unit Tests

| # | Test | Erwartung |
|---|------|-----------|
| 1 | `testReminderData_dailyRecurrence` | EKReminder mit daily rule → recurrencePattern == "daily" |
| 2 | `testReminderData_weeklyRecurrence` | EKReminder mit weekly rule → recurrencePattern == "weekly" |
| 3 | `testReminderData_biweeklyRecurrence` | EKReminder mit weekly/interval=2 → recurrencePattern == "biweekly" |
| 4 | `testReminderData_monthlyRecurrence` | EKReminder mit monthly rule → recurrencePattern == "monthly" |
| 5 | `testReminderData_noRecurrence` | EKReminder ohne rule → recurrencePattern == "none" |
| 6 | `testImport_setsRecurrencePattern` | Importierter Task hat korrektes recurrencePattern |
| 7 | `testImport_recurringTaskHiddenWhenFuture` | Importierter recurring Task mit Future-Date ist nicht in fetchIncompleteTasks |

## Nicht im Scope

- Migration bestehender importierter Tasks
- recurrenceWeekdays/recurrenceMonthDay aus EKRecurrenceRule (kann spaeter ergaenzt werden)
- Yearly recurrence (nicht in FocusBlox unterstuetzt)
