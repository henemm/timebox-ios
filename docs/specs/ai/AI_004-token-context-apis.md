---
entity_id: AI_004-token-context-apis
type: feature
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [ai, token-count, context-size, monitoring]
---

# AI_004 — tokenCount/contextSize APIs integrieren

## Approval

- [ ] Approved

## Purpose

Integriert die FoundationModels APIs `tokenCount(for:)` und `contextSize` für Debug-Logging und Context-Budget-Monitoring in die bestehenden AI-Services. Ermöglicht frühzeitiges Erkennen wenn Prompts das Context-Window-Budget überschreiten.

## Source

- **File:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **Identifier:** `func performEnrichment()`, `func enrichCategoryAndDuration()`

Zweite Stelle:

- **File:** `Sources/Services/TaskTitleEngine.swift`
- **Identifier:** `func enrichWithSuggestions()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FoundationModels | framework | `SystemLanguageModel.tokenCount(for:)` + `.contextSize` |
| SmartTaskEnrichmentService | service | Haupt-Enrichment mit buildPrompt() |
| TaskTitleEngine | service | Titel-Verbesserung + Kategorie/Dauer |

## Implementation Details

### API-Signaturen (verifiziert in Xcode 26.2 SDK)

```swift
// Auf SystemLanguageModel (nicht LanguageModelSession!)
SystemLanguageModel.default.contextSize  // Int, synchron
SystemLanguageModel.default.tokenCount(for: prompt)  // async throws -> Int
```

Beide sind Teil von iOS 26.0+ — kein extra Availability-Guard nötig.

### Änderung 1: Token-Logging in SmartTaskEnrichmentService

In `performEnrichment()` nach `buildPrompt()`:
```swift
#if DEBUG
let model = SystemLanguageModel.default
let tokens = try? await model.tokenCount(for: prompt)
let contextSize = model.contextSize
if let tokens {
    let pct = contextSize > 0 ? Int(Double(tokens) / Double(contextSize) * 100) : 0
    print("[SmartEnrichment] Prompt: \(tokens) tokens (\(pct)% of \(contextSize) context)")
    if pct > 50 {
        print("[SmartEnrichment] ⚠️ Prompt verbraucht >\(pct)% des Context Windows!")
    }
}
#endif
```

Analog in `enrichCategoryAndDuration()` für den Task-Prompt.

### Änderung 2: Token-Logging in TaskTitleEngine

In `enrichWithSuggestions()` nach Prompt-Erstellung — gleiches Pattern.

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | MODIFY | Token-Logging in performEnrichment() + enrichCategoryAndDuration() |
| `Sources/Services/TaskTitleEngine.swift` | MODIFY | Token-Logging in enrichWithSuggestions() |
| `FocusBloxTests/SmartTaskEnrichmentServiceTests.swift` | MODIFY | Test für Budget-Berechnung |

**Scope:** 3 Dateien, ~40 LoC | **Risk:** LOW

### Design-Entscheidungen

- **Kein separater Helper:** Bei ~6 LoC pro Aufrufstelle ist ein AIContextMonitor-Service Over-Engineering
- **Nur `#if DEBUG`:** Kein Token-Logging in Production — Performance-neutral
- **Nur loggen, nie abbrechen:** 50%-Warnung ist informativ, bricht kein Enrichment ab
- **AITaskScoringService nicht ändern:** Score-Prompts sind kurz, kein Overflow-Risiko

## Expected Behavior

- **Input:** Normaler Enrichment-/Kategorisierungs-Flow
- **Output:** Debug-Console zeigt Token-Verbrauch pro Prompt + Warnung bei >50%
- **Side effects:** Keine — reines Debug-Logging, Production unverändert

## Acceptance Criteria

- contextSize wird beim ersten Enrichment geloggt (Debug-Build)
- Enrichment-Prompt Token-Count wird geloggt (Debug-Build)
- Warnung wenn Prompt >50% des Context Windows verbraucht
- Kein Impact auf Production-Builds (`#if DEBUG`)
- Keine Regression bei bestehenden Unit Tests

## Known Limitations

- Token-Counting ist `async throws` — kann bei Model-Unavailability fehlschlagen (wird mit `try?` gefangen)
- Python SDK unterstützt `tokenCount` NICHT — Eval-Script bleibt unverändert
- Logging nur sichtbar in Xcode Debug-Console, nicht in Production-Logs

## Changelog

- 2026-03-31: Initial spec created (workflow AI_004, GitHub Issue #153)
