# Context: macOS Planning View (MAC-014)

## Request Summary
Tagesplanung-Ansicht für macOS mit Kalender-Timeline, freien Blöcken und Drag & Drop Planung.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/PlanningView.swift` | iOS Reference: Timeline + Mini-Backlog |
| `Sources/Models/FocusBlock.swift` | Shared Model für Focus Blocks |
| `Sources/Models/CalendarEvent.swift` | Shared Model für Kalender-Events |
| `Sources/Services/EventKitRepository.swift` | Shared EventKit Integration |
| `FocusBloxMac/ContentView.swift` | Aktuell Backlog-View, braucht Tab/Segment für Planning |

## Existing Patterns

### iOS PlanningView Features
- TimelineView mit Stunden-Grid
- CalendarEvents (readonly) anzeigen
- Focus Blocks erstellen via Drag & Drop
- MiniBacklogView am unteren Rand
- EventKit für Kalender-Zugriff

### Focus Block Konzept
- Focus Block = Kalender-Event mit `focusBlock:true` in Notes
- Tasks werden in Notes als `tasks:id1|id2|id3` gespeichert
- Completion Status als `completed:id1|id2`
- Zeiten als `times:id1=120|id2=90`

## Dependencies
- **Upstream:** EventKitRepository, FocusBlock, CalendarEvent (shared)
- **Downstream:** MAC-020 (Drag & Drop) erweitert diese View

## macOS-spezifische Adaptationen

### Layout-Unterschiede zu iOS
- Mehr Platz: Kalender links, Task-Liste rechts (side-by-side)
- Größere Timeline (mehr Stunden sichtbar)
- Kein MiniBacklog am unteren Rand (stattdessen Sidebar mit Tasks)

### EventKit auf macOS
- Gleiche API wie iOS
- Benötigt `NSCalendarsUsageDescription` in Info.plist
- Benötigt Entitlement: `com.apple.security.personal-information.calendars`

## Risks & Considerations
- EventKit Permissions auf macOS (Privacy-Dialog)
- Sandbox-Beschränkungen für Kalender-Zugriff
- Drag & Drop zwischen Views (komplexer auf macOS)
