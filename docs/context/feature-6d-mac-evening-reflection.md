# Context: Phase 6d — EveningReflectionCard in macOS

## Request Summary
Abend-Spiegel (EveningReflectionCard) soll auf macOS in MacCoachReviewView angezeigt werden — mit Coach-Fulfillment, Monster-Icons und KI-Texten, genau wie auf iOS.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/EveningReflectionCard.swift` | Shared Card — wird direkt in macOS eingebettet |
| `FocusBloxMac/MacCoachReviewView.swift` | Ziel-View — fehlt aktuell EveningReflectionCard + FocusBlock-Loading + AI-Text |
| `Sources/Views/CoachMeinTagView.swift` | iOS-Referenz — zeigt wie EveningReflectionCard eingebettet ist |
| `Sources/Services/IntentionEvaluationService.swift` | evaluateFulfillment() + fallbackTemplate() — shared, keine Aenderung noetig |
| `Sources/Services/EveningReflectionTextService.swift` | AI-Text-Generierung — shared, keine Aenderung noetig |
| `Sources/Models/DailyCoachSelection.swift` | Coach-Auswahl laden — shared |
| `Sources/Models/FocusBlock.swift` | FocusBlock Modell — benoetigt fuer Fulfillment-Berechnung |
| `FocusBloxMac/ContentView.swift:270-275` | Routing — MacCoachReviewView wird bei coachModeEnabled gezeigt |
| `FocusBloxMacUITests/MacCoachReviewUITests.swift` | Bestehende macOS UI Tests — erweitern um Evening-Tests |
| `FocusBloxUITests/EveningReflectionCardUITests.swift` | iOS UI Tests — Referenz fuer macOS Tests |

## Existing Patterns
- **iOS EveningReflectionCard Integration (CoachMeinTagView.swift):**
  - `showEveningReflection` computed: `hour >= 18` ODER `-ForceEveningReflection` Launch-Arg
  - `DailyCoachSelection.load().coach` fuer aktiven Coach
  - FocusBlock-Loading via `EventKitRepository.fetchFocusBlocks(for:)`
  - AI-Text via `EveningReflectionTextService().generateTextForCoach()`
  - Card nur sichtbar wenn `showEveningReflection && coach != nil`

- **macOS Coach-View Pattern (MacCoachReviewView):**
  - `@Environment(\.modelContext)` fuer SwiftData
  - `.task { await loadData() }` fuer initiales Laden
  - Kein NavigationStack (macOS nutzt NavigationSplitView extern)
  - Kein `.withSettingsToolbar()` (macOS hat Preferences-Menu)

- **macOS Launch-Args Pattern (MacCoachReviewUITests):**
  - `-coachModeEnabled 1/0` statt `-CoachModeEnabled`
  - `-UITesting -MockData -ApplePersistenceIgnoreState YES`

## Dependencies
- **Upstream (was MacCoachReviewView nutzt):**
  - `EveningReflectionCard` (shared View)
  - `IntentionEvaluationService` (shared Service)
  - `EveningReflectionTextService` (shared Service)
  - `DailyCoachSelection` (shared Model)
  - `EventKitRepository` (shared, via Environment)
  - `FocusBlock` (shared Model)

- **Downstream (was MacCoachReviewView nutzt):**
  - `ContentView.swift` routet zu MacCoachReviewView bei coachModeEnabled

## Existing Specs
- `docs/specs/features/coach-review-macos.md` — Phase 6c Spec (Basis, erwaehnt 6d als TODO)
- `docs/specs/features/coach-views-meintag.md` — iOS CoachMeinTagView Spec (Referenz-Pattern)
- `docs/specs/services/evening-reflection-text-service.md` — AI Text Service Spec

## Key Insight: Minimale Aenderung
MacCoachReviewView ist fast identisch zu CoachMeinTagView — es fehlen nur:
1. `showEveningReflection` computed property
2. `todayBlocks: [FocusBlock]` State + Loading
3. `aiReflectionText: String?` State + Loading
4. `EveningReflectionCard(...)` in der View-Hierarchie
5. `onChange(of: intentionJustSet)` fuer AI-Text-Reload

**Keine neuen Dateien noetig.** Nur `MacCoachReviewView.swift` erweitern (~30 LoC).

## Risks & Considerations
- EventKitRepository Environment muss in macOS verfuegbar sein (ist es — FocusBloxMacApp.swift:259)
- `-ForceEveningReflection` Launch-Arg muss auch in macOS App erkannt werden (ProcessInfo — funktioniert)
- macOS UI Tests nutzen `-coachModeEnabled 1` (klein), iOS nutzt `-CoachModeEnabled` (gross)

---

## Analysis

### Type
Feature (Phase 6d — Monster Coach macOS-Paritaet)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/MacCoachReviewView.swift` | MODIFY | +30 LoC: Evening-States, showEveningReflection, FocusBlock/AI-Loading, Card einbetten |
| `FocusBloxMacUITests/MacCoachReviewUITests.swift` | MODIFY | +25 LoC: 2-3 neue Tests fuer Evening Card Sichtbarkeit + Inhalt |

### Scope Assessment
- Files: 2
- Estimated LoC: +55
- Risk Level: LOW

### Technical Approach
**Empfehlung:** MacCoachReviewView.swift um Evening-Logik erweitern — identisch zum iOS-Pattern in CoachMeinTagView.swift.

Konkret:
1. `@State todayBlocks: [FocusBlock]` + `@State aiReflectionText: String?` hinzufuegen
2. `@Environment(\.eventKitRepository)` fuer FocusBlock-Zugriff (statt lokaler Instanz — konsistenter mit macOS-Pattern)
3. `showEveningReflection` computed property (hour >= 18 || ForceEveningReflection)
4. `loadData()` erweitern um FocusBlock-Fetch
5. `loadAIReflectionText()` async Funktion (wie iOS)
6. `EveningReflectionCard(...)` in VStack nach dayProgressSection (conditional)
7. `onChange(of: intentionJustSet)` fuer AI-Text-Reload

**Alle Dependencies sind shared und auf macOS verfuegbar.** Keine neuen Dateien, keine neuen Dependencies.

### Dependencies (alle bestaetigt verfuegbar)
- EveningReflectionCard.swift — shared, plattformunabhaengig
- IntentionEvaluationService — shared
- EveningReflectionTextService — shared, macOS 26.0+ kompatibel
- DailyCoachSelection — shared, UserDefaults via App Group
- EventKitRepository — bereits im macOS Environment injiziert (FocusBloxMacApp.swift:259)
- FocusBlock — shared Model

### Open Questions
Keine — alles klar.
