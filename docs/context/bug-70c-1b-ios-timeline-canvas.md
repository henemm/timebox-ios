# Context: Bug 70c-1b — iOS Timeline Canvas Rebuild

## Request Summary
iOS-Timeline von listenbasiert (TimelineHourRow pro Stunde) auf canvas-basiert (TimelineLayout + Collision Detection) umbauen, damit Blocks duration-proportional dargestellt werden — wie auf macOS.

## Ist-Zustand iOS
- **Listenbasiert:** `ForEach(6..<22)` rendert `TimelineHourRow` pro Stunde
- **Block-Hoehe fix:** TimelineFocusBlockRow hat ~40pt Hoehe unabhaengig von Dauer
- **Kein Spanning:** 90-Min-Block erscheint NUR in seiner Start-Stunde
- **Keine Collision Detection:** Ueberlappende Blocks werden nicht side-by-side dargestellt
- **Ungenutzter Code:** `FocusBlockView` (BPV Zeile 579-633) hat duration-proportionale Logik, wird aber nie aufgerufen

## Soll-Zustand (wie macOS)
- **Canvas-basiert:** `TimelineLayout` (CustomLayout) positioniert alle Items absolut
- **Duration-proportional:** Block-Hoehe = (durationMinutes / 60) * hourHeight
- **Collision Detection:** `TimelineItem.groupOverlapping()` → side-by-side Spalten
- **Visuelles Spanning:** 90-Min-Block spannt ueber 1.5 Stunden-Zeilen

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/BlockPlanningView.swift` | **HAUPTDATEI** — iOS Timeline, muss umgebaut werden |
| `Sources/Layouts/TimelineLayout.swift` | Shared Canvas-Engine (aus 70c-1a) — wird genutzt |
| `Sources/Models/TimelineItem.swift` | Shared Model + groupOverlapping() — wird genutzt |
| `Sources/Models/FocusBlock.swift` | Block-Model (durationMinutes, snapToQuarterHour) |
| `Sources/Models/CalendarEventTransfer.swift` | Drag & Drop Transfer-Typ |
| `FocusBloxMac/MacTimelineView.swift` | **Referenz-Implementation** — so soll iOS aussehen |
| `FocusBloxMac/MacPlanningView.swift` | macOS Integration der Timeline |
| `Sources/Services/EventKitRepository.swift` | Write-Points (updateFocusBlockTime) |

## Existing Patterns (macOS als Vorbild)

### Canvas-Rendering Pattern
```
focusBlocks + calendarEvents
  → map to [TimelineItem]
  → TimelineItem.groupOverlapping() → [[TimelineItem]]
  → PositionedItem (column, totalColumns)
  → PositionedFocusBlock / PositionedEvent
  → View mit .timelinePosition() Modifier
  → TimelineLayout.placeSubviews() positioniert absolut
```

### TimelineLayout Nutzung
```swift
TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22) {
    ForEach(positionedBlocks) { positioned in
        FocusBlockView(block: positioned.block)
            .timelinePosition(
                hour: hour, minute: minute,
                durationMinutes: block.durationMinutes,
                column: positioned.column,
                totalColumns: positioned.totalColumns
            )
    }
}
```

### PositionedFocusBlock (aktuell private in MacTimelineView)
```swift
struct PositionedFocusBlock: Identifiable {
    let id: String
    let block: FocusBlock
    let column: Int
    let totalColumns: Int
}
```

## Dependencies (Upstream)
- `TimelineLayout` (Sources/Layouts/) — Shared, fertig
- `TimelineItem` + `groupOverlapping()` (Sources/Models/) — Shared, fertig
- `PositionedItem`, `PositionedEvent` (Sources/Models/) — Shared, fertig
- `FocusBlock.durationMinutes`, `.snapToQuarterHour()` — existiert
- `CalendarEventTransfer` — existiert (Bug 70b)
- `EventKitRepository.updateFocusBlockTime()` — existiert

## Dependencies (Downstream)
- `MainTabView` → zeigt BlockPlanningView im "Blox" Tab
- `FocusBlockTasksSheet` → geoeffnet bei Block-Tap
- `EditFocusBlockSheet` → geoeffnet bei Edit-Tap
- UI Tests: `FocusBlockDragDropUITests`, `EditFocusBlockUITests`, `Bug68BlockTaskSheetUITests`

## Existing Specs
- `docs/specs/features/bug-70c-1a-shared-timeline-layout.md` — Vorgaenger (ERLEDIGT)
- `docs/artifacts/bug-70c-focusblock-resize/analysis.md` — Gesamtanalyse Bug 70c

## Key Line Numbers (BlockPlanningView.swift)
| Section | Lines | Beschreibung |
|---------|-------|-------------|
| timelineContent | 131-167 | ScrollView + ForEach hours → TimelineHourRow |
| moveFocusBlock | 327-333 | Drag & Drop Move-Handler |
| updateBlock | 300-325 | Persistenz + Notification-Reschedule |
| FocusBlockView (UNUSED) | 579-633 | Duration-proportional Code, nie aufgerufen |
| TimelineHourRow | 993-1102 | Stunden-Container mit Drop-Zone |
| blocksInHour Filter | 1072-1078 | Filter: block.startDate in [hourStart, hourEnd) |
| TimelineFocusBlockRow | 1107-1179 | Block-UI mit Drag, fixe Hoehe |
| TimelineEventRow | 1238-1293 | Calendar Event Row |
| TimelineFreeSlotRow | 1182-1236 | Freie Zeitslot-Vorschlaege |

## Risiken & Considerations

1. **Scope-Risiko:** BlockPlanningView ist 1300+ LoC — nur Timeline-Rendering aendern, NICHT Sheets/Logic
2. **Gesture-Konflikte:** `.draggable()` + ScrollView — macOS hat das gleiche Setup, funktioniert dort
3. **Bestehende UI Tests:** `FocusBlockDragDropUITests` pruefen `focusBlock_*` und `timelineDropZone_*` IDs — muessen erhalten bleiben
4. **Free Slots:** `TimelineFreeSlotRow` muss im neuen Canvas integriert werden. `.frame(minHeight: 50)` noetig fuer kurze Slots
5. **PositionedFocusBlock:** Aktuell private in MacTimelineView — muss nach Sources/Models/TimelineItem.swift extrahiert werden (6 Zeilen)
6. **Hour Grid:** Stunden-Labels (06:00, 07:00...) muessen als Hintergrund im ZStack bleiben
7. **Drop-Zonen:** Aktuell pro TimelineHourRow — im Canvas-Layout eine einzelne `.dropDestination` auf dem ZStack mit `calculateTimeFromLocation()`

---

## Analysis

### Type
Feature (iOS Timeline Rendering Rebuild)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/BlockPlanningView.swift` | MODIFY | `timelineContent` ersetzen (list→canvas), `positionedItems`/`positionedEvents`/`positionedFocusBlocks` computed vars + `hourGrid` + `calculateTimeFromLocation()` hinzufuegen. `TimelineHourRow` (110 LoC) + altes `FocusBlockView` (55 LoC) loeschen. |
| `Sources/Models/TimelineItem.swift` | MODIFY | `PositionedFocusBlock` struct hinzufuegen (+6 Zeilen, neben PositionedItem/PositionedEvent) |
| `FocusBloxMac/MacTimelineView.swift` | MODIFY | Private `PositionedFocusBlock` entfernen, shared Version aus TimelineItem.swift nutzen |

