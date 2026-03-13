# Bug 70b: FocusBlock verschieben per Drag & Drop — Analyse

## KORREKTUR nach Devil's Advocate Challenge (Verdict: SCHWACH)

**Meine erste Analyse war fundamental falsch:**
- Behauptung "iOS funktioniert bereits" war FALSCH
- `PlanningView` (mit EventBlock-Drag) ist NICHT der aktive Tab
- `BlockPlanningView` ist der aktive Tab — und dort fehlt Drag & Drop GENAUSO wie auf macOS
- Scope war zu klein geschaetzt (3 Dateien → 5 Dateien)

**Zusaetzlich entdeckter Bug:** macOS `MacPlanningView.updateBlockTime()` (Zeile 455-470) persistiert NICHT zu EventKit — nur lokaler State-Update

## Tatsaechliche iOS-Architektur

**Aktiver Tab:** `MainTabView.swift:11` → `BlockPlanningView()` (NICHT `PlanningView`)

**BlockPlanningView Zeile 140:**
```swift
events: calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock },
```
FocusBlocks werden EXPLIZIT aus der Event-Liste gefiltert. Sie erscheinen als eigene `TimelineFocusBlockRow` — NICHT als EventBlocks.

**TimelineFocusBlockRow (Zeile 1086-1154):**
- Hat `.onTapGesture` und `.accessibilityIdentifier("focusBlock_\(block.id)")`
- Hat KEIN `.draggable()` — identisches Problem wie macOS FocusBlockView

**TimelineHourRow (Zeile 980-1079):**
- Rendert FocusBlocks, FreeSlots, CalendarEvents pro Stunde
- Hat KEINE Drop-Destinations — weder fuer CalendarEventTransfer noch fuer andere Typen

## Tatsaechlicher Befund: BEIDE Plattformen fehlen komplett

| Aspekt | iOS | macOS |
|--------|-----|-------|
| FocusBlock draggable? | NEIN | NEIN |
| Drop-Zonen fuer Moves? | NEIN | NEIN |
| Move-Handler verdrahtet? | NEIN | NEIN |
| EventKit-Persistierung? | JA (updateBlock, Zeile 300) | NEIN (nur lokaler State, Zeile 455-470) |

## Fix-Ansatz (korrigiert)

### Dateien und Aenderungen (~100 LoC, 5 Dateien)

**1. CalendarEventTransfer.swift (+6 LoC) — Shared**
- Neuer `init(from block: FocusBlock)` — Wiederverwendung statt neuer Transfer-Typ

**2. BlockPlanningView.swift (~30 LoC) — iOS**
- `.draggable(CalendarEventTransfer(from: block))` auf TimelineFocusBlockRow (nur future Blocks)
- Drop-Zones in TimelineHourRow: `.dropDestination(for: CalendarEventTransfer.self)` pro Stunde
- `onMoveFocusBlock` Callback durch die Kette: TimelineHourRow → BlockPlanningView
- Move-Handler: `snapToQuarterHour()` → `eventKitRepo.updateFocusBlockTime()` → `loadData()`

**3. MacTimelineView.swift (~25 LoC) — macOS**
- `.draggable(CalendarEventTransfer(from: block))` auf FocusBlockView (nur future Blocks)
- `.dropDestination(for: CalendarEventTransfer.self)` auf Timeline-Ebene
- `onMoveFocusBlock` Callback hinzufuegen
- Drop-Handler: `calculateTimeFromLocation()` → `onMoveFocusBlock`

**4. MacPlanningView.swift (~20 LoC) — macOS**
- `onMoveFocusBlock` verdrahten
- Move-Handler: `snapToQuarterHour()` → `eventKitRepo.updateFocusBlockTime()` → `loadCalendarEvents()`
- NEBENFIX: `updateBlockTime()` (Zeile 455-470) auch EventKit-Persistierung hinzufuegen

**5. EventBlock.swift / TimelineFocusBlockRow (+1 LoC) — Accessibility**
- `.accessibilityIdentifier()` sicherstellen fuer UI Tests

### Snapping-Konsistenz
- iOS TimelineHourRow: Drop-Destination pro Stunde, Snap auf Stundenbeginn (hour:00)
  - Alternativ: Viertelstunden-Sub-Zones wie QuarterHourDropZone (besser, aber mehr Code)
- macOS: `calculateTimeFromLocation()` nutzt floor `(minute / 15) * 15`
  - `FocusBlock.snapToQuarterHour()` nutzt round-to-nearest `((minute + 7) / 15) * 15`
  - Empfehlung: Beide auf round-to-nearest vereinheitlichen

### Call-Sites (KEIN Dead Code)
- iOS: `.draggable()` → SwiftUI Drag → Drop auf TimelineHourRow → `onMoveFocusBlock` → `eventKitRepo.updateFocusBlockTime()`
- macOS: `.draggable()` → SwiftUI Drag → Drop auf MacTimelineView → `onMoveFocusBlock` → `eventKitRepo.updateFocusBlockTime()`

## Blast Radius
- **Bestehender MacTaskTransfer-Drop:** Nicht betroffen (separater .dropDestination)
- **EventKit Writes:** Nutzt bestehende `updateFocusBlockTime()` Methode
- **Gestures:** .draggable() + .onTapGesture bewiesen auf iOS EventBlock (Zeile 52-57)
- **Nebenfix macOS updateBlockTime():** Korrigiert bestehenden Bug, verbessert Zustand

## Offene Entscheidungen fuer Henning
1. **Sollen aktive/vergangene Blocks verschiebbar sein?** Empfehlung: Nur future Blocks
2. **iOS Drop-Praezision:** Stunden-Level (einfach) oder Viertelstunden-Level (besser, +20 LoC)?
3. **macOS Nebenfix:** `updateBlockTime()` (EditSheet) auch zu EventKit persistieren? Empfehlung: JA
