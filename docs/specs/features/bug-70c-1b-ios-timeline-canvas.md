---
entity_id: bug-70c-1b-ios-timeline-canvas
type: feature
created: 2026-03-05
updated: 2026-03-05
status: draft
version: "1.0"
tags: [ios, timeline, canvas, focusblock, drag-drop]
---

# Bug 70c-1b — iOS Timeline Canvas Rebuild

## Approval

- [ ] Approved

## Purpose

Ersetzt die listenbasierte iOS-Timeline in `BlockPlanningView` durch einen canvas-basierten Ansatz, der die in 70c-1a nach `Sources/` extrahierte `TimelineLayout`-Engine nutzt. Blocks erhalten duration-proportionale Hoehe und korrekte Collision Detection — Paritat mit der macOS-Timeline.

## Source

- **File:** `Sources/Views/BlockPlanningView.swift`
- **Identifier:** `struct BlockPlanningView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TimelineLayout` | layout (Sources/Layouts/) | Positioniert Events, FocusBlocks und FreeSlots absolut auf dem Canvas |
| `TimelineItem` + `groupOverlappingItems()` | model (Sources/Models/TimelineItem.swift) | Kollisionserkennung und Item-Gruppierung |
| `PositionedItem` | model (Sources/Models/TimelineItem.swift) | Positioniertes Event auf dem Canvas |
| `PositionedEvent` | model (Sources/Models/TimelineItem.swift) | Positioniertes CalendarEvent auf dem Canvas |
| `PositionedFocusBlock` | model (Sources/Models/TimelineItem.swift) | Positionierter FocusBlock — wird von private (MacTimelineView) nach Sources/ verschoben |
| `FocusBlock.durationMinutes` | property (Sources/Models/) | Basis fuer duration-proportionale Hoehe |
| `FocusBlock.snapToQuarterHour()` | method (Sources/Models/) | Snap-to-Grid beim Drop |
| `CalendarEventTransfer` | model (Sources/) | Drag-Payload fuer Events (erstellt in Bug 70b) |
| `FocusBlockTasksSheet` | view | Oeffnet sich bei Block-Tap |
| `EditFocusBlockSheet` | view | Oeffnet sich bei Edit-Tap |
| `MainTabView` | view | Zeigt BlockPlanningView im "Blox" Tab |

## Implementation Details

### Neue Struktur in `BlockPlanningView.swift`

```swift
// VORHER: ForEach(hours) { hour in TimelineHourRow(...) }
// NACHHER: ScrollView > ZStack > hourGrid + TimelineLayout

var timelineContent: some View {
    ScrollView {
        ZStack(alignment: .topLeading) {
            hourGrid          // Hintergrund: Stunden-Linien mit accessibilityIdentifier
            TimelineLayout {  // Canvas: positioniert Items absolut
                ForEach(positionedItems, ...) { item in
                    switch item {
                    case .focusBlock(let pb): TimelineFocusBlockRow(pb)
                    case .event(let pe):      TimelineEventRow(pe)
                    case .freeSlot(let ps):   TimelineFreeSlotRow(ps).frame(minHeight: 50)
                    }
                }
            }
        }
        .dropDestination(for: ...) { items, location in
            let time = calculateTimeFromLocation(location)
            // Drop-Handling
        }
    }
}
```

### Neue computed vars

```swift
// Berechnet PositionedFocusBlock-Liste aus FocusBlocks + CalendarEvents
private var positionedItems: [PositionedItem] { ... }

// Mapping von Drop-Location (CGPoint) auf Uhrzeit (Date)
private func calculateTimeFromLocation(_ point: CGPoint) -> Date { ... }

// Stunden-Raster als Hintergrund
private var hourGrid: some View { ... }
```

### Aenderungen an `Sources/Models/TimelineItem.swift`

`PositionedFocusBlock` wird von `private` in `MacTimelineView.swift` hierher verschoben und `public` gemacht (+6 Zeilen):

```swift
public struct PositionedFocusBlock: Identifiable {
    public let id: UUID
    public let focusBlock: FocusBlock
    public let column: Int
    public let totalColumns: Int
    public let startMinute: Int  // Minuten seit Tagesbeginn
    public let durationMinutes: Int
}
```

### Aenderungen an `FocusBloxMac/MacTimelineView.swift`

- `private struct PositionedFocusBlock` entfernen
- Shared `PositionedFocusBlock` aus `Sources/` nutzen (kein Umbau der Logik)

### Geloeschte Entitaeten

- `TimelineHourRow` — komplett entfernt (ersetzt durch `hourGrid` + Canvas)
- Altes `FocusBlockView` (Dead Code in BlockPlanningView) — entfernt

### Beibehaltene Entitaeten

- `TimelineFocusBlockRow` — bleibt als Block-Cell-View, nur Padding-Anpassung
- `TimelineFreeSlotRow` — bleibt, erhaelt `.frame(minHeight: 50)`

## Expected Behavior

- **Input:** FocusBlocks und CalendarEvents fuer den selektierten Tag
- **Output:** Canvas-Timeline mit duration-proportionalen Block-Hoehen, Collision Detection (nebeneinander statt uebereinander), funktionierende Drop-Zone
- **Side effects:**
  - `FocusBlockTasksSheet` und `EditFocusBlockSheet` oeffnen sich weiterhin korrekt per Block-Tap bzw. Edit-Tap
  - Bestehende UI Tests (`FocusBlockDragDropUITests`, `EditFocusBlockUITests`) muessen nach Anpassung der Element-IDs gruen sein

## Known Limitations

- Resize-per-Drag (vertikales Strecken eines Blocks) ist NICHT Teil dieses Tickets — das ist Bug 70c-2
- watchOS-Timeline ist nicht betroffen (kein Canvas)
- `hourGrid` muss `accessibilityIdentifier("hourMarker_\(hour)")` setzen, damit UI Tests die Stunden-Marker finden koennen

## Changelog

- 2026-03-05: Initial spec created (Port des macOS Canvas-Patterns auf iOS, Scope 3 Files ~-90 LoC netto)
