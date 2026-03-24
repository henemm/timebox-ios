# Context: RW_3.1c — ScheduledTaskBlock + Context Menu

## Request Summary

Ersetze die Platzhalter-Kapseln (Phase B) fuer geplante Tasks auf der Timeline durch eine eigene `ScheduledTaskBlock.swift` View mit eigenem Design und Context Menu (Entplanen, Focus Sprint starten).

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/TimelineView.swift` | Enthaelt `ScheduledTaskOverlay` (Phase B Platzhalter) — wird durch ScheduledTaskBlock ersetzt |
| `Sources/Views/BlockPlanningView.swift` | Enthaelt `TimelineScheduledTaskRow` (Phase B Platzhalter, Zeile 1279) — wird durch ScheduledTaskBlock ersetzt |
| `Sources/Views/PlanningView.swift` | Nutzt `confirmationDialog` fuer Unschedule — wird durch Context Menu auf ScheduledTaskBlock ersetzt |
| `Sources/Views/EventBlock.swift` | Referenz-Design: So sehen CalendarEvents auf der Timeline aus |
| `Sources/Models/TimelineItem.swift` | `.scheduledTask(id:title:)` Case + `PositionedScheduledTask` Struct |
| `Sources/Views/NextUpSection.swift` | Referenz: Context Menu Pattern mit Focus Sprint, Bearbeiten, Loeschen |
| `Sources/Services/FocusBlockActionService.swift` | `startImmediate()` — Focus Sprint aus Context Menu starten |
| `Sources/Services/SyncEngine.swift` | `unscheduleTask()` — Entplanen-Logik (Phase B) |

## Existing Patterns

- **Context Menu:** `.contextMenu { }` mit `Label("Text", systemImage: "icon")` — siehe NextUpSection Zeile 49
- **EventBlock Design:** RoundedRectangle mit `.fill(color.opacity(0.3))`, Title + Zeitrange, CategoryBadge
- **ScheduledTaskOverlay (Platzhalter):** Orange Kapsel mit `.fill(.orange.opacity(0.2))`, Stroke `.orange`, nur Title
- **TimelineScheduledTaskRow (Platzhalter):** Orange Sidebar-Strich (4px), Title, `.fill(.orange.opacity(0.1))`
- **Tap-Handling:** Aktuell ueber `confirmationDialog` — Phase C ersetzt durch `.contextMenu`
- **AccessibilityIdentifier:** `scheduledTaskBlock_\(taskID)` — bereits in beiden Platzhaltern gesetzt

## Dependencies

- **Upstream:** LocalTask.scheduledDate/scheduledDuration (Phase A), SyncEngine.scheduleTask/unscheduleTask (Phase B)
- **Downstream:** PlanningView + BlockPlanningView konsumieren die neue View

## Existing Specs

- `docs/specs/rework/3.1-calendar-task-drop.md` — Parent Story
- `docs/specs/rework/3.1a-calendar-task-drop-model-layer.md` — Phase A (ERLEDIGT)
- `docs/specs/rework/3.1b-calendar-task-drop-schedule-logic.md` — Phase B (ERLEDIGT)

## Risks & Considerations

- **Zwei Platzhalter-Views ersetzen:** ScheduledTaskOverlay (TimelineView) + TimelineScheduledTaskRow (BlockPlanningView) — beide muessen durch eine gemeinsame ScheduledTaskBlock View ersetzt werden
- **Context Menu statt confirmationDialog:** PlanningView + BlockPlanningView nutzen aktuell confirmationDialog fuer Unschedule — wird durch Context Menu auf dem Block selbst ersetzt
- **Focus Sprint Integration:** FocusBlockActionService.startImmediate() muss aus Context Menu aufrufbar sein — braucht modelContext + eventKitRepo
- **Scope-Limit:** Max 4-5 Dateien, ±250 LoC
