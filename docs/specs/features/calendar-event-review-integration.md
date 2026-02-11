---
entity_id: calendar-event-review-integration
type: feature
created: 2026-02-10
status: draft
version: "1.0"
workflow: calendar-event-review-integration
tags: [calendar, review, categories, macOS]
---

# Calendar Event Review Integration

## Approval

- [ ] Approved for implementation

## Purpose

Kategorisierte Kalender-Eintraege sollen automatisch im Tages- und Wochen-Review beruecksichtigt werden. Auf macOS fehlt zusaetzlich die UI zur Kategorie-Zuweisung fuer Events (iOS hat das bereits).

## Scope

| File | Change | LoC |
|------|--------|-----|
| `FocusBloxMac/MacTimelineView.swift` | MODIFY - onTapEvent Callback + Kategorie-Farbstreifen | ~15 |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY - Sheet-State + MacEventCategorySheet + Handler | ~40 |
| `Sources/Views/DailyReviewView.swift` | MODIFY - Events laden + in categoryStats einrechnen | ~15 |
| `FocusBloxMac/MacReviewView.swift` | MODIFY - EventKitRepo + Events in Stats einrechnen | ~30 |
| **Total** | **4 Dateien** | **~100 LoC** |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CalendarEvent.category` | Model Property | Liest Kategorie aus Event-Notes |
| `EventKitRepository.fetchCalendarEvents(for:)` | Service Method | Laedt Events fuer einen Tag |
| `EventKitRepository.updateEventCategory(eventID:category:)` | Service Method | Speichert Kategorie in Event-Notes |
| `TaskCategory` | Enum | Zentrale 5 Kategorien |
| `EventCategorySheet` (iOS) | View | Vorlage fuer macOS-Version |

## Implementation Details

### Teil 1: macOS Category-UI

**MacTimelineView.swift:**
```swift
// 1. Neuer Callback-Parameter
var onTapEvent: ((CalendarEvent) -> Void)?

// 2. EventBlockView bekommt onTapGesture
EventBlockView(event: positioned.event)
    .onTapGesture { onTapEvent?(positioned.event) }

// 3. EventBlockView: Kategorie-Farbstreifen (4px links)
// Wenn event.category != nil: farbiger Streifen an linker Kante
```

**MacPlanningView.swift:**
```swift
// 4. State fuer Sheet
@State private var eventToCategories: CalendarEvent?

// 5. Callback an MacTimelineView
onTapEvent: { event in eventToCategories = event }

// 6. Sheet
.sheet(item: $eventToCategories) { event in
    MacEventCategorySheet(event: event) { category in
        updateEventCategory(event: event, category: category)
    }
}

// 7. Handler (wie iOS)
private func updateEventCategory(event: CalendarEvent, category: String?) {
    Task {
        try? eventKitRepo.updateEventCategory(eventID: event.id, category: category)
        await loadCalendarEvents()
    }
}
```

**MacEventCategorySheet** (neue View in MacPlanningView.swift):
- Analog zu iOS EventCategorySheet
- List mit CategoryConfig.allCases als Buttons
- Checkmark bei aktueller Kategorie
- "Kategorie entfernen" Option
- Kein NavigationStack/.presentationDetents (macOS Sheet)

### Teil 2: Review Integration

**DailyReviewView.swift (iOS):**
```swift
// 8. Neue State-Variable
@State private var categorizedEvents: [CalendarEvent] = []

// 9. In loadData(): Events fuer jeden Wochentag laden
let dayEvents = try eventKitRepo.fetchCalendarEvents(for: currentDate)
let regularCategorized = dayEvents.filter { !$0.isFocusBlock && $0.category != nil }
allCategorizedEvents.append(contentsOf: regularCategorized)

// 10. In categoryStats: Event-Minuten addieren
for event in categorizedEvents {
    if let cat = event.category {
        stats[cat, default: 0] += event.durationMinutes
    }
}
// (weekBlocks-basierte Task-Filter fuer Wochen-Events verwenden)
```

**MacReviewView.swift (macOS):**
```swift
// 11. EventKitRepository hinzufuegen
@State private var eventKitRepo = EventKitRepository()
@State private var categorizedEvents: [CalendarEvent] = []

// 12. Events laden in .task {}
// Fuer today: Events fuer heute
// Fuer week: Events fuer alle Wochentage

// 13. Events an Sub-Views weitergeben
DayReviewContent(completedTasks: todayTasks, categorizedEvents: todayEvents)
WeekReviewContent(completedTasks: weekTasks, categorizedEvents: weekEvents)

// 14. In categoryStats: Event-Count addieren
// In totalFocusMinutes: Event-Dauer addieren
```

## Expected Behavior

### macOS Category-UI
- **Input:** Tap auf Kalender-Event in macOS Timeline
- **Output:** Sheet mit 5 Kategorien + "Entfernen" Option
- **Side Effects:** Kategorie wird in EventKit-Notes gespeichert, Timeline reloaded

### Review Integration
- **Input:** Tages-/Wochen-Review laden
- **Output:** Kategorisierte Events fliessen in "Zeit pro Kategorie" Statistik ein
- **Regeln:**
  - Nur Events mit `category != nil` werden beruecksichtigt
  - FocusBlocks werden wie bisher ueber Tasks gezaehlt (kein Doppelzaehlen)
  - Event-Minuten = `durationMinutes` (Dauer des Kalender-Eintrags)

## Test Plan

### Automated Tests (TDD RED)

**Unit Tests (FocusBloxTests/):**
- [ ] `testCategoryStatsIncludesCalendarEvents`: GIVEN Events mit Kategorie, WHEN categoryStats berechnet, THEN Event-Minuten in Stats enthalten
- [ ] `testCategoryStatsExcludesUncategorizedEvents`: GIVEN Events ohne Kategorie, WHEN categoryStats berechnet, THEN Events nicht in Stats
- [ ] `testCategoryStatsExcludesFocusBlockEvents`: GIVEN FocusBlock-Events mit Kategorie, WHEN categoryStats berechnet, THEN nicht doppelt gezaehlt

**UI Tests (FocusBloxUITests/):**
- [ ] `testMacEventCategorySheetOpens`: GIVEN macOS Timeline mit Event, WHEN Tap auf Event, THEN Category-Sheet oeffnet sich
- [ ] `testMacEventCategoryAssignment`: GIVEN Category-Sheet offen, WHEN Kategorie waehlen, THEN Event zeigt Kategorie-Farbe

### Acceptance Criteria

- [ ] macOS: Tap auf Kalender-Event oeffnet Category-Sheet
- [ ] macOS: Kategorie-Auswahl speichert in EventKit und zeigt Farbstreifen
- [ ] iOS Review: Kategorisierte Events fliessen in Wochen-Statistik ein
- [ ] macOS Review: Kategorisierte Events fliessen in Tages- und Wochen-Statistik ein
- [ ] Events ohne Kategorie werden nicht beruecksichtigt
- [ ] FocusBlock-Events werden nicht doppelt gezaehlt

## Known Limitations

- Kategorie wird in EventKit-Notes gespeichert (Text-basiert, nicht strukturiert)
- Kalender-Events aus externen Quellen (Google, Exchange) koennen nur kategorisiert werden, wenn Notes-Feld beschreibbar ist
- All-Day Events werden nicht in der Timeline angezeigt und sind nicht kategorisierbar

## Changelog

- 2026-02-10: Initial spec created
