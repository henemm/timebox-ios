# Context: Live Activity (Sprint 4)

## Request Summary
Fokus-Block Timer auf dem Lockscreen und in der Dynamic Island anzeigen, sodass der User den Countdown sehen kann ohne die App zu oeffnen.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/FocusBlock.swift` | Core Model - enthaelt alle Timer-Daten (startDate, endDate, taskIDs) |
| `Sources/Views/FocusLiveView.swift` | Aktuelle Timer-UI - 1-Sekunden Updates, Progress-Berechnung |
| `Sources/Models/AppSettings.swift` | User Preferences via AppStorage |
| `Sources/Services/EventKitRepository.swift` | FocusBlock Laden/Speichern in Kalender |
| `Sources/Services/SoundService.swift` | Audio Feedback (Warnung, End-Gong) |
| `FocusBloxApp.swift` | App Entry + Dependency Injection |
| `FocusBloxWidgets/` | Bestehendes Widget Target (Control Center) |
| `Resources/FocusBlox.entitlements` | Entitlements - MUSS erweitert werden |

## Existing Patterns

### Timer-Update Pattern (FocusLiveView)
```swift
Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    .sink { currentTime = $0 }
```

### FocusBlock Timing-Daten
```swift
struct FocusBlock {
    let startDate: Date
    let endDate: Date
    var durationMinutes: Int
    var isActive: Bool  // startDate <= now < endDate
}
```

### Service Pattern
- `SoundService` - Enum-basiert fuer Audio/Haptic
- `EventKitRepository` - Protocol-basiert mit DI

### Repository Pattern
```swift
@Environment(\.eventKitRepository) var eventKitRepository
```

## Dependencies

### Upstream (was wir nutzen)
- `FocusBlock` Model - Timer-Daten
- `EventKitRepository` - Block-Status abrufen
- `AppSettings` - User-Einstellungen

### Downstream (was uns nutzt)
- Keine - Live Activity ist neues Feature

## Frameworks benoetigt

| Framework | Zweck |
|-----------|-------|
| `ActivityKit` | Live Activity API (iOS 16.1+) |
| `WidgetKit` | Lock Screen Widget UI |

**Keine externen Packages noetig** - alles Apple Frameworks.

## Existing Specs
- Keine direkten Specs fuer Live Activity vorhanden
- `docs/specs/foundation/step2-backlogview.md` - Zeigt Spec-Format

## Architektur-Entscheidungen

### App Groups ERFORDERLICH
- **Problem:** Widget Extension laeuft in separatem Prozess
- **Loesung:** App Group fuer shared UserDefaults/Container
- **Aenderung:** Entitlements + Provisioning Profile anpassen

### ActivityAttributes Design
```swift
struct FocusBlockActivityAttributes: ActivityAttributes {
    let blockTitle: String
    let totalDurationMinutes: Int

