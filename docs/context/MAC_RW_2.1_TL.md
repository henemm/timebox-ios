# Context: MAC_RW_2.1_TL — DayView Daytime Timeline auf macOS

## Request Summary
Den Platzhalter "Timeline kommt bald" im macOS-DayView Daytime-Modus durch die bereits existierende `MacTimelineView` ersetzen. Alle Daten werden bereits geladen — es fehlt nur die UI-Integration.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | **Hauptdatei** — Zeile 154-167: `#if os(iOS)` Branch mit Platzhalter im `#else`. Daten-Loading (`loadDaytimeData()`) bereits vorhanden. |
| `FocusBloxMac/MacTimelineView.swift` | **Bestehende Timeline-View** (750 LoC) — Zeigt Events, FocusBlocks, Scheduled Tasks, Free Slots mit Collision Detection + TimelineLayout. Wird bereits in MacPlanningView genutzt. |
| `Sources/Views/TimelineView.swift` | iOS-Timeline (nur read-only in DayView). Zeigt Pattern: alle Callbacks optional, nil = read-only. |
| `FocusBloxMac/MacPlanningView.swift` | Referenz-Integration: Zeigt wie MacTimelineView verdrahtet wird (Zeile 168-207). Alle Callbacks implementiert. |
| `Sources/Models/TimelineItem.swift` | Shared Model fuer Collision Detection. `TimelineItem`, `PositionedItem`, `PositionedEvent`, `PositionedFocusBlock`, `PositionedScheduledTask`. |
| `Sources/Layouts/TimelineLayout.swift` | Shared custom Layout mit `.place()` fuer korrektes Hit-Testing. |
| `FocusBloxMac/ContentView.swift` | Zeile 268: `DayView()` wird direkt eingebunden (keine Parameter). |

## Existing Patterns

### iOS DayView Daytime-Integration (read-only)
```swift
TimelineView(
    date: Date(),
    events: calendarEvents,
    scheduledTasks: scheduledTasks,
    onRefresh: { await loadDaytimeData() }
    // Alle anderen Callbacks nil → read-only
)
```

### macOS MacPlanningView-Integration (vollinteraktiv)
```swift
MacTimelineView(
    date: selectedDate,
    events: calendarEvents,
    focusBlocks: focusBlocks,
    scheduledTasks: scheduledTasks,
    freeSlots: computedFreeSlots,
    onScheduleTask: { ... },
    onCreateFocusBlock: { ... },
    // ... 10+ weitere Callbacks
)
```

### Entscheidung: Read-only vs. Interaktiv
- iOS DayView: **Read-only** (nur Events + Scheduled Tasks anzeigen)
- macOS PlanningView: **Vollinteraktiv** (Drag & Drop, Resize, Schedule)
- macOS DayView: **Read-only sinnvoll** — DayView ist Tagesübersicht, nicht Planungsansicht. Interaktion passiert in Blox/PlanningView.

## Dependencies
- **Upstream:** `EventKitRepository` (Kalender-Events), `SyncEngine` (Tasks), `GapFinder` (freie Slots)
- **Downstream:** Keine — DayView ist Endpunkt (Leaf View)

## Daten-Status in DayView
Bereits vorhanden und geladen in `loadDaytimeData()`:
- `@State calendarEvents: [CalendarEvent]` ✅
- `@State focusBlocks: [FocusBlock]` ✅
- `@State scheduledTasks: [TimelineItem]` ✅
- `@State freeSlots: [TimeSlot]` ❌ — wird nur in Morning geladen, nicht in Daytime

