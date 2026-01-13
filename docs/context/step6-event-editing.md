# Context: Step 6 - Event Editing

## Request Summary
Events im Kalender sollen bearbeitbar sein: antippen für Details, löschen/unschedule um zurück in den Backlog zu kommen.

## Aktueller Stand

**createCalendarEvent:**
- Erstellt EKEvent mit title, start, end
- Speichert KEINE Referenz zum Reminder

**markReminderComplete:**
- Markiert Reminder als erledigt
- Kein Weg zurück (incomplete setzen fehlt)

**EventBlock:**
- Zeigt Event in Timeline
- Nicht interaktiv (kein Tap-Handler)

## Problem: Reminder ↔ Event Verknüpfung

Aktuell gibt es keine Verbindung zwischen dem erstellten Calendar Event und dem ursprünglichen Reminder. Um "unschedule" zu ermöglichen, müssen wir:

1. **Bei Scheduling:** ReminderID im Event speichern (z.B. in `notes`)
2. **Bei Unschedule:** ReminderID aus Event lesen → Reminder incomplete setzen

## Geplante Änderungen

| Datei | Änderung |
|-------|----------|
| `EventKitRepository.swift` | createCalendarEvent um reminderID erweitern |
| `EventKitRepository.swift` | deleteCalendarEvent() hinzufügen |
| `EventKitRepository.swift` | markReminderIncomplete() hinzufügen |
| `CalendarEvent.swift` | reminderID Property aus notes parsen |
| `EventBlock.swift` | Tap-Handler + Action Sheet |
| `PlanningView.swift` | onUnschedule Callback |
| `TimelineView.swift` | onEventTap Callback durchreichen |

## Technischer Ansatz

### ReminderID Speichern
```swift
func createCalendarEvent(title: String, startDate: Date, endDate: Date, reminderID: String) throws {
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate
    event.notes = "reminderID:\(reminderID)"  // Versteckte Referenz
    event.calendar = eventStore.defaultCalendarForNewEvents
    try eventStore.save(event, span: .thisEvent)
}
```

### ReminderID Auslesen
```swift
struct CalendarEvent {
    var reminderID: String? {
        guard let notes = notes,
              notes.hasPrefix("reminderID:") else { return nil }
        return String(notes.dropFirst("reminderID:".count))
    }
}
```

## Risks & Considerations

- **Bestehende Events:** Alte Events ohne reminderID können nicht unscheduled werden
- **Notes-Feld:** User könnte Notes in Kalender-App bearbeiten und reminderID verlieren
- **Gelöschte Reminders:** Was wenn der Reminder nicht mehr existiert?
