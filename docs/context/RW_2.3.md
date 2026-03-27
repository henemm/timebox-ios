# Context: RW_2.3 — Limitation Guard

## Request Summary
Nicht-modale Inline-Warnung wenn der User sich mehr Tasks/Stunden vornimmt als sein historischer Durchschnitt zeigt. Informierend, nicht blockierend.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/NextUpSection.swift` | Primaerer Ort fuer das Inline-Banner (nach Header, vor Task-Liste) |
| `Sources/Views/MorningCoachingSection.swift` | Sekundaerer Ort (Banner wenn Vorschlaege uebernommen die Limit ueberschreiten) |
| `Sources/Views/DayView.swift` | Parent View — liefert `nextUpTasks` via Filter (L364), zeigt Morning-Modus (L164-200) |
| `Sources/Models/BehavioralProfile.swift` | Liefert `avgTasksPerDay: Double?` und `avgMinutesPerDay: Double?` |
| `Sources/Models/PlanItem.swift` | `effectiveDuration: Int` (Minuten) pro Task |
| `Sources/Services/BehavioralProfileService.swift` | Berechnet Profil, cached in-memory, 28-Tage-Fenster |

## Existing Patterns
- **NextUpSection** ist eine reine View ohne eigene Datenabfrage — bekommt `tasks: [PlanItem]` von aussen
- **MorningCoachingSection** bekommt `suggestions: [NextUpSuggestion]` von aussen
- **BehavioralProfile** Felder sind `nil` wenn zu wenig Daten (< 5 aktive Tage = erste 14 Tage)
- Datenfluss: `DayView.loadMorningData()` → filtert `nextUpTasks` → uebergibt an Sections

## Dependencies
- **Upstream:** `BehavioralProfileService.profile()` fuer historische Durchschnitte
- **Upstream:** `PlanItem.effectiveDuration` fuer aktuelle Summe
- **Downstream:** `NextUpSection` und `MorningCoachingSection` rendern das Banner

## Existing Specs
- `docs/specs/rework/2.3-limitation-guard.md` — Feature-Spec (Ready)
- `docs/specs/rework/0.2-behavioral-profile-impl.md` — BehavioralProfileService (Erledigt)

## Risks & Considerations
- BehavioralProfile-Felder koennen `nil` sein → Guard muss gracefully damit umgehen (keine Warnung zeigen)
- Spec sagt "max 1x pro Ueberschreitung" → Dismissed-State muss in-memory getrackt werden
- Spec sagt "keine Warnung in ersten 14 Tagen" → Profile nil-Check reicht (< 5 aktive Tage = nil)
- NextUpSection bekommt Tasks von aussen → Service-Aufruf muss in DayView oder direkt in Section passieren
- Shared Code (iOS + macOS) → Standard SwiftUI, keine plattformspezifischen Anpassungen noetig

---

## Analysis

### Type
Feature

### Architecture Insights
- `BehavioralProfileService` ist ein stateless enum mit static methods (kein DI noetig)
- DayView ruft bereits `BehavioralProfileService.profile()` auf (L379-387) → Profil ist verfuegbar
- `NextUpSection` und `MorningCoachingSection` sind reine presentational Views (Daten via init-Parameter)
- Neuer `LimitationGuardService` sollte gleiches Pattern folgen: stateless enum mit static method
- Datenfluss: DayView berechnet Warning-State → uebergibt als Parameter an Sub-Views

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/LimitationGuardService.swift` | CREATE | Stateless Service: vergleicht Next-Up-Summe mit Profil |
| `Sources/Views/NextUpSection.swift` | MODIFY | + Inline-Banner Parameter + Rendering |
| `Sources/Views/MorningCoachingSection.swift` | MODIFY | + Inline-Banner nach Suggestion-Confirm |
| `Sources/Views/DayView.swift` | MODIFY | Wire Service, @State dismissed, Parameter an Sub-Views |
| `FocusBloxTests/LimitationGuardServiceTests.swift` | CREATE | Unit Tests fuer Service-Logik |
| `FocusBloxUITests/LimitationGuardUITests.swift` | CREATE | UI Tests fuer Banner-Darstellung |

### Scope Assessment
- Files: 4 Produktion + 2 Test = 6 total
- Estimated LoC: +180/-10
- Risk Level: LOW (isoliertes Feature, keine bestehende Logik betroffen)

### Technical Approach
1. `LimitationGuardService` als stateless enum: `static func evaluate(tasks:profile:) -> LimitationWarning?`
2. `LimitationWarning` Struct: `taskCount`, `taskAvg`, `minutesSum`, `minutesAvg`, `kind` (.tasks/.minutes/.both)
3. DayView: `@State private var limitationWarning: LimitationWarning?` + `@State private var warningDismissed = false`
4. DayView berechnet Warning in `loadMorningData()` (Profil ist dort schon verfuegbar)
5. NextUpSection: Neuer optionaler Parameter `warning: LimitationWarning?` + `onDismiss: (() -> Void)?`
6. MorningCoachingSection: Gleicher Banner nach Suggestion-Confirm (Callback updated Warning)
7. Banner-Design: `.ultraThinMaterial` Background, SF Symbol `exclamationmark.triangle`, informierender Ton

### Dependencies
- **Upstream (existiert):** `BehavioralProfileService.profile()`, `PlanItem.effectiveDuration`
- **Downstream (wird erstellt):** `NextUpSection` + `MorningCoachingSection` rendern Banner
- **Keine externen Dependencies**