## Key Difference: iOS TimelineView vs. MacTimelineView
| Aspekt | iOS TimelineView | macOS MacTimelineView |
|--------|------------------|----------------------|
| Positionierung | `.offset(y:)` | `TimelineLayout` + `.place()` |
| Collision Detection | Keine | Unified via `TimelineItem.groupOverlapping()` |
| Drag & Drop | Drop Zones pro Stunde | Flexible Drop-to-Block/Schedule |
| FocusBlock Support | Kein direktes Rendering | Voll (Drag, Resize, Edit) |
| Free Slots | Nicht angezeigt | Dashed Green Boxes |
| Zeitindikator | Nicht angezeigt | Roter Punkt + Linie |

## Existing Specs
- `docs/specs/rework/2.1c-day-view-daytime-timeline.md` — Original-Spec fuer iOS Timeline-Integration
- `docs/specs/rework/2.1-day-view.md` — Gesamt-DayView-Spec (alle 3 Modi)
- `docs/specs/rework/2.1b-day-view-morning-mode.md` — Morning Mode Referenz

## Scope-Schaetzung
**Minimal-Ansatz (read-only):** ~10-15 LoC in DayView.swift — Platzhalter durch `MacTimelineView(date:events:focusBlocks:scheduledTasks:)` ersetzen. Keine Callbacks = read-only.

**Erweiterter Ansatz (mit Free Slots):** +10 LoC — `freeSlots` in `loadDaytimeData()` berechnen (wie in Morning Mode). Dann auch Free Slots in der Timeline anzeigen.

## Risks & Considerations
1. ~~**MacTimelineView erwartet `focusBlocks: [FocusBlock]`**~~ KORREKTUR: `loadDaytimeData()` laedt bereits `focusBlocks` (Zeile 437). Kein Risiko.
2. **Drop-Destination fuer `MacTaskTransfer`** — MacTimelineView hat immer Drop-Targets aktiv. In read-only Modus: Callback nil → Drop wird ignoriert, aber visuelle Artefakte moeglich.
3. **Free Slots Berechnung** — Braucht `GapFinder`, der Events + FocusBlocks + Scheduled Tasks benoetigt. Alles vorhanden, muss nur verdrahtet werden.
4. **Evening-Mode auf macOS** — `SuccessStoryView` und `failureQuickSelectSection` sind `#if os(iOS)`. Separates Ticket, nicht in Scope.

---

## Analysis

### Type
Feature — Platzhalter ersetzen durch bestehende Komponente

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/DayView.swift` | MODIFY | `#else` Branch (Zeile 162-166): Platzhalter → `MacTimelineView` read-only |
| `FocusBloxMacTests/DayViewTimelineTests.swift` | CREATE | Unit Tests: MacTimelineView wird im Daytime-Modus angezeigt |

### Scope Assessment
- Files: 1 Aenderung + 1 Test-Datei
- Estimated LoC: +15 (DayView) / +60 (Tests)
- Risk Level: **LOW** — Alle Komponenten existieren, nur Verdrahtung noetig

### Technical Approach
**Read-only MacTimelineView im DayView Daytime-Modus:**

Platzhalter (Zeile 162-166) ersetzen durch:
```swift
MacTimelineView(
    date: Date(),
    events: calendarEvents,
    focusBlocks: focusBlocks,
    scheduledTasks: scheduledTasks
    // Keine Callbacks → read-only Ansicht
)
```

**Begründung read-only:**
- DayView = Tagesübersicht ("Was steht heute an?")
- MacPlanningView = Planungsansicht ("Plane deinen Tag") → dort sind alle Interaktionen
- Konsistent mit iOS, wo TimelineView im DayView auch read-only ist

**Optional (Scope-Erweiterung):** Free Slots berechnen und anzeigen. Braucht `GapFinder`-Aufruf in `loadDaytimeData()`. Empfehlung: NICHT in V1, da DayView = Übersicht, nicht Planung.

### Dependencies
- **Upstream:** `MacTimelineView` (FocusBloxMac, existiert), `TimelineLayout` (Sources, existiert), `TimelineItem` (Sources, existiert)
- **Downstream:** Keine

### Open Questions
- Keine — Ansatz ist klar und risikoarm
