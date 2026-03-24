# Context: RW_3.1d — GapFinder + Notifications + macOS

## Request Summary
Phase D des Calendar Task Drop Features: GapFinder muss Scheduled Tasks als belegte Slots erkennen, Notification-Reconciliation muss bei Schedule-Aenderungen getriggert werden, und macOS braucht Scheduled Task Support (Rendering + Drop).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Models/GapFinder.swift` | AENDERN: Scheduled Tasks als busy periods hinzufuegen (aktuell nur events + focusBlocks) |
| `Sources/Services/SmartNotificationEngine.swift` | AENDERN: Scheduled Tasks in buildTaskRequests beruecksichtigen |
| `Sources/Services/SyncEngine.swift` | PRUEFEN: reconcile-Aufruf nach scheduleTask/unscheduleTask |
| `FocusBloxMac/MacTimelineView.swift` | AENDERN: ScheduledTaskBlock Rendering hinzufuegen |
| `FocusBloxMac/MacPlanningView.swift` | AENDERN: scheduledTasks laden + Drop-Handler fuer Task-Scheduling |
| `Sources/Views/ScheduledTaskBlock.swift` | SHARED: Existiert bereits, wird von macOS wiederverwendet |
| `Sources/Models/TimelineItem.swift` | SHARED: Hat bereits .scheduledTask case |
| `Sources/Views/TimelineView.swift` | REFERENZ: iOS-Implementation als Vorlage |
| `Sources/Views/PlanningView.swift` | REFERENZ: iOS Schedule/Unschedule-Logik |

## Existing Patterns
- iOS PlanningView laedt scheduledTasks via Query + Filter auf selectedDate
- iOS TimelineView rendert scheduledTasks als ScheduledTaskBlock mit Context Menu
- SyncEngine.scheduleTask/unscheduleTask existieren bereits (RW_3.1b)
- ScheduledTaskBlock ist shared in Sources/ — macOS kann es direkt nutzen
- MacTimelineView nutzt TimelineLayout + .timelinePosition() fuer Positionierung
- MacTimelineView hat bereits Drop-Handler fuer MacTaskTransfer → aktuell nur FocusBlock-Erstellung

## Dependencies
- **Upstream:** LocalTask.scheduledDate/scheduledDuration (RW_3.1a), SyncEngine.scheduleTask (RW_3.1b), ScheduledTaskBlock (RW_3.1c)
- **Downstream:** GapFinder wird von MacPlanningView.computedFreeSlots und iOS PlanningView genutzt

## Existing Specs
- `docs/specs/rework/3.1-calendar-task-drop.md` — Haupt-Spec (deckt Phase D ab)
- `docs/specs/rework/3.1a-calendar-task-drop-model-layer.md` — Phase A (erledigt)
- `docs/specs/rework/3.1b-calendar-task-drop-schedule-logic.md` — Phase B (erledigt)
- `docs/specs/rework/3.1c-scheduled-task-block.md` — Phase C (erledigt)

## 3 Arbeitspakete (Phase D)

### 1. GapFinder: Scheduled Tasks als busy periods
- `GapFinder` hat aktuell nur `events` und `focusBlocks` als Input
- Neuer Parameter `scheduledTasks: [TimelineItem]` oder `scheduledTasks: [(start: Date, end: Date)]`
- Diese muessen in `busyPeriods` Array einfliessen
- Betrifft BEIDE Plattformen (shared in Sources/)

### 2. Notification Reconciliation bei Schedule-Aenderung
- `SyncEngine.scheduleTask()` und `unscheduleTask()` rufen aktuell KEIN `SmartNotificationEngine.reconcile()` auf
- ReconciliationReason `.taskChanged` existiert bereits — muss nach schedule/unschedule getriggert werden
- iOS PlanningView.scheduleTask/unscheduleTask muessen reconcile aufrufen

### 3. macOS: Scheduled Task Rendering + Drop
- **MacTimelineView:** Neuer Parameter `scheduledTasks: [TimelineItem]`, Rendering via ScheduledTaskBlock + .timelinePosition()
- **MacPlanningView:** scheduledTasks laden (analog iOS), an MacTimelineView durchreichen, Drop-Handler erweitern (aktuell nur FocusBlock-Erstellung)
- **Collision Detection:** scheduledTasks muessen in positionedItems einfliessen

## Risks & Considerations
- GapFinder-Aenderung ist shared — iOS darf nicht brechen
- macOS Drop-Handler muss zwischen "Task einplanen" und "FocusBlock erstellen" unterscheiden (Long-Press / Modifier Key?)
- LoC-Limit beachten: ~250 LoC max
