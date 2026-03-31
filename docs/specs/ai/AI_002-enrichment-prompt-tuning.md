---
entity_id: AI_002-enrichment-prompt-tuning
type: feature
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [ai, enrichment, prompt-tuning, task-title-engine]
---

# AI_002 — Enrichment-Prompt Tuning (67% → 85%+)

## Approval

- [ ] Approved

## Purpose

Erhöht die Feldgenauigkeit des Enrichment-Prompts von aktuell 67% auf mindestens 85%, indem zwei Hebel kombiniert werden: deterministische Urgency-Erkennung für Datums-Formulierungen in TaskTitleEngine und Few-Shot-Beispiele im AI-Prompt von SmartTaskEnrichmentService für Importance- und Energy-Grenzfälle.

## Source

- **File:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **Identifier:** `class SmartTaskEnrichmentService`

Zweite betroffene Quelle:

- **File:** `Sources/Services/TaskTitleEngine.swift`
- **Identifier:** `func extractDeterministicUrgency`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FoundationModels Framework | framework | AI-Inferenz für Enrichment |
| LocalTask | model | Datenmodell, das angereichert wird |
| AppSettings | service | Konfigurationsquelle |
| LocalTaskSource.createTask() | function | Downstream-Konsument der angereicherten Tasks |
| FocusBloxApp | module | iOS-seitiger Downstream-Konsument |
| FocusBloxMac | module | macOS-seitiger Downstream-Konsument |
| extractDeterministicUrgency | function | Wird an 4 Stellen aufgerufen; bekommt neuen "bis [Datum]"-Matcher |
| eval_prompts.py | script | Python-Eval-Script, muss mit ENRICHMENT_INSTRUCTIONS und @Guide synchronisiert werden |

## Implementation Details

### Hebel 1: Deterministischer Urgency-Matcher in TaskTitleEngine

Neues Regex-Pattern in `extractDeterministicUrgency`:

```
\bbis\s+(morgen|heute|Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Ende\s+der\s+Woche)\b
```

Trifft das Pattern zu, wird `urgency = true` deterministisch gesetzt — ohne AI-Aufruf.

**False-Positive-Schutz:** Das Pattern schließt bewusst aus:
- "von A bis Z" (kein Wochentag/Zeitwort nach "bis")
- "bis auf weiteres" (kein erlaubtes Zeitwort)
- "bis zu 3 Stunden" (kein erlaubtes Zeitwort)

### Hebel 2: Few-Shot-Beispiele im System-Prompt

In `SmartTaskEnrichmentService` werden dem System-Prompt konkrete Few-Shot-Beispiele für Grenzfälle hinzugefügt:

- Steuererklärung / Bewerbungsunterlagen → `importance: 3`, `energy: high`
- Klarere @Guide-Descriptions für importance und energy

Die gleichen Beispiele und Guide-Descriptions werden in `scripts/eval_prompts.py` (ENRICHMENT_INSTRUCTIONS + @Guide) synchronisiert, damit der Python-Eval dieselbe Grundlage hat.

### Implementierungs-Reihenfolge

1. **TDD RED:** Tests für "bis [Datum]" Urgency + Few-Shot `buildPrompt` schreiben (schlagen fehl)
2. **Hebel 2:** `extractDeterministicUrgency` um "bis [Wochentag]"-Matcher erweitern
3. **Hebel 1:** Prompt Few-Shot + @Guide tuning in `SmartTaskEnrichmentService`
4. **Python-Sync:** `eval_prompts.py` aktualisieren
5. **Validation:** Unit Tests grün + Python Eval ≥ 85%

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | MODIFY | Few-Shot Beispiele im System-Prompt + klarere @Guide Descriptions |
| `Sources/Services/TaskTitleEngine.swift` | MODIFY | "bis [Wochentag/heute/morgen]" → urgent |
| `scripts/eval_prompts.py` | MODIFY | ENRICHMENT_INSTRUCTIONS + @Guide sync |
| `FocusBloxTests/TaskTitleEngineTests.swift` | MODIFY | TDD RED: Tests für "bis Freitag" Urgency |
| `FocusBloxTests/SmartTaskEnrichmentServiceTests.swift` | MODIFY | Tests für Few-Shot buildPrompt |

**Scope:** 5 Dateien, ~80–110 LoC | **Risk:** LOW-MEDIUM

## Expected Behavior

- **Input:** Task-Titel wie "Steuererklärung bis Freitag einreichen" oder "Bewerbungsunterlagen vorbereiten"
- **Output:** Angereicherter LocalTask mit korrekten Feldern: urgency, importance, energy
- **Side effects:** `extractDeterministicUrgency` wird an 4 Stellen aufgerufen — alle erhalten den neuen Matcher; Python-Eval-Score steigt auf ≥ 85%

## Acceptance Criteria

- Enrichment-Score ≥ 85% im Python-Eval (`scripts/eval_prompts.py`)
- "bis [Datum/Wochentag]" wird als `urgent = true` erkannt
- "Steuererklärung" / "Bewerbung" → `importance: 3` + `energy: high`
- Keine Regression bei bestehenden Unit Tests

## Known Limitations

- Der Urgency-Matcher ist auf deutsche Wochentage und "morgen/heute/Ende der Woche" beschränkt; englische Formulierungen werden nicht abgedeckt
- Few-Shot-Beispiele verbessern Grenzfälle, garantieren aber keine 100%-Treffsicherheit bei ungewöhnlichen Formulierungen
- Python-Eval misst Offline-Score; On-Device-Inferenz mit FoundationModels kann abweichen

## Changelog

- 2026-03-31: Initial spec created (workflow AI_002, GitHub Issue #151)
