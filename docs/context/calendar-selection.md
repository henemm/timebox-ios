# Context: Calendar Selection

## Request Summary
User möchte in den Settings auswählen können, welcher Kalender für Focus Blocks verwendet wird. Aktuell wird immer der System-Default-Kalender verwendet.

## Related Files
| File | Relevance |
|------|-----------|
| `TimeBox/Sources/Services/EventKitRepository.swift` | Verwendet `defaultCalendarForNewEvents` an 2 Stellen (Zeile 118, 194) |
| `TimeBox/Sources/Views/MainTabView.swift` | Braucht Settings-Zugang (Button/Tab) |
| `TimeBox/Resources/Info.plist` | Bereits Calendar-Permission vorhanden |

## Existing Patterns

### Kalender-Nutzung (aktuell)
```swift
// EventKitRepository.swift:118
event.calendar = eventStore.defaultCalendarForNewEvents

// EventKitRepository.swift:194 (createFocusBlock)
event.calendar = eventStore.defaultCalendarForNewEvents
```

### Verfügbare EventKit APIs
```swift
// Alle Kalender abrufen
eventStore.calendars(for: .event) -> [EKCalendar]

// Kalender nach ID finden
eventStore.calendar(withIdentifier: String) -> EKCalendar?

// Kalender-Eigenschaften
calendar.title: String
calendar.calendarIdentifier: String
calendar.cgColor: CGColor?
calendar.allowsContentModifications: Bool
```

### Settings-Pattern (nicht vorhanden)
- Keine SettingsView existiert
- Kein AppStorage/UserDefaults in Nutzung
- Kein Settings-Button in MainTabView

## Dependencies

### Upstream (was wir nutzen)
- `EventKit` Framework (EKEventStore, EKCalendar)
- SwiftUI AppStorage für Persistenz

### Downstream (was uns nutzt)
- `createCalendarEvent()` - genutzt von PlanningView
- `createFocusBlock()` - genutzt von BlockPlanningView
- Beide müssen den ausgewählten Kalender verwenden

## Existing Specs
- `docs/specs/foundation/step1-foundation.md` - EventKitRepository Basis
- Keine Settings-Spec vorhanden

## Risks & Considerations

### 1. Kalender-Validierung
- Ausgewählter Kalender könnte gelöscht werden
- Fallback auf Default nötig wenn Kalender nicht mehr existiert

### 2. Read-Only Kalender
- Manche Kalender (z.B. Geburtstage, Feiertage) sind read-only
- `calendar.allowsContentModifications` prüfen
- Nur beschreibbare Kalender in Auswahl anzeigen

### 3. Kalender-Sync
- iCloud-Kalender könnten offline nicht verfügbar sein
- Lokale Kalender bevorzugen oder Hinweis zeigen

### 4. Migration
- Bestehende Focus Blocks bleiben im alten Kalender
- Keine Migration nötig (Events bleiben wo sie sind)

## Implementation Scope

### Neue Dateien
| Datei | Zweck |
|-------|-------|
| `Sources/Views/SettingsView.swift` | Settings UI mit Kalender-Picker |

### Zu ändern
| Datei | Änderung |
|-------|----------|
| `EventKitRepository.swift` | `selectedCalendar` Property, Methode zum Kalender-Abruf |
| `MainTabView.swift` | Settings-Button in Toolbar |

### Geschätzte Größe
- ~150-200 LoC
- 2-3 Dateien

---

## Analysis

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/SettingsView.swift` | CREATE | Neue Settings UI mit Kalender-Picker |
| `Sources/Services/EventKitRepository.swift` | MODIFY | `getWritableCalendars()`, `selectedCalendarID` nutzen |
| `Sources/Views/BacklogView.swift` | MODIFY | Settings-Button in Toolbar |

### Scope Assessment
- Files: 3
- Estimated LoC: +120/-5
- Risk Level: LOW

### Technical Approach

#### 1. Kalender-ID Speicherung
```swift
@AppStorage("selectedCalendarID") var selectedCalendarID: String = ""
```

#### 2. EventKitRepository Erweiterungen
```swift
// Alle beschreibbaren Kalender abrufen
func getWritableCalendars() -> [EKCalendar] {
    eventStore.calendars(for: .event)
        .filter { $0.allowsContentModifications }
}

// Kalender für Events (mit Fallback)
func calendarForEvents() -> EKCalendar? {
    if let id = UserDefaults.standard.string(forKey: "selectedCalendarID"),
       let calendar = eventStore.calendar(withIdentifier: id),
       calendar.allowsContentModifications {
        return calendar
    }
    return eventStore.defaultCalendarForNewEvents
}
```

#### 3. Settings UI
- Sheet/NavigationDestination von BacklogView
- Picker mit allen beschreibbaren Kalendern
- Kalender-Farbe als visueller Indikator

#### 4. Integration in Views
- Gear-Button in BacklogView Toolbar
- Sheet präsentiert SettingsView

### Open Questions

**Geklärt durch Empfehlung:**
- UI-Platzierung: **Gear-Button in Backlog-Toolbar** (iOS Standard-Pattern)
- Scope: **Nur Kalender-Setting** (weitere Settings später erweiterbar)

**Keine offenen Fragen für User.**
