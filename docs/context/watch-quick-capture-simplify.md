# Context: Watch Quick Capture vereinfachen

## Request Summary
Komplikation-Tap auf der Watch zeigt unnoetig "Was moechtest du tun?" + Abbrechen-Button. Soll direkt Spracheingabe oeffnen, nach "Fertig" sofort speichern. Kein Zwischenscreen, keine Rueckfragen.

## Ist-Zustand (aktueller Flow)
1. Complication-Tap → App oeffnet → ContentView rendert
2. VoiceInputSheet oeffnet automatisch (Sheet mit NavigationStack)
3. Sheet zeigt: **"Neuer Task"** Titel + **"Was moechtest du tun?"** Text + TextField + **"Abbrechen"** Button
4. TextField wird fokussiert → System-Diktat-Keyboard erscheint
5. User spricht → Text erscheint in TextField
6. **1.5s Pause** → Auto-Save + Haptik + Dismiss

**Problem:** Schritte 3 + 6 sind unnoetige Reibung. Der User sieht kurz den Zwischenscreen bevor Diktat startet, und wartet dann 1.5s bis gespeichert wird.

## Soll-Zustand (gewuenschter Flow)
1. Complication-Tap → App oeffnet
2. Diktat startet direkt (minimales Sheet, kein sichtbarer Zwischenscreen)
3. User spricht → Text wird erkannt
4. **Sofort speichern** + Haptik + Dismiss

**Abbruch:** Swipe-Down auf dem Sheet (watchOS-Standard) statt explizitem "Abbrechen"-Button.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | **Hauptaenderung** — UI vereinfachen, Auto-Save beschleunigen |
| `FocusBloxWatch Watch App/ContentView.swift` | Unveraendert (Auto-Open + Deep-Link funktionieren bereits) |
| `FocusBloxWatch Watch AppUITests/FocusBloxWatch_Watch_AppUITests.swift` | Tests anpassen (kein cancelButton, kein "Was moechtest du tun?" mehr) |
| `FocusBloxWatch Watch AppTests/FocusBloxWatch_Watch_AppTests.swift` | Unit Tests — pruefen ob Aenderungen noetig |
| `FocusBloxWatchWidgets/QuickCaptureComplication.swift` | Unveraendert (Complication + Deep-Link) |

## Existing Patterns
- Auto-Save mit DispatchWorkItem + Timer (bereits implementiert, nur Timing aendern)
- `.focused($isFocused)` + `onAppear { isFocused = true }` fuer automatischen Diktat-Start
- `WKInterfaceDevice.current().play(.success)` fuer Haptik-Feedback

## Dependencies
- **Upstream:** SwiftData ModelContext, WKInterfaceDevice (Haptik)
- **Downstream:** CloudKit Sync (Task wird via SwiftData → CloudKit zum iPhone gepusht)

## Existing Specs
- `docs/specs/features/watch-quick-capture-inapp.md` — Draft (nie approved), beschreibt den bereits implementierten Flow
- `docs/project/stories/watch-quick-capture.md` — JTBD User Story (approved)
- `docs/specs/features/watch-complication.md` — Complication Spec (done)

## Aenderungen (geschaetzt)
| Datei | Aenderung |
|-------|-----------|
| `VoiceInputSheet.swift` | "Was moechtest du tun?" entfernen, NavigationStack/Toolbar entfernen, Auto-Save Delay reduzieren (1.5s → sofort/minimal) |
| `Watch_AppUITests.swift` | Tests anpassen: cancelButton-Tests entfernen, "Was moechtest du tun?"-Assert entfernen |

**Geschaetzt: 2 Dateien, ~30 LoC netto (Reduktion) — Groesse S**

## Analysis

### Type
Bug — Verhalten weicht von User Story ab ("1 Tap + Sprechen + fertig, max 3s aktive Interaktion")

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | MODIFY | NavigationStack + Toolbar + Prompt-Text entfernen, Auto-Save Delay 1.5s → 0.5s |
| `FocusBloxWatch Watch AppUITests/FocusBloxWatch_Watch_AppUITests.swift` | MODIFY | cancelButton-Tests + Prompt-Text-Assert entfernen, restliche Tests anpassen |

### Scope Assessment
- Files: 2
- Estimated LoC: +5/-30 (Netto-Reduktion ~25 LoC)
- Risk Level: LOW (isolierte Watch-App, kein Shared-Code)

### Technical Approach
1. VoiceInputSheet: NavigationStack + Toolbar komplett entfernen → pures VStack mit TextField
2. "Was moechtest du tun?" Text entfernen
3. Auto-Save Delay von 1.5s auf 0.5s reduzieren (Sicherheit gegen Partial-Diktat)
4. Abbruch per Sheet-Swipe-Down (watchOS-Standard)
5. UI Tests: 2 Tests entfernen, 4 Tests anpassen (kein cancelButton-Abhaengigkeit)

### Dependencies
- Upstream: SwiftData ModelContext, WKInterfaceDevice (Haptik)
- Downstream: CloudKit Sync (unveraendert)
- Cross-Platform: Kein Impact (Watch-Code ist isoliert)

### Risks & Considerations
- **watchOS Diktat-Verhalten:** TextField-Focus triggert System-Diktat-Keyboard. Ohne NavigationStack/Toolbar ist das Sheet schlanker, aber die Diktat-UI bleibt gleich.
- **Sofort-Save vs. Partial-Text:** Wenn Diktat stueckweise Text liefert, koennte sofortiges Speichern zu Partial-Saves fuehren. Minimaler Delay (0.5s) als Sicherheitsnetz.
- **Cancel ohne Button:** watchOS erlaubt Sheet-Dismiss per Swipe-Down — das ist ausreichend als Abbruch-Mechanismus.

### Open Questions
- Keine — Anforderungen sind klar aus User Story + Bug-Beschreibung.
