# Context: ITB-F CaptureContextIntent

## Request Summary
Automatische Task-Erstellung aus dem aktuellen Bildschirminhalt via Apple Intelligence.
"Erstelle Task aus dem was ich gerade sehe" — Siri-Befehl der den Screen-Kontext liest.

## API-Verifizierung (RESEARCH-Ergebnis)

### Kernfrage: Kann FocusBlox lesen was der User in ANDEREN Apps sieht?

**Antwort: NEIN. Technisch nicht moeglich — weder jetzt noch geplant.**

iOS Sandbox verhindert grundsaetzlich, dass eine App den Bildschirminhalt anderer Apps lesen kann. Apple hat keine Plaene dies fuer Drittanbieter-Apps zu aendern.

### Untersuchte APIs

| API | Existiert? | Tut was wir brauchen? |
|-----|-----------|----------------------|
| `ForegroundContinuableIntent` | Ja (seit iOS 17) | NEIN — bringt App nur in Vordergrund, kein Screen-Zugriff |
| `IntentParameter(requestValue: .context)` | NEIN | Gibt es nicht in dieser Form |
| `SemanticContentDescriptor` (Visual Intelligence) | Ja (iOS 26) | TEILWEISE — aber USER muss Screenshot/Kamera aktiv nutzen |
| `AssistantSchema` | Ja (erweitert in iOS 26) | NEIN — kein Produktivitaets/Task-Domain vorhanden |
| `NSUserActivity + appEntityIdentifier` | Ja (iOS 18+) | Nur fuer EIGENE App — nicht fuer andere Apps |
| Siri On-Screen Awareness | ANGEKUENDIGT (WWDC 2024) | NOCH NICHT AUSGELIEFERT (stand Feb 2026) |

### Siri On-Screen Awareness — Status

- WWDC 2024 angekuendigt, sollte in iOS 18 kommen
- Craig Federighi (WWDC 2025): "did not converge quality-wise"
- Verschoben auf iOS 26.4 (Maerz 2026), moeglicherweise iOS 26.5 oder iOS 27
- Apple bestaetigte am 12.02.2026: "still coming in 2026" — kein konkretes Datum
- AUCH WENN es kommt: Siri versteht nur was Apps EXPLIZIT via NSUserActivity deklarieren
- Kein API fuer Drittanbieter-Apps um Screen-Content anderer Apps zu lesen

### Was TATSAECHLICH machbar waere

| Capability | API | Status | Relevanz |
|---|---|---|---|
| FocusBlox-Inhalte fuer Siri exponieren | NSUserActivity + AppEntity | Verfuegbar (iOS 18+) | Mittel — Vorbereitung fuer Siri Personal Context |
| Visual Intelligence FocusBlox-Suche | IntentValueQuery + SemanticContentDescriptor | Verfuegbar (iOS 26) | Niedrig — Nischen-Usecase |
| Task aus Share Sheet erstellen | Share Extension (ITB-E) | Verfuegbar | HOCH — loebbares Problem |
| On-device AI fuer Task-Vorschlaege | Foundation Models | Verfuegbar (iOS 26) | Hoch — bereits implementiert (ITB-B) |

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Intents/CreateTaskIntent.swift` | Bestehende Task-Erstellung via Siri |
| `Sources/Intents/TaskEntity.swift` | AppEntity + EntityQuery Pattern |
| `Sources/Intents/FocusBloxShortcuts.swift` | Siri Phrase Registration |
| `Sources/Services/AITaskScoringService.swift` | Foundation Models Pattern (ITB-B) |
| `Sources/Intents/QuickCaptureSubIntents.swift` | Quick Capture via Intents |

## Existing Patterns
- **AppIntents Pattern:** 5 Intents in `Sources/Intents/` (CreateTask, GetNextUp, CompleteTask, CountOpenTasks, CreateTaskSnippet)
- **TaskEntity + EntityQuery** mit SharedModelContainer (App Group)
- **Foundation Models** via `#if canImport(FoundationModels)` + `@available` (ITB-B)
- **FocusBloxShortcuts** als zentraler `AppShortcutsProvider`

## Dependencies
- **Upstream:** AppIntents Framework, FoundationModels Framework (optional)
- **Downstream:** ITB-G (Proaktive Vorschlaege) haengt von ITB-F ab

## Risks & Considerations
- **HAUPTRISIKO: Feature wie beschrieben NICHT umsetzbar** — Screen-Context anderer Apps ist ein Apple-Sicherheits-Grundsatz
- Siri On-Screen Awareness ist angekuendigt aber seit 18 Monaten verschoben — unzuverlaessig als Basis
- Alternative (Share Extension / ITB-E) loest das gleiche User-Problem auf machbarem Weg
- Visual Intelligence Integration waere technisch machbar aber sehr nischig

## Empfehlung

**ITB-F wie beschrieben ist NICHT umsetzbar.** Die Kernpraemisse (Screen einer anderen App lesen) widerspricht der iOS-Sandbox.

**Stattdessen:**
1. **ITB-E (Share Extension) priorisieren** — loest das gleiche Problem ("Inhalt aus anderen Apps als Task erfassen") auf dem offiziellen iOS-Weg
2. **NSUserActivity-Integration als Vorbereitung** fuer Siri Personal Context (wenn/falls es kommt) — kleiner Aufwand, zukunftssicher
3. **ITB-F als "WONT DO" schliessen** oder umwidmen zu "Siri Context Readiness"
