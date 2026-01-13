---
entity_id: step6-event-editing
type: feature
created: 2026-01-13
status: approved
workflow: step6-event-editing
---

# Step 6: Event Editing

## Approval

- [x] Approved for implementation (2026-01-13)

## Purpose

Geplante Events im Kalender sollen interaktiv sein: antippen zeigt Optionen, "Unschedule" löscht das Event und setzt den Reminder zurück auf "incomplete" - der Task erscheint wieder im Backlog.

## Scope

| File | Change | Description |
|------|--------|-------------|
| `Services/EventKitRepository.swift` | MODIFY | Add reminderID to createCalendarEvent, add deleteEvent, markReminderIncomplete |
| `Models/CalendarEvent.swift` | MODIFY | Add notes property, reminderID computed property |
| `Views/EventBlock.swift` | MODIFY | Add tap handler, action sheet |
| `Views/TimelineView.swift` | MODIFY | Pass onEventTap callback |
| `Views/PlanningView.swift` | MODIFY | Handle unschedule action |

**Estimated:** ~60 LoC

## Implementation Details

### 1. EventKitRepository - Erweiterte Methoden

```swift
// Erweitert: reminderID in notes speichern
func createCalendarEvent(title: String, startDate: Date, endDate: Date, reminderID: String) throws {
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.notes = "reminderID:\(reminderID)"
    event.calendar = eventStore.defaultCalendarForNewEvents
    try eventStore.save(event, span: .thisEvent)
}

// Neu: Event löschen
func deleteCalendarEvent(eventID: String) throws {
    guard calendarAuthStatus == .fullAccess else {
        throw EventKitError.notAuthorized
    }
    guard let event = eventStore.event(withIdentifier: eventID) else {
        return // Silent fail
    }
    try eventStore.remove(event, span: .thisEvent)
}

// Neu: Reminder wieder incomplete setzen
func markReminderIncomplete(reminderID: String) throws {
    guard reminderAuthStatus == .fullAccess else {
        throw EventKitError.notAuthorized
    }
    guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
        return
    }
    reminder.isCompleted = false
    reminder.completionDate = nil
    try eventStore.save(reminder, commit: true)
}
```

### 2. CalendarEvent - ReminderID Property

```swift
struct CalendarEvent: Identifiable, Sendable {
    // ... existing properties ...
    let notes: String?

    var reminderID: String? {
        guard let notes, notes.hasPrefix("reminderID:") else { return nil }
        return String(notes.dropFirst("reminderID:".count))
    }

    init(from event: EKEvent) {
        // ... existing ...
        self.notes = event.notes
    }
}
```

### 3. EventBlock - Interaktiv

```swift
struct EventBlock: View {
    let event: CalendarEvent
    let onTap: (() -> Void)?
    // ...

    var body: some View {
        RoundedRectangle(...)
            .onTapGesture {
                onTap?()
            }
    }
}
```

### 4. PlanningView - Action Sheet

```swift
@State private var selectedEvent: CalendarEvent?

// In TimelineView:
TimelineView(... onEventTap: { event in
    selectedEvent = event
})

// Action Sheet
.confirmationDialog("Event", isPresented: $showEventActions) {
    if selectedEvent?.reminderID != nil {
        Button("Unschedule (zurück in Backlog)") {
            unscheduleEvent(selectedEvent!)
        }
    }
    Button("Löschen", role: .destructive) {
        deleteEvent(selectedEvent!)
    }
    Button("Abbrechen", role: .cancel) {}
}
```

## Test Plan

### Unit Tests

1. **createCalendarEvent stores reminderID:**
   - GIVEN: reminderID provided
   - WHEN: createCalendarEvent called
   - THEN: event.notes contains "reminderID:xxx"

2. **markReminderIncomplete sets isCompleted false:**
   - GIVEN: completed reminder exists
   - WHEN: markReminderIncomplete called
   - THEN: reminder.isCompleted == false

3. **CalendarEvent.reminderID parses notes:**
   - GIVEN: notes = "reminderID:abc123"
   - THEN: reminderID == "abc123"

### UI Tests

1. **Tap on event shows action sheet:**
   - GIVEN: Event in timeline
   - WHEN: Tap on event
   - THEN: Action sheet appears

2. **Unschedule returns task to backlog:**
   - GIVEN: Scheduled task with reminderID
   - WHEN: Unschedule tapped
   - THEN: Event deleted, task in backlog

## Acceptance Criteria

- [ ] Events sind tappable
- [ ] Action Sheet mit Optionen erscheint
- [ ] "Unschedule" löscht Event UND setzt Reminder incomplete
- [ ] Task erscheint wieder im Backlog nach Unschedule
- [ ] "Löschen" entfernt nur das Event
- [ ] Bestehende Events ohne reminderID zeigen nur "Löschen"

## Changelog

- 2026-01-13: Initial spec created