    struct ContentState: Codable, Hashable {
        let endDate: Date           // Fuer Timer
        let currentTaskTitle: String?
        let completedCount: Int
        let totalCount: Int
    }
}
```

### Update-Strategie
- **Option A:** Push Updates (Server-basiert) - NICHT moeglich ohne Backend
- **Option B:** Timer-basiert lokal - WidgetKit `.date` relativ automatisch
- **Empfehlung:** Option B mit `Text(timerInterval:)` fuer Countdown

## Risks & Considerations

### 1. Background Limitations
- **Risk:** App kann im Background nicht beliebig updaten
- **Mitigation:** WidgetKit `Text(timerInterval:)` zaehlt automatisch

### 2. App Groups Setup
- **Risk:** Erfordert Aenderung an Provisioning/Entitlements
- **Mitigation:** Nur fuer echtes Device relevant, Simulator funktioniert

### 3. Activity Lifetime
- **Risk:** Live Activity kann max 8h laufen (iOS Limit)
- **Mitigation:** Focus Blocks sind typisch 25-90min - kein Problem

### 4. Testing
- **Risk:** Live Activity schwer in UI Tests zu testen
- **Mitigation:** Unit Tests fuer Manager, manuelle Verifikation fuer UI

## Implementation Scope

### Neue Dateien (geschaetzt)
| Datei | Zweck |
|-------|-------|
| `Sources/Services/LiveActivityManager.swift` | Start/Update/End Activity |
| `Sources/Models/FocusBlockActivityAttributes.swift` | Activity Data Model |
| `FocusBloxWidgets/FocusBlockLiveActivity.swift` | Lock Screen + Dynamic Island UI |

### Zu aendernde Dateien
| Datei | Aenderung |
|-------|-----------|
| `FocusBloxApp.swift` | LiveActivityManager initialisieren |
| `FocusLiveView.swift` | Activity starten bei Block-Start |
| `Resources/FocusBlox.entitlements` | App Group hinzufuegen |
| `FocusBloxWidgets/Info.plist` | Live Activity Support aktivieren |
| `FocusBloxWidgetsBundle.swift` | Live Activity registrieren |

### Geschaetzte LoC
- Neue Dateien: ~150-200 LoC
- Aenderungen: ~50 LoC
- **Total:** ~200-250 LoC (innerhalb Scope Limit)

## iOS 26 Considerations

- iOS 26 nutzt "Liquid Glass" Design
- Dynamic Island und Lock Screen sollten minimalistisch sein
- Systemfonts und SF Symbols bevorzugen

---

## Analysis (Phase 2)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/FocusBlockActivityAttributes.swift` | CREATE | ActivityAttributes fuer Live Activity |
| `Sources/Services/LiveActivityManager.swift` | CREATE | Start/Update/End Activity Lifecycle |
| `FocusBloxWidgets/FocusBlockLiveActivity.swift` | CREATE | Lock Screen + Dynamic Island UI |
| `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` | MODIFY | Live Activity registrieren |
| `FocusBloxWidgets/Info.plist` | MODIFY | `NSSupportsLiveActivities = YES` |
| `Sources/Views/FocusLiveView.swift` | MODIFY | LiveActivityManager aufrufen bei Block-Start/End |
| `Resources/FocusBlox.entitlements` | MODIFY | App Group hinzufuegen (optional, erstmal ohne) |

### Scope Assessment

- **Files:** 3 neue + 4 geaenderte = 7 total
- **Estimated LoC:** +180 / -5
- **Risk Level:** MEDIUM (neues Framework, aber klare API)

### Technical Approach

#### 1. ActivityAttributes definieren
```swift
struct FocusBlockActivityAttributes: ActivityAttributes {
    let blockTitle: String
    let startDate: Date
    let endDate: Date

    struct ContentState: Codable, Hashable {
        let currentTaskTitle: String?
        let completedCount: Int
        let totalCount: Int
    }
}
```

#### 2. LiveActivityManager Service
```swift
@Observable
class LiveActivityManager {
    private var currentActivity: Activity<FocusBlockActivityAttributes>?

    func startActivity(for block: FocusBlock, currentTask: PlanItem?) async
    func updateActivity(currentTask: PlanItem?, completedCount: Int, totalCount: Int) async
    func endActivity() async
}
```

#### 3. Lock Screen / Dynamic Island UI
- **Minimal View:** Block-Titel + Countdown Timer
- **Expanded View:** Aktueller Task + Progress
- **Compact View (Dynamic Island):** Timer only
- Timer via `Text(timerInterval:)` - zaehlt automatisch ohne Updates

#### 4. Integration in FocusLiveView
- `onAppear` wenn Block aktiv: `startActivity()`
- Bei Task-Wechsel: `updateActivity()`
- Bei Block-Ende: `endActivity()`

### Key Insight: Kein App Group noetig (vorerst)

Live Activity braucht **KEIN** App Group fuer den Basis-Use-Case:
- App startet Activity mit Daten
- Widget zeigt nur statische Daten + Timer
- Timer laeuft via `Text(timerInterval:)` automatisch
- Updates kommen von der App (nicht vom Widget)

App Group waere nur noetig wenn:
- Widget selbst Daten lesen muesste (z.B. aus UserDefaults)
- Wir Push-basierte Updates ohne App-Foreground wollen

**Empfehlung:** Ohne App Group starten, spaeter bei Bedarf hinzufuegen.

### Open Questions

- [x] App Group noetig? → NEIN, nicht fuer MVP
- [x] Wie Timer anzeigen? → `Text(timerInterval:)` automatisch
- [ ] Quick Actions auf Lock Screen? → Phase 2 (spaeter)

### Definition of Done (fuer dieses Feature)

1. Live Activity erscheint wenn FocusBlock aktiv
2. Countdown Timer laeuft auf Lock Screen
3. Aktueller Task-Titel wird angezeigt
4. Activity verschwindet wenn Block endet
5. UI Tests vorhanden und GRUEN
