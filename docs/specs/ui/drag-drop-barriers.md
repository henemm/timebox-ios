---
entity_id: drag-drop-barriers
type: feature
created: 2026-04-20
updated: 2026-04-20
status: draft
version: "2.0"
tags: [drag-drop, calendar, timeline, ux]
---

# Drag & Drop Barrieren entfernen (Feature #284)

## Approval

- [ ] Approved

## Purpose

Timeline-Elemente in der BlockPlanningView blockieren Drag-Operationen: Wenn ein FocusBlock über ein bestehendes Event oder einen anderen Block gezogen wird, konsumiert das darunterliegende Element den Drop-Event und verhindert das Ablegen. Das liegt daran, dass der einzige `.onDrop`-Handler auf dem Canvas-ZStack liegt (Zeile 239), aber die überlagernden Views im `TimelineLayout` die Drop-Events abfangen. Zusätzlich fehlt `.draggable` auf `TimelineEventRow` und `ScheduledTaskBlock`.

## Source

- **File:** `Sources/Views/BlockPlanningView.swift` — TimelineLayout (Zeilen 147–222), Canvas-DropDelegate (Zeile 239), TimelineEventRow (Zeilen 1222–1276), TimelineDropDelegate (Zeilen 1281–1325)
- **File:** `Sources/Views/ScheduledTaskBlock.swift` — kein `.draggable` vorhanden

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CalendarEventTransfer` | model | Transferable für Drag-Operationen |
| `TimelineDropDelegate` | struct | Drop-Handler mit Quarter-Hour-Snapping |
| `TimelineLocationCalculator` | struct | Berechnet Zeit aus Y-Position |
| `FocusBlock.snapToQuarterHour` | method | Snap auf 15-Min-Grenzen |

## Implementation Details

### HAUPTFIX — Alle Timeline-Rows als Drop-Ziele registrieren

**Problem:** `TimelineLayout` enthält interaktive Views (Events, Blocks, Slots, Tasks) die per ZStack ÜBER dem Canvas-`.onDrop` liegen. SwiftUI gibt Drop-Events an die oberste View → der Canvas-Handler wird nie erreicht wenn man über ein bestehendes Element zieht.

**Lösung:** Jede Timeline-Row in BlockPlanningView bekommt einen eigenen `.onDrop(of:delegate:)` mit dem GLEICHEN `TimelineDropDelegate`. Damit leiten alle Elemente Drops korrekt weiter statt sie zu blockieren.

In `BlockPlanningView.timelineContent`, nach jedem `.timelinePosition()`:

```swift
// Auf TimelineEventRow, TimelineFocusBlockRow, TimelineFreeSlotRow, ScheduledTaskBlock:
.onDrop(of: [.calendarEvent], delegate: TimelineDropDelegate(
    hourHeight: hourHeight,
    startHour: startHour,
    selectedDate: selectedDate,
    focusBlocks: focusBlocks,
    dropTargetTime: $dropTargetTime,
    onDrop: handleTimelineDrop
))
```

`handleTimelineDrop` ist eine extrahierte Closure die den `onDrop`-Callback aus Zeile 245 kapselt.

### Barriere 2 — TimelineEventRow: `.draggable` hinzufügen

`TimelineEventRow` (Zeile 1237) bekommt `.draggable(CalendarEventTransfer(from: event))` mit Guard `!event.isReadOnly`. Read-only Events zeigen ein Lock-Icon.

Der `onDrop`-Callback wird erweitert: Anhand der ID wird geprüft ob es ein FocusBlock oder CalendarEvent ist, und die passende Move-Funktion aufgerufen.

### Barriere 3 — ScheduledTaskBlock: `.draggable` hinzufügen

`ScheduledTaskBlock` bekommt `.draggable(CalendarEventTransfer(id: taskID, ...))` — nutzt den bestehenden Transfer-Typ. Im Drop-Callback wird anhand der ID dispatcht.

### Barriere 4 — Visuelles Feedback für nicht-draggable Items

- Vergangene FocusBlöcke (`!block.isFuture`): `.opacity(0.6)` auf TimelineFocusBlockRow
- Read-only Events in TimelineEventRow: Lock-Icon (`.lock.fill`)

## Acceptance Criteria

1. Ein FocusBlock kann über JEDES bestehende Element gezogen werden ohne blockiert zu werden
2. Events im Blox-Tab können per Drag verschoben werden (wenn nicht read-only)
3. Eingeplante Tasks können per Drag verschoben werden
4. Read-only Events zeigen ein Lock-Icon
5. Vergangene FocusBlöcke sind visuell als nicht-verschiebbar erkennbar
6. Drop-Preview-Indicator zeigt korrekte Zielzeit beim Ziehen über bestehende Elemente
7. Bestehende D&D-Funktionalität (FocusBlock-Drag im freien Bereich) bleibt unverändert

## Known Limitations

- Zwei parallele Drop-Systeme (TimelineView vs. BlockPlanningView) werden nicht vereinheitlicht
- Live-Preview beim Drag (Ghosting), Snap-Haptik und Undo sind nicht im Scope
- `moveCalendarEvent` erfordert Schreibzugriff auf EventKit — read-only Kalender zeigen Fehler via `.errorAlert()`

## Changelog

- 2026-04-20: v2.0 — HAUPTFIX ergänzt: Drop-Barriere durch .onDrop auf allen Timeline-Rows lösen
- 2026-04-19: v1.0 — Initial spec
