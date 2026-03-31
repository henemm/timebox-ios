# Context: AI_004 — tokenCount/contextSize APIs integrieren

## Request Summary
iOS 26.4 bietet `tokenCount(for:)` und `contextSize` APIs im FoundationModels Framework. Diese sollen für Debug-Logging und Context-Budget-Monitoring integriert werden.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | Hauptdienst für Enrichment — performEnrichment() + enrichCategoryAndDuration() |
| `Sources/Services/TaskTitleEngine.swift` | Titel-Verbesserung + enrichWithSuggestions() |
| `Sources/Services/AITaskScoringService.swift` | Task-Scoring — nutzt LanguageModelSession |
| `scripts/eval_prompts.py` | Python-Eval — hat bereits token_count/context_size Aufrufe (Z.310-358) |

## Existing Patterns
- `isAvailable` Pattern: `SystemLanguageModel.default.availability == .available`
- `#if canImport(FoundationModels)` + `@available(iOS 26.0, macOS 26.0, *)` Guards
- Debug-Logging via `print("[SmartEnrichment] ...")`
- Python-Eval hat bereits Token-Analyse-Code (check_token_usage(), Z.310-358)

## Dependencies
- Upstream: FoundationModels Framework (iOS 26.4+)
- Downstream: Keine — reines Logging/Monitoring

## Risks & Considerations
- `tokenCount(for:)` und `contextSize` sind auf `SystemLanguageModel` (nicht `LanguageModelSession`)
- APIs sind Teil von iOS 26.0+ — kein extra Availability-Guard nötig
- Debug-only Logging — kein Impact auf Production UX
- Python SDK hat tokenCount NICHT (siehe eval_prompts.py Z.345-346)
- tokenCount ist `async throws` — braucht try/await

## Analysis

### Type
Feature (API-Integration + Debug-Logging)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/SmartTaskEnrichmentService.swift | MODIFY | Token-Logging in performEnrichment() + enrichCategoryAndDuration() + contextSize beim Start |
| Sources/Services/TaskTitleEngine.swift | MODIFY | Token-Logging in enrichWithSuggestions() |
| FocusBloxTests/SmartTaskEnrichmentServiceTests.swift | MODIFY | Test für Token-Budget-Berechnung |

### Scope Assessment
- Files: 3
- Estimated LoC: ~40
- Risk Level: LOW

### Technical Approach
- Token-Logging direkt in die bestehenden Services (kein separater Helper nötig bei nur ~6 LoC pro Aufruf)
- `SystemLanguageModel.default.contextSize` + `tokenCount(for:)` nutzen
- contextSize beim ersten Enrichment loggen (nicht beim App-Start — Services sind lazy)
- 50%-Warnung als print() im Debug-Build
- AITaskScoringService bewusst NICHT ändern (Score-Prompts sind kurz, kein Overflow-Risiko)
