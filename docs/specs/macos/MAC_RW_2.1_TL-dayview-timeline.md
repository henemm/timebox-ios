---
entity_id: MAC_RW_2.1_TL
type: feature
created: 2026-03-29
updated: 2026-03-29
status: draft
version: "1.0"
tags: [macos, dayview, timeline, parity]
---

# MAC_RW_2.1_TL — DayView Daytime Timeline auf macOS

## Approval

- [ ] Approved

## Purpose

Den Platzhalter "Timeline kommt bald" im macOS-DayView Daytime-Modus durch die bereits existierende `MacTimelineView` ersetzen. Damit zeigt der Tag-Tab auf macOS im Tages-Modus dieselbe Timeline-Ansicht wie der Blox-Tab, allerdings im Read-only-Modus (keine Drag & Drop Interaktion).

## Source

- **File:** `Sources/Views/DayView.swift`
- **Identifier:** `DayView.daytimeContent` (Zeile 141-169)
- **Betroffener Branch:** `#else` (macOS) in Zeile 162-166

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `MacTimelineView` | View (FocusBloxMac) | Bestehende macOS-Timeline mit Collision Detection, TimelineLayout |
| `TimelineItem` | Model (Sources) | Shared Model fuer Scheduled Tasks in der Timeline |
| `TimelineLayout` | Layout (Sources) | Custom Layout mit `.place()` fuer korrektes Positioning |
| `CalendarEvent` | Model (Sources) | Kalender-Events aus EventKit |
| `FocusBlock` | Model (Sources) | Focus Blocks aus EventKit |
| `EventKitRepository` | Service (Sources) | Daten-Provider (bereits in DayView injected) |

## Implementation Details

### Aenderung 1: Platzhalter ersetzen (DayView.swift)

Ersetze den `#else`-Branch in `daytimeContent`:

```swift
// VORHER (Zeile 162-166):
#else
ContentUnavailableView(
    "Dein Tag",
    systemImage: "sun.max",
    description: Text("Timeline kommt bald")
)
#endif

// NACHHER:
#else
MacTimelineView(
    date: Date(),
    events: calendarEvents,
    focusBlocks: focusBlocks,
    scheduledTasks: scheduledTasks
    // Keine Callbacks = read-only Ansicht
)
#endif
```

### Warum Read-only

- DayView = Tagesuebersicht ("Was steht heute an?")
- MacPlanningView (Blox-Tab) = Planungsansicht mit voller Interaktion
- Konsistent mit iOS, wo TimelineView im DayView ebenfalls read-only ist (nur `onRefresh`)
- MacTimelineView akzeptiert alle Callbacks als Optional — nil = keine Interaktion

### Daten-Verfuegbarkeit

Alle benoetigten State-Variablen existieren bereits in DayView:
- `@State calendarEvents: [CalendarEvent]` — geladen in `loadDaytimeData()`
- `@State focusBlocks: [FocusBlock]` — geladen in `loadDaytimeData()`
- `@State scheduledTasks: [TimelineItem]` — geladen in `loadDaytimeData()`

Kein zusaetzliches Data-Loading noetig.

## Expected Behavior

- **Input:** User navigiert zum Tag-Tab waehrend der Tagesphase (morningEndHour bis eveningStartHour)
- **Output:** Vollstaendige Timeline-Ansicht (6:00-22:00) mit:
  - Kalender-Events (farbcodiert, mit Titel und Zeitraum)
  - Focus Blocks (blau/gruen/grau je nach Status)
  - Scheduled Tasks (orange Bloecke)
  - Aktueller Zeitindikator (roter Punkt + Linie, nur heute)
  - Collision Detection (ueberlappende Events nebeneinander)
- **Keine Interaktion:** Kein Drag & Drop, kein Resize, kein Tap-Feedback
- **Side effects:** Keine — reine Anzeige

## Scope

| Metrik | Wert |
|--------|------|
| Geaenderte Dateien | 1 |
| Test-Dateien | 1 |
| Geschaetzte LoC (Aenderung) | ~8 |
| Geschaetzte LoC (Tests) | ~60 |
| Risiko | LOW |

## Test Plan

### Unit Tests (FocusBloxMacTests/DayViewTimelineTests.swift)

1. **test_daytimeContent_showsMacTimelineView_onMacOS**
   - DayView im Daytime-Modus instanziieren
   - Verifizieren dass MacTimelineView gerendert wird (nicht der Platzhalter)

2. **test_scheduledTimelineItems_mapsCorrectly**
   - Bereits existierender Test — verifiziert Daten-Mapping
   - Sicherstellen dass es keine Regression gibt

3. **test_macBuild_succeeds**
   - `./scripts/sim.sh mac-build` muss erfolgreich sein

## Known Limitations

- Keine Free Slots in der DayView-Timeline (bewusst ausgescoped — DayView = Uebersicht, nicht Planung)
- Drop-Targets von MacTimelineView sind technisch aktiv, aber ohne Callbacks passiert nichts
- Evening-Modus auf macOS fehlt weiterhin SuccessStoryView und FailureQuickSelect (separates Ticket)

## Changelog

- 2026-03-29: Initial spec created
