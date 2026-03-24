# Context: RW_3.1b — Calendar Task Drop: iOS Schedule/Unschedule Logic

## Request Summary

Phase B von RW_3.1: Business-Logik zum Einplanen/Entplanen von Tasks auf der Timeline. Tasks werden per Drop zeitlich fixiert (ohne FocusBlock/EventKit), per Tap/Swipe wieder entplant.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | Hat scheduledDate/scheduledDuration aus Phase A |
| `Sources/Models/PlanItem.swift` | Mirror-Properties aus Phase A |
| `Sources/Models/TimelineItem.swift` | .scheduledTask Case aus Phase A |
| `Sources/Models/PlanItemTransfer.swift` | Transferable fuer Drag&Drop — unveraendert |
| `Sources/Services/SyncEngine.swift` | MODIFY: Neue scheduleTask()/unscheduleTask() Methoden |
| `Sources/Views/PlanningView.swift` | MODIFY: Drop-Handler aendern (SyncEngine statt eventKitRepo) |
| `Sources/Views/TimelineView.swift` | Hat bereits onScheduleTask Callback — kein Change noetig |
| `Sources/Views/MiniBacklogView.swift` | MODIFY: Scheduled Tasks ausfiltern |
| `Sources/Services/FocusBlockActionService.swift` | Pattern-Referenz fuer Mutual Exclusion |

## Existing Patterns

- **SyncEngine Pattern:** `findTask(byID:)` → Property aendern → `modelContext.save()` → ggf. Reconciliation
- **Mutual Exclusion:** `assignedFocusBlockID` wird an Write-Sites geraeumt, nicht im Model
- **Drop Flow:** MiniBacklogView → PlanItemTransfer → TimelineView Drop → PlanningView.scheduleTask()
- **Current scheduleTask():** Erstellt CalendarEvent via eventKitRepo — muss auf SyncEngine umgestellt werden

## Dependencies

- **Upstream:** LocalTask (SwiftData), SyncEngine, PlanItemTransfer
- **Downstream:** PlanningView (rendert Timeline), MiniBacklogView (zeigt unscheduled Tasks)
- **Mutual Exclusion mit:** assignedFocusBlockID (FocusBlock-System)

## Existing Specs

- `docs/specs/rework/3.1-calendar-task-drop.md` — Parent Story
- `docs/specs/rework/3.1a-calendar-task-drop-model-layer.md` — Phase A (erledigt)

## Scope (aus Parent Spec abgeleitet)

**Neue Methoden:**
1. `SyncEngine.scheduleTask(itemID:date:duration:)` — setzt scheduledDate + optional scheduledDuration, raeumt assignedFocusBlockID
2. `SyncEngine.unscheduleTask(itemID:)` — raeumt scheduledDate + scheduledDuration

**View-Aenderungen:**
3. `PlanningView.scheduleTask()` — ruft SyncEngine statt eventKitRepo auf
4. `PlanningView.loadData()` — laedt scheduled Tasks fuer selectedDate aus SwiftData
5. `MiniBacklogView` — filtert scheduled Tasks aus

## Risks & Considerations

- Mutual Exclusion muss an ALLEN Write-Sites konsistent sein
- PlanningView.scheduleTask() aendert Verhalten — bestehende Drop-Tests koennten brechen
- Completion-Logik muss scheduledDate ebenfalls raeumen (ggf. Phase C)
- Notification Reconciliation Trigger erst in Phase D — hier nur vorbereiten
