# Context: Smart Task Interpretation + Similar-Task Learning

## Request Summary
TaskTitleEngine soll idiomatische Phrasen wie "Erinnere mich..." besser verstehen und mehr relative Datumsangaben unterstuetzen. SmartTaskEnrichmentService soll von aehnlichen bestehenden Tasks lernen (Attribute uebernehmen).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/TaskTitleEngine.swift` | Feature A: Prompt + Guide + relativeDateFrom erweitern |
| `Sources/Services/SmartTaskEnrichmentService.swift` | Feature B: fetchRecentTaskContext() + Prompt erweitern |
| `FocusBloxTests/TaskTitleEngineTests.swift` | Bestehende Tests (14 Tests) |
| `FocusBloxTests/SmartTaskEnrichmentServiceTests.swift` | Bestehende Tests (8 Tests) |
| `Sources/Models/LocalTask.swift` | Model mit importance, urgency, taskType, tags, aiEnergyLevel |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Ruft beide Services auf — KEINE Aenderung noetig |

## Existing Patterns
- `relativeDateFrom()` ist ein static helper mit switch/case auf lowercased Strings
- `@Guide` Descriptions steuern die AI-Generierung (FoundationModels @Generable)
- `buildPrompt()` baut Task-Kontext als String zusammen
- Enrichment laeuft async im Hintergrund nach Task-Erstellung
- User-gesetzte Werte werden NIE ueberschrieben (Guard-Pattern)

## Dependencies
- Upstream: FoundationModels (Apple Intelligence), SwiftData, LocalTask Model
- Downstream: LocalTaskSource.createTask() ruft beide Services auf — Flow bleibt identisch

## Risks & Considerations
- Prompt-Laenge: ~30 Tasks als Kontext = ~500 Woerter extra — kein Problem fuer on-device AI
- Enrichment wird minimal langsamer (1 SwiftData Fetch extra) — irrelevant da async
- Rueckwaertskompatibel: Ohne Similar Tasks verhaelt sich alles wie bisher

## Analysis

### Type
Feature (2 Sub-Features: A = Prompt-Verbesserung, B = Similar-Task-Lernen)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/TaskTitleEngine.swift | MODIFY | Prompt + Guide + relativeDateFrom erweitern |
| Sources/Services/SmartTaskEnrichmentService.swift | MODIFY | fetchRecentTaskContext() + buildPrompt() + System-Prompt |
| FocusBloxTests/TaskTitleEngineTests.swift | MODIFY | Neue Tests fuer relativeDateFrom + Floskel-Handling |
| FocusBloxTests/SmartTaskEnrichmentServiceTests.swift | MODIFY | Neue Tests fuer fetchRecentTaskContext + buildPrompt |

### Scope Assessment
- Files: 4 (2 Source + 2 Test)
- Estimated LoC: ~70 (Feature A: ~30, Feature B: ~40)
- Risk Level: LOW (async, backwards-compatible, no Model changes)

### Technical Approach
- Feature A: relativeDateFrom() mit neuen Mappings (uebermorgen, naechste woche, Wochentage), System-Prompt + @Guide mit Floskel-Erkennung
- Feature B: fetchRecentTaskContext() fetcht letzte 30 Tasks mit Attributen, buildPrompt() fuegt Kontext ein, System-Prompt mit Similar-Task-Instruktion

### Reihenfolge
1. Feature A zuerst (einfacher, sofortiger Mehrwert)
2. Feature B danach (baut auf funktionierendem Enrichment auf)
