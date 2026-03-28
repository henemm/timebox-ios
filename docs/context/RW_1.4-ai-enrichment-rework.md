# Context: RW_1.4 — AI Enrichment Rework

## Request Summary
Die TaskTitleEngine soll umgebaut werden: AI-Titel-Bereinigung raus (30% Trefferquote), stattdessen deterministische Regex-Bereinigung. Neu: AI-gestuetzte Kategorisierung (88% korrekt) und Zeitschaetzung (75% korrekt) mit @Guide(.anyOf()) Constraints.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/TaskTitleEngine.swift` | **Kern-Datei** — ImprovedTask @Generable, performImprovement(), shouldAcceptImprovedTitle() werden entfernt/ersetzt |
| `FocusBloxTests/TaskTitleEngineTests.swift` | Tests fuer stripKeywords, shouldAcceptImprovedTitle, relativeDateFrom, AI-Tests — muss angepasst werden |
| `FocusBloxTests/AITitleQualityTests.swift` | AI-Qualitaetstests — Titel-Matrix raus, Kategorie+Dauer-Tests bleiben/werden angepasst |
| `Sources/Models/LocalTask.swift` | Hat bereits `suggestedCategory`, `suggestedDuration`, `needsTitleImprovement` Properties |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Aufrufer: `stripKeywords()` bei Task-Erstellung, `improveTitleIfNeeded()` nach Save |
| `Sources/FocusBloxApp.swift` | Aufrufer: `TaskTitleEngine` + `improveAllPendingTitles()` bei App-Start |
| `FocusBloxMac/FocusBloxMacApp.swift` | Aufrufer: identisch zu iOS App-Start |
| `Sources/Intents/CreateTaskIntent.swift` | Aufrufer: `extractDeterministicDueDate()` — bleibt unveraendert |

## Existing Patterns
- `@Generable` Structs mit `@Guide(.anyOf())` — bereits getestet mit ImprovedTask, funktioniert mit iOS 26.2
- `SmartTaskEnrichmentService` existiert parallel und fuellt andere Felder (importance, urgency) — TaskTitleEngine soll Kategorie+Dauer hinzufuegen
- `LocalTask.applyAISuggestions()` uebernimmt `suggestedCategory` → `taskType` und `suggestedDuration` → `estimatedDuration`

## Dependencies
- **Upstream:** Apple FoundationModels (SystemLanguageModel), SwiftData ModelContext
- **Downstream:** LocalTaskSource.createTask(), FocusBloxApp/FocusBloxMacApp Startup, CreateTaskIntent

## Existing Specs
- `docs/specs/rework/1.4-ai-enrichment-rework-impl.md` — Detaillierte Spec (SPEC READY)
- `docs/specs/services/task-title-engine.md` — Service-Dokumentation

## Risks & Considerations
- `shouldAcceptImprovedTitle()` wird entfernt — Tests die darauf basieren muessen geloescht werden
- `ImprovedTask` @Generable wird durch `TaskSuggestion` @Generable ersetzt
- Backward-Kompatibilitaet: `improveTitleIfNeeded()` bleibt als API erhalten
- ~10-15% guardrailViolation Rate bei Apple AI — Fallback: kein Vorschlag
- Keine UI-Aenderungen — rein Service-Layer

## Analysis

### Type
Feature (Service-Layer Rework)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/TaskTitleEngine.swift` | MODIFY | Entferne ImprovedTask/@Generable, performImprovement(), shouldAcceptImprovedTitle(). Fuege cleanTitle(), TaskSuggestion/@Generable, enrichWithSuggestions() hinzu. |
| `FocusBloxTests/TaskTitleEngineTests.swift` | MODIFY | shouldAcceptImprovedTitle-Tests loeschen, cleanTitle()-Tests hinzufuegen, AI-Kategorie/Dauer-Tests hinzufuegen |
| `FocusBloxTests/AITitleQualityTests.swift` | MODIFY | AI-Titel-Matrix-Tests entfernen, Kategorie+Dauer-Qualitaetstests hinzufuegen |

### Scope Assessment
- Files: 3 (wie in Spec definiert)
- Estimated LoC: ~170 Add / ~180 Del (netto -10 LoC)
- Risk Level: LOW — backward-kompatible API, kein Model-Change, keine UI-Aenderung

### Technical Approach
1. `cleanTitle()` als statische Methode: Regex-basiert E-Mail-Prefixe, Floskeln, Urgency entfernen
2. `TaskSuggestion` @Generable mit @Guide(.anyOf()) fuer Kategorie (5 Werte) und Dauer (4 Werte)
3. `enrichWithSuggestions()` als neue interne Methode: cleanTitle() + deterministic date + AI suggestions
4. `improveTitleIfNeeded()` bleibt als oeffentliche API, ruft intern cleanTitle() + enrichWithSuggestions() auf
5. `shouldAcceptImprovedTitle()` und `ImprovedTask` komplett entfernen

### Overlap mit SmartTaskEnrichmentService
- SmartTaskEnrichmentService setzt `taskType` direkt fuer **nicht-raw** Tasks (nach Refiner)
- TaskTitleEngine setzt `suggestedCategory`/`suggestedDuration` fuer **raw** Tasks (Share Ext, Siri, Watch)
- Verschiedene Lifecycle-Stufen → kein Konflikt
- SmartTaskEnrichmentService hat KEINE Dauer-Schaetzung → TaskTitleEngine fuellt diese Luecke

### Dependencies
- Upstream: FoundationModels, SwiftData, LocalTask Model (keine Aenderung noetig)
- Downstream: LocalTaskSource.createTask(), FocusBloxApp, FocusBloxMacApp, CreateTaskIntent (alle backward-kompatibel)

### Open Questions
Keine — Spec ist vollstaendig und klar.
