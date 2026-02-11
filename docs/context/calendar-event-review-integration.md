# Context: Calendar Event Review Integration

## Request Summary
Kalender-Eintraege sollen den bestehenden 5 Kategorien zugeordnet werden koennen (auf macOS - iOS hat das Feature bereits) und kategorisierte Events sollen automatisch im Tages- und Wochen-Review beruecksichtigt werden.

## Related Files

### Models
| File | Relevance |
|------|-----------|
| `Sources/Models/CalendarEvent.swift` | Hat bereits `category: String?` Property (Zeile 47-50), parsed aus Notes |
| `Sources/Models/TaskCategory.swift` | Zentrale 5 Kategorien: income, maintenance, recharge, learning, giving_back |
| `Sources/Models/FocusBlock.swift` | FocusBlock ist ein CalendarEvent mit `isFocusBlock == true` |

### Views - iOS
| File | Relevance |
|------|-----------|
| `Sources/Views/DailyReviewView.swift` | iOS Review - `categoryStats` beruecksichtigt NUR Tasks aus FocusBlocks (Zeile 50-67) |
| `Sources/Views/BlockPlanningView.swift` | iOS hat bereits `EventCategorySheet` (Zeile 918+) und Tap-Handler |

### Views - macOS
| File | Relevance |
|------|-----------|
| `FocusBloxMac/MacReviewView.swift` | macOS Review - nutzt NUR `@Query` auf `LocalTask` (Zeile 14), KEINE CalendarEvents |
| `FocusBloxMac/MacTimelineView.swift` | `EventBlockView` (Zeile 371+) ist nicht interaktiv - kein onTapGesture |

### Services
| File | Relevance |
|------|-----------|
| `Sources/Services/EventKitRepository.swift` | `fetchCalendarEvents(for:)` (Zeile 88) + `updateEventCategory(eventID:category:)` (Zeile 240) existieren |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Beide Methoden im Protocol definiert |
| `Sources/Testing/MockEventKitRepository.swift` | Mock fuer beide Methoden vorhanden, inkl. `updateEventCategoryCalled` tracking |

## Existing Patterns

### iOS Category-Sheet Pattern (BlockPlanningView)
1. `@State private var eventToCategories: CalendarEvent?`
2. `.sheet(item: $eventToCategories)` oeffnet `EventCategorySheet`
3. `EventCategorySheet` zeigt alle `CategoryConfig.allCases` als Buttons
4. `onSelect` ruft `eventKitRepo.updateEventCategory()` auf
5. Events werden neu geladen via `loadCalendarEvents()`

### iOS Review Pattern (DailyReviewView)
- `loadData()` laedt `FocusBlock`s via `fetchFocusBlocks(for:)` (Zeile 446)
- `categoryStats` aggregiert Tasks aus FocusBlocks (completed IDs) nach `taskType`
- Zeigt `CategoryBar` mit Minuten pro Kategorie

### macOS Review Pattern (MacReviewView)
- Nutzt `@Query` auf `LocalTask` mit `isCompleted` Filter
- `WeekReviewContent.categoryStats` gruppiert nach `taskType`
- Zeigt Chart + CategoryStatCards
- Hat eigene `CategoryStat` struct (mit `count` statt `minutes`)

## Dependencies

### Upstream (was wir nutzen)
- `EventKitRepository.fetchCalendarEvents(for:)` - Events laden
- `EventKitRepository.updateEventCategory(eventID:category:)` - Kategorie speichern
- `CalendarEvent.category` - Kategorie lesen
- `CalendarEvent.isFocusBlock` - FocusBlocks filtern
- `TaskCategory` enum - Alle Kategorien

### Downstream (was uns nutzt)
- Keine - Review Views sind End-Views ohne Abhaengige

## Existing Specs
- `docs/specs/features/calendar-event-categories.md` - Phase 1 (Model + iOS UI) bereits implementiert, Phase 2 (Review Integration) noch offen

## 2 Aenderungsbereiche

