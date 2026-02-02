# Context: Calendar Event Categories

## Request Summary

Kalendereinträge (nicht nur Focus Blocks) sollen kategorisierbar werden, damit die Zeit-Auswertung im Tages- und Wochenrückblick vollständiger wird.

**PO-Vorgaben:**
1. Scope: Sowohl Daily Review ALS AUCH Weekly Review
2. Display: Nur als Teil der Kategorie-Balken (aggregiert, nicht einzeln aufgelistet)
3. Default: "unbekannt" als neue Kategorie für nicht kategorisierte Items

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/CalendarEvent.swift` | Model muss `category` Property bekommen |
| `Sources/Views/DailyReviewView.swift` | Zeigt Weekly Review mit categoryStats |
| `Sources/Views/BlockPlanningView.swift` | Zeigt ExistingEventBlock - braucht Tap-Gesture |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Braucht `updateEventCategory()` Methode |
| `Sources/Services/EventKitRepository.swift` | Implementation der neuen Methode |
| `Sources/Testing/MockEventKitRepository.swift` | Mock für Tests |

## Existing Patterns

### Notes-Based Metadata
CalendarEvent nutzt bereits notes-basierte Metadaten:
```swift
// Beispiel aus CalendarEvent.swift:
var isFocusBlock: Bool {
    guard let notes else { return false }
    return notes.contains("focusBlock:true")
}
```

Format: `key:value` in notes, getrennt durch Newlines.

**Für Categories:** `category:income` oder `category:unbekannt`

### Category System
5 existierende Kategorien in `CategoryConfig`:
| Enum Case | rawValue | Display |
|-----------|----------|---------|
| income | "income" | "Geld verdienen" |
| maintenance | "maintenance" | "Schneeschaufeln" |
| recharge | "recharge" | "Energie aufladen" |
| learning | "learning" | "Lernen" |
| givingBack | "giving_back" | "Weitergeben" |

**NEU:** `unknown` / "unbekannt" als 6. Kategorie

## Dependencies

### Upstream (was unser Code nutzt)
- `EKEvent` (EventKit) - notes Property zum Lesen/Schreiben
- `EKEventStore` - zum Speichern von Event-Änderungen

### Downstream (was unseren Code nutzt)
- `DailyReviewView` - liest CalendarEvent.category für Stats
- `BlockPlanningView` - zeigt ExistingEventBlock mit Tap-Handler

## Existing Specs

- `docs/project/stories/timebox-core.md` - Beschreibt Kategorien-System
- `docs/context/reminders-sync.md` - Ähnliches notes-basiertes Pattern

## Risks & Considerations

1. **EventKit Permissions** - Schreibzugriff auf Kalender erforderlich (bereits vorhanden)
2. **Notes-Überschreibung** - Bestehende Notes müssen erhalten bleiben (wie bei Focus Block notes)
3. **Performance** - Event-Updates lösen Kalender-Refresh aus
4. **Default-Kategorie** - "unbekannt" muss bei allen Views konsistent behandelt werden

## Analysis

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/CalendarEvent.swift` | MODIFY | +category computed property |
| `Sources/Views/DailyReviewView.swift` | MODIFY | +CategoryConfig.unknown, +event duration in stats |
| `Sources/Views/BlockPlanningView.swift` | MODIFY | +Tap gesture, +CategorySheet |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | MODIFY | +updateEventCategory() |
| `Sources/Services/EventKitRepository.swift` | MODIFY | +updateEventCategory() impl |
| `Sources/Testing/MockEventKitRepository.swift` | MODIFY | +mock support |
| `FocusBloxUITests/CalendarCategoryUITests.swift` | CREATE | UI Tests |
| `FocusBloxTests/CalendarEventCategoryTests.swift` | CREATE | Unit Tests |

### Scope Assessment
- Files: 8
- Estimated LoC: +150/-20
- Risk Level: LOW (nutzt existierende Patterns)

### Technical Approach

**Phase 1: Kategorisierbare Events**
1. `CalendarEvent.category` computed property (parsed from notes)
2. `updateEventCategory(eventID:, category:)` in Repository
3. Tap auf ExistingEventBlock → CategorySheet
4. UI Tests + Unit Tests

**Phase 2: Review Integration + "unbekannt"**
1. `CategoryConfig.unknown` hinzufügen
2. `DailyReviewView.categoryStats` erweitern um Event-Dauer
3. Uncategorized Tasks/Events → "unbekannt"
4. UI Tests + Unit Tests
