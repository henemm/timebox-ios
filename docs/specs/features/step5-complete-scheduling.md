---
entity_id: step5-complete-scheduling
type: feature
created: 2026-01-13
status: complete
workflow: step5-complete-scheduling
---

# Step 5: Complete Scheduling

## Approval

- [x] Approved for implementation (2026-01-13)

## Purpose

Wenn ein Task per Drag & Drop in den Kalender eingeplant wird, soll die zugehoerige Apple Reminder automatisch als erledigt markiert werden. Dies vervollstaendigt den Scheduling-Flow gemaess Projekt-Spec.

## Scope

| File | Change | Description |
|------|--------|-------------|
| `Services/EventKitRepository.swift` | MODIFY | Add markReminderComplete() |
| `Views/PlanningView.swift` | MODIFY | Call markReminderComplete in scheduleTask |

**Estimated:** +13 LoC

## Implementation Details

### 1. EventKitRepository.markReminderComplete()

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

### 2. PlanningView.scheduleTask()

```swift
private func scheduleTask(_ transfer: PlanItemTransfer, at startTime: Date) {
    Task {
        do {
            // ... existing createCalendarEvent code ...

            // Mark reminder as complete
            try eventKitRepo.markReminderComplete(reminderID: transfer.id)

            await loadData()
            scheduleFeedback.toggle()
        } catch {
            // ...
        }
    }
}
```

## Test Plan

### Unit Tests (TDD RED)

1. **markReminderComplete sets isCompleted:**
   - GIVEN: A reminder exists in EventStore
   - WHEN: markReminderComplete(reminderID) is called
   - THEN: reminder.isCompleted == true

2. **markReminderComplete with invalid ID:**
   - GIVEN: No reminder with given ID exists
   - WHEN: markReminderComplete("invalid") is called
   - THEN: No error thrown (silent fail)

### UI Tests

1. **Scheduled task disappears from backlog:**
   - GIVEN: Task visible in MiniBacklog
   - WHEN: Task is dragged to timeline
   - THEN: Task no longer appears in MiniBacklog

## Acceptance Criteria

- [x] Reminder wird als complete markiert nach Drag-to-Calendar
- [x] Task verschwindet aus MiniBacklog nach Scheduling
- [x] Calendar Event wird erstellt (bestehendes Verhalten)
- [x] Kein Crash bei ungueltigem Reminder-ID

## Changelog

- 2026-01-13: Initial spec created
- 2026-01-13: Implementation complete - all tests passing