### Scope Assessment
- **Files:** 3 (+ UI Test fuer TDD RED)
- **Estimated LoC:** +80 / -170 = **netto ~-90 LoC**
- **Risk Level:** MEDIUM (Drop-Zone-Umbau + Free-Slot-Sizing, aber macOS beweist dass Pattern funktioniert)

### Technical Approach — Empfehlung

**Direkter Port des macOS Canvas-Patterns in `timelineContent`.**

Kein Hybrid-Ansatz (TimelineHourRow behalten + TimelineLayout drauf). Die beiden Ansaetze sind fundamental inkompatibel in Positioning und Drop-Zonen.

**Neue `timelineContent` Struktur:**
```swift
ScrollView(.vertical) {
    ZStack(alignment: .topLeading) {
        hourGrid                    // Stunden-Labels als Hintergrund
        TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22) {
            ForEach(positionedEvents) { ... }
            ForEach(positionedFocusBlocks) { ... }
            ForEach(computedFreeSlots) { ... }
        }
    }
    .frame(height: totalHeight)
    .dropDestination(for: CalendarEventTransfer.self) { items, location in
        let dropTime = calculateTimeFromLocation(location)
        ...
    }
}
.accessibilityIdentifier("planningTimeline")
```

**Entscheidungen:**
1. `PositionedFocusBlock` → nach `Sources/Models/TimelineItem.swift` (shared, nicht dupliziert)
2. Fester `timeColumnWidth: CGFloat = 45` auf iOS (kein GeometryReader noetig)
3. Eine `.dropDestination` auf ZStack statt 16 einzelne pro Stunde
4. `hourMarker_\(hour)` Identifier bleiben auf den Grid-Labels erhalten
5. `TimelineFocusBlockRow` bleibt als Block-View, nur Padding-Anpassung
6. `TimelineFreeSlotRow` bekommt `.frame(minHeight: 50)` gegen Clipping

### Was wird geloescht (Dead Code Cleanup)
- `TimelineHourRow` (Zeilen 993-1102) — komplett ersetzt durch TimelineLayout
- `FocusBlockView` (Zeilen 579-633) — nie aufgerufen, duration-Logik jetzt in TimelineLayout
- `blocksInHour`, `slotsInHour`, `eventsInHour` Filter — ersetzt durch groupOverlapping()

### Sequencing
1. TDD RED: UI Tests fuer Canvas-Timeline (proportionale Hoehe, Drop-Zone)
2. `PositionedFocusBlock` nach TimelineItem.swift extrahieren (+6 Zeilen)
3. `timelineContent` in BlockPlanningView ersetzen (Kern-Umbau)
4. Dead Code loeschen (TimelineHourRow, FocusBlockView)
5. Tests GREEN + Build-Validierung (iOS + macOS)

### Open Questions
- Keine — alle technischen Fragen durch macOS-Referenz beantwortet
