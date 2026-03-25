# Context: RW_2.1c — DayView Phase C: Tages-Timeline

## Request Summary
Ersetze den Placeholder im Daytime-Modus der DayView durch eine vollstaendige TimelineView-Integration. Die TimelineView existiert bereits (wird von PlanningView genutzt) und soll wiederverwendet werden.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | Hauptview — daytime-Case muss von Placeholder zu TimelineView wechseln |
| `Sources/Views/TimelineView.swift` | Bestehende Timeline-Komponente (6:00–22:00, Stunden-Grid, Events + Tasks) |
| `Sources/Models/TimelineItem.swift` | Unified Model fuer Items auf der Timeline (.event, .focusBlock, .scheduledTask) |
| `Sources/Views/EventBlock.swift` | Kalender-Event-Block fuer Timeline-Overlay |
| `Sources/Views/ScheduledTaskBlock.swift` | Geplante-Task-Block fuer Timeline-Overlay |
| `Sources/Models/GapFinder.swift` | Luecken-Finder (bereits von Morning Mode genutzt) |
| `Sources/Services/EventKitRepository.swift` | Kalender-Zugriff (fetchCalendarEvents, fetchFocusBlocks, requestAccess) |
| `Sources/Models/CalendarEvent.swift` | Kalender-Event Model |
| `Sources/Models/FocusBlock.swift` | FocusBlock Model |
| `FocusBloxUITests/DayViewUITests.swift` | Bestehende UI Tests (RW_2.1a + 2.1b) — braucht neue Daytime-Tests |

## Existing Patterns
- **Morning Mode Pattern:** DayView laedt Daten via `loadMorningData()` in `.task {}` — gleicher Pattern fuer Daytime
- **PlanningView Pattern:** Nutzt TimelineView mit allen Callbacks — DayView nutzt TimelineView read-only (keine Drag-and-Drop)
- **Permission Flow:** `eventKitRepo.requestAccess()` → denied → ContentUnavailableView + Settings-Button
- **Scheduled Tasks laden:** SyncEngine → filter `isScheduled` → map zu TimelineItem

## Dependencies
- **Upstream:** EventKitRepository, SyncEngine, GapFinder, TimelineView, TimelineItem
- **Downstream:** Nichts — DayView ist Leaf-View (nur Navigation zeigt sie)

## Existing Specs
- `docs/specs/rework/2.1-day-view.md` — Master-Spec fuer alle DayView-Phasen
- `docs/specs/rework/2.1a-day-view-skeleton.md` — Phase A (erledigt)
- `docs/specs/rework/2.1b-day-view-morning-mode.md` — Phase B (erledigt)

## Current State
- DayPhase.daytime zeigt: `ContentUnavailableView("Dein Tag", systemImage: "sun.max", description: "Timeline kommt bald")`
- `.task {}` laedt nur bei `.morning` — muss auch `.daytime` abdecken
- State-Variablen (calendarEvents, focusBlocks, isLoading, isPermissionDenied) existieren bereits
- Scheduled Tasks: State `scheduledTasks: [TimelineItem]` fehlt noch — muss hinzugefuegt werden

## Scope
- **Aendern:** DayView.swift (~100 LoC additions), DayViewUITests.swift (~80 LoC additions)
- **Nicht aendern:** TimelineView, EventBlock, ScheduledTaskBlock, EventKitRepository (alle ready-to-use)
- **Wichtig:** DayView daytime ist READONLY — kein onScheduleTask, kein onMoveEvent (das kommt in RW_3+)

## Risks & Considerations
- TimelineView hat optional Callbacks — alle nil lassen fuer read-only Modus
- `.task {}` muss auch bei Phase-Wechsel (z.B. 11:59→12:00) reagieren
- Mock-Daten fuer UI Tests: Phase/Uhrzeit muss simulierbar sein
