# Context: Monster Coach Phase 6c — MorningIntentionView in macOS

## Request Summary
Die shared MorningIntentionView (Morgen-Intention setzen) soll in der macOS-App nutzbar gemacht werden. Aktuell gibt es sie nur auf iOS (in CoachMeinTagView).

## Related Files

| File | Relevanz |
|------|----------|
| `Sources/Views/MorningIntentionView.swift` | Shared View — wird direkt eingebettet |
| `Sources/Models/DailyIntention.swift` | Model + IntentionOption Enum (shared) |
| `Sources/Models/Discipline.swift` | Monster-Discipline Mapping (shared) |
| `Sources/Views/CoachMeinTagView.swift` | iOS-Referenz: wie MorningIntentionView dort eingebettet ist |
| `FocusBloxMac/ContentView.swift` | macOS Routing — hier muss Review-Tab conditional werden |
| `FocusBloxMac/MacReviewView.swift` | Aktuelle Review-View — wird bei Coach-Modus ersetzt |
| `FocusBloxMac/MacCoachBacklogView.swift` | Referenz: wie Phase 6b Coach-Modus in macOS integriert hat |

## Existing Patterns

### Coach-Modus Conditional in macOS (Phase 6b)
```swift
// ContentView.swift Zeile 251-255
case .backlog:
    if coachModeEnabled {
        MacCoachBacklogView(...)
    } else {
        backlogView
    }
```
Selbes Pattern fuer Review-Tab anwenden.

### iOS CoachMeinTagView Aufbau
```
ScrollView > VStack:
  1. MorningIntentionView()     ← direkt eingebettet
  2. dayProgressSection          ← X Tasks erledigt
  3. EveningReflectionCard       ← ab 18:00 (Phase 6d)
```

### macOS-Layout
- NavigationSplitView (3 Spalten)
- Navigation via Toolbar-Picker (Segmented Control), KEIN TabView
- Sektionen: Backlog, Blox, Assign, Focus, Review
- Review-Tab: MacReviewView (Heute/Diese Woche Statistiken)

## MorningIntentionView Kompatibilitaet

Die shared View nutzt:
- `@State`, `@AppStorage` — plattformunabhaengig
- `LazyVGrid`, `ScrollView`, `Button` — plattformunabhaengig
- `.ultraThinMaterial` — funktioniert auf macOS
- `.spring()` Animation — funktioniert auf macOS
- `NotificationService` Calls — shared in Sources/
- Keine iOS-spezifischen APIs (kein UIKit, kein NavigationStack)

**Ergebnis: MorningIntentionView ist direkt macOS-kompatibel.**

## Scope-Abgrenzung Phase 6c

**IN Scope:**
- MorningIntentionView in macOS einbetten
- Tages-Fortschritt (erledigte Tasks) anzeigen
- Review-Tab conditional: Coach-Modus → neue View, sonst MacReviewView

**NICHT in Scope (spaetere Phasen):**
- EveningReflectionCard (→ Phase 6d)
- CoachMeinTagView Vollausbau (→ Phase 6e, abhaengig von 5b)

## Empfohlener Ansatz

Neue `MacCoachReviewView.swift` erstellen die:
1. `MorningIntentionView()` einbettet (wie iOS CoachMeinTagView)
2. Tages-Fortschritt zeigt (erledigte Tasks heute)
3. In ContentView.swift den Review-Case conditional macht

Aenderungen an ~3 Dateien, ~80-120 LoC.

## Dependencies
- **Upstream:** DailyIntention, IntentionOption, Discipline, NotificationService (alles shared)
- **Downstream:** MacCoachBacklogView liest `intentionFilterOptions` — wird von MorningIntentionView geschrieben

## Risks
- `intentionJustSet` AppStorage-Flag triggert auf iOS einen Tab-Wechsel zu Backlog. Auf macOS muesste analog `selectedSection = .backlog` gesetzt werden — sonst passiert nach Intention-Setzen nichts.

---

## Analysis

### Type
Feature

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/MacCoachReviewView.swift` | CREATE | Neue View: MorningIntentionView + Tages-Fortschritt |
| `FocusBloxMac/ContentView.swift` | MODIFY | Review-Case conditional (Coach ON → MacCoachReviewView) + Toolbar-Label "Mein Tag" |

### Scope Assessment
- Files: 2 (1 CREATE, 1 MODIFY)
- Estimated LoC: +100 neue, ~15 modifiziert
- Risk Level: LOW

### Technical Approach

1. **MacCoachReviewView.swift** erstellen (Pattern von iOS CoachMeinTagView):
   - `MorningIntentionView()` einbetten (shared, plattformunabhaengig)
   - `dayProgressSection` mit erledigten Tasks heute
   - KEIN NavigationStack (macOS nutzt NavigationSplitView)
   - KEIN `.withSettingsToolbar()` (macOS hat eigenes Menu/Preferences)
   - Daten laden via `@Environment(\.modelContext)` + `.task {}`

2. **ContentView.swift** modifizieren:
   - Review-Case: `if coachModeEnabled { MacCoachReviewView() } else { MacReviewView() }`
   - Toolbar-Picker Label: conditional "Mein Tag" vs "Review"
   - `intentionJustSet` beobachten → `selectedSection = .backlog` setzen

### Cross-Dependencies (AppStorage-Kette)
```
MorningIntentionView → schreibt intentionFilterOptions + intentionJustSet
MacCoachBacklogView  → liest intentionFilterOptions (filtert Tasks)
ContentView          → muss intentionJustSet lesen (Tab-Wechsel zu Backlog)
```

### NICHT aendern
- `MorningIntentionView.swift` — shared, bereits macOS-kompatibel
- `MacReviewView.swift` — bleibt fuer Coach-OFF unveraendert
- `project.pbxproj` — Xcode registriert neue Dateien automatisch

### Existing Specs
- `docs/specs/features/coach-views-meintag.md` — iOS Pendant (Pattern-Referenz)
- `openspec/changes/monster-coach-phase6b/` — Phase 6b macOS (Pattern-Referenz)
- Keine existierende Spec fuer Phase 6c

### Open Questions
- Keine — Ansatz ist klar durch etabliertes Pattern aus Phase 6b
