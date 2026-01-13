# Context: Step 5 - Complete Scheduling

## Request Summary
Wenn ein Task in den Kalender gezogen wird, soll die zugehoerige Erinnerung in Apple Reminders automatisch als erledigt markiert werden.

## Aktueller Stand

**PlanningView.scheduleTask():**
- Erstellt Calendar Event via `createCalendarEvent()`
- Reminder wird NICHT als complete markiert

**PlanItemTransfer:**
- Hat `id` (= reminderID aus PlanItem)
- Wird beim Drag & Drop uebergeben

## Related Files

| File | Relevance |
|------|-----------|
| `Services/EventKitRepository.swift` | Braucht `markReminderComplete(reminderID:)` |
| `Views/PlanningView.swift` | scheduleTask() muss erweitert werden |
| `Models/PlanItemTransfer.swift` | Hat bereits die reminderID |

## Projekt-Spec Anforderung

> `scheduleTask(item: PlanItem, start: Date)` -> Creates EKEvent, marks EKReminder as complete.

## Geplante Erweiterungen

1. **EventKitRepository.markReminderComplete(reminderID:)**
   - Reminder via calendarItemIdentifier finden
   - `reminder.isCompleted = true` setzen
   - `eventStore.save(reminder)` aufrufen

2. **PlanningView.scheduleTask()**
   - Nach `createCalendarEvent()` aufrufen: `markReminderComplete(transfer.id)`

## Technische Details

```swift
// EventKit: Reminder als complete markieren
func markReminderComplete(reminderID: String) throws {
    guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
        return
    }
    reminder.isCompleted = true
    try eventStore.save(reminder, commit: true)
}
```

## Risks & Considerations

- **Undo:** Kein Undo wenn Reminder einmal complete ist
- **Sync:** Reminder verschwindet aus Backlog nach naechstem sync()
- **Fehlerbehandlung:** Was wenn markComplete fehlschlaegt aber Event erstellt wurde?

---

## Analysis

### Affected Files (with changes)

| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `Services/EventKitRepository.swift` | MODIFY | Add markReminderComplete() | +10 |
| `Views/PlanningView.swift` | MODIFY | Call markReminderComplete in scheduleTask | +3 |

### Scope Assessment

- **Files:** 2
- **Estimated LoC:** +13
- **Risk Level:** LOW

### Technical Approach

1. **EventKitRepository.markReminderComplete(reminderID:)**
   ```swift
   func markReminderComplete(reminderID: String) throws {
       guard reminderAuthStatus == .fullAccess else {
           throw EventKitError.notAuthorized
       }
       guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
           return // Silent fail if reminder not found
       }
       reminder.isCompleted = true
       reminder.completionDate = Date()
       try eventStore.save(reminder, commit: true)
   }
   ```

2. **PlanningView.scheduleTask()** - Add after createCalendarEvent:
   ```swift
   try eventKitRepo.markReminderComplete(reminderID: transfer.id)
   ```

### Data Flow

```
User drops task on Timeline
    → scheduleTask(transfer, startTime)
        → createCalendarEvent(title, start, end)
        → markReminderComplete(transfer.id)  // NEW
        → loadData() (task disappears from MiniBacklog)
```

### Open Questions

- [x] Reminder ID bereits in PlanItemTransfer.id verfuegbar ✓