### Teil 1: macOS Category-UI (EventBlockView interaktiv machen)
- `MacTimelineView.swift` - EventBlockView braucht onTapGesture + CategorySheet
- Pattern: 1:1 wie iOS BlockPlanningView
- Neuer Callback: `onTapEvent: ((CalendarEvent) -> Void)?` an MacTimelineView

### Teil 2: Review Integration (beide Plattformen)
- `DailyReviewView.swift` - CalendarEvents mit Kategorie zusaetzlich laden und in `categoryStats` einrechnen
- `MacReviewView.swift` - EventKitRepository einbinden, categorisierte Events in Stats einrechnen

## Design-Entscheidungen
- **Nur kategorisierte Events** zaehlen im Review (User-Entscheidung)
- **Keine "Unbekannt" Kategorie** noetig
- **Kein Bestaetigung-Schritt** - einmal kategorisiert, fliesst automatisch ein

## Analysis

### Affected Files (with changes)

| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `FocusBloxMac/MacTimelineView.swift` | MODIFY | `onTapEvent` Callback + `.onTapGesture` auf EventBlockView + Kategorie-Farbstreifen | ~15 |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY | State + Sheet + Handler fuer Event-Kategorisierung + macOS EventCategorySheet | ~40 |
| `Sources/Views/DailyReviewView.swift` | MODIFY | CalendarEvents laden + in `categoryStats` einrechnen | ~15 |
| `FocusBloxMac/MacReviewView.swift` | MODIFY | EventKitRepository + Events laden + in categoryStats/totalFocusMinutes einrechnen | ~30 |

### Scope Assessment
- **Files:** 4
- **Estimated LoC:** ~100 (alles Additions/Modifications)
- **Risk Level:** LOW
- Alle Backend-Methoden existieren bereits
- iOS Pattern dient als bewiesene Vorlage

### Technical Approach

**Teil 1: macOS Category-UI**
1. `MacTimelineView`: Neuer `onTapEvent: ((CalendarEvent) -> Void)?` Callback (wie `onTapBlock`)
2. `EventBlockView`: `.contentShape(Rectangle()).onTapGesture` + Kategorie-Farbstreifen links (4px)
3. `MacPlanningView`: `@State eventToCategories: CalendarEvent?` + `.sheet()` mit macOS-spezifischer `MacEventCategorySheet`
4. `MacEventCategorySheet`: Analog zu iOS `EventCategorySheet`, aber ohne `NavigationStack`/`.presentationDetents` (nutzt einfaches macOS Sheet)

**Teil 2: Review Integration**
5. `DailyReviewView.loadData()`: Zusaetzlich `fetchCalendarEvents` fuer jeden Wochentag, filtern nach `!isFocusBlock && category != nil`
6. `DailyReviewView.categoryStats`: Event-Minuten zu `stats[category]` addieren
7. `MacReviewView`: EventKitRepository einbinden, Events in `.task` laden
8. `WeekReviewContent`: Events in `categoryStats` count + `totalFocusMinutes` einrechnen
9. `DayReviewContent`: Events in `totalFocusMinutes` einrechnen

### Wichtig: EventCategorySheet ist iOS-only
`EventCategorySheet` liegt in `BlockPlanningView.swift` im iOS Target. Fuer macOS wird eine eigene `MacEventCategorySheet` in `MacPlanningView.swift` erstellt (gleiche Logik, macOS-angepasstes UI).

### Open Questions
- Keine - alles geklaert durch User-Input

## Risiken
- **CategoryStat Name-Conflict:** iOS (`config: CategoryConfig, minutes: Int`) vs macOS (`category: String, count: Int`) - verschiedene Targets, kein Compile-Conflict
- **macOS Review nutzt nur @Query:** Muss um EventKitRepository erweitert werden (braucht Calendar-Permission, die in MacPlanningView bereits funktioniert)
- **Scope gut kontrollierbar:** 4 Dateien, ~100 LoC
