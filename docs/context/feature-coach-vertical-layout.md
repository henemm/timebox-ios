# Context: Coach-Auswahl — Vertikales Layout + ausführliche AI-Pitches

## Request Summary
Die Coach-Auswahl zeigt 4 winzige Kacheln in einem 2x2 Grid. Text wird abgeschnitten (lineLimit(2), caption2-Schrift). AI-Pitches sind auf 120 Zeichen begrenzt. Umbau auf vertikale Liste mit horizontalen Karten (wie CoachMissionCard) und ausführlichere AI-Texte (300 Zeichen, 3-4 Sätze).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/MorningIntentionView.swift` | **HAUPTZIEL** — Grid→VStack, coachCard horizontal umbauen |
| `Sources/Services/CoachPitchService.swift` | **HAUPTZIEL** — Längere Pitches (300 statt 120 Zeichen) |
| `FocusBloxTests/CoachPitchServiceTests.swift` | **HAUPTZIEL** — Test anpassen (5 statt 3 Tasks) |
| `Sources/Views/Components/CoachMissionCard.swift` | Referenz für horizontales Layout (56×56 Monster, HStack) |
| `Sources/Models/CoachType.swift` | displayName, subtitle, shortPitch, monsterImage, color, personality |
| `Sources/Services/CoachMissionService.swift` | generatePreview(), recommendedCoach() — unverändert |
| `Sources/Views/CoachMeinTagView.swift` | Embeddet MorningIntentionView (iOS) |
| `FocusBloxMac/MacCoachReviewView.swift` | Embeddet MorningIntentionView (macOS) |
| `FocusBloxUITests/MorningIntentionUITests.swift` | UI Tests für Coach-Auswahl — AccessibilityIDs bleiben stabil |

## Existing Patterns
- **CoachMissionCard:** HStack(alignment: .top, spacing: 12), Monster 56×56 Circle links, VStack rechts mit Name+Subtitle, Headline, Detail
- **Empfohlen-Badge:** Aktuell star.fill auf Monster → wird zu "Empfohlen" Capsule-Label
- **AI-Pitch Flow:** Sofort shortPitch/teaser anzeigen, AI lädt parallel, ersetzt Text mit Animation

## Dependencies
- Upstream: CoachType (Model), CoachMissionService (Previews), CoachPitchService (AI)
- Downstream: CoachMeinTagView (iOS), MacCoachReviewView (macOS), MorningIntentionUITests

## Existing Specs
- Keine spezifische Spec für MorningIntentionView vorhanden

## Risks & Considerations
- AccessibilityIDs bleiben gleich → UI Tests sollten stabil bleiben
- `columns`-Property und `LazyVGrid` werden entfernt — rein lokale Änderung
- Große Monster-Vorschau (120px) oben wird ebenfalls entfernt — Monster ist jetzt in jeder Karte
- CoachPreview.teaser (max 60 Zeichen) bleibt als shortPitch-Ergänzung, wird ZUSÄTZLICH zum AI-Text angezeigt

## Analysis

### Type
Feature (UI-Redesign + Service-Parameter-Anpassung)

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/MorningIntentionView.swift | MODIFY | Grid→VStack, coachCard horizontal, Empfohlen-Capsule |
| Sources/Services/CoachPitchService.swift | MODIFY | Längere Pitches (300 Zeichen, 5 Tasks, 3-4 Sätze) |
| FocusBloxTests/CoachPitchServiceTests.swift | MODIFY | Test für 5 statt 3 Tasks anpassen |

### Scope Assessment
- Files: 3
- Estimated LoC: ~75-105
- Risk Level: LOW

### Technical Approach
1. Test zuerst anpassen (TDD RED — max5 Test schlägt fehl mit aktuellem prefix(3))
2. CoachPitchService ändern (TDD GREEN — Tests grün)
3. MorningIntentionView Layout-Umbau (rein visuell, kein Service-Eingriff)

### Dependencies
- Upstream: CoachType (Model), CoachMissionService (Previews)
- Downstream: CoachMeinTagView (iOS), MacCoachReviewView (macOS) — beide embedden MorningIntentionView
- AccessibilityIDs bleiben identisch → UI Tests stabil

### Open Questions
- Keine — Layout ist shared, macOS bekommt automatisch das neue Layout
