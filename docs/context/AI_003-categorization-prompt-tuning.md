# Context: AI_003 — Kategorisierungs-Prompt Tuning (77% → 90%+)

## Request Summary
Der Kategorisierungs-Prompt erreicht nur 77% (23/30). Systematische Fehler: "schreiben/üben/lernen" triggert learning (auch bei Arbeit/Hobby), "kaufen" wird als income assoziiert, Steuererklärung als income statt maintenance. Ziel: ≥ 90% (≥27/30).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartTaskEnrichmentService.swift` Z.218-224 | `enrichCategoryAndDuration()` — Kategorisierungs-Prompt #1 |
| `Sources/Services/TaskTitleEngine.swift` Z.415-422 | `enrichWithSuggestions()` — Kategorisierungs-Prompt #2 (gleicher Text!) |
| `scripts/eval_prompts.py` Z.106-113 | `CATEGORIZATION_INSTRUCTIONS` — Python-Eval Prompt |
| `scripts/eval_prompts.py` Z.29-67 | `CATEGORIZATION_CASES` — 30 Test-Cases |
| `scripts/eval_prompts.py` Z.139-148 | `CategorizedTask` Generable-Klasse |

## Existing Patterns
- Kategorisierungs-Prompt ist auf Englisch (im Gegensatz zum Enrichment-Prompt der auf Deutsch ist)
- Prompt ist identisch an 2 Swift-Stellen + 1 Python-Stelle (3-fach Sync nötig!)
- @Guide mit `.anyOf()` constraint in TaskSuggestion (TaskTitleEngine Z.318)
- Few-Shot Beispiele haben bei AI_002 (Enrichment) 67% → 100% gebracht

## Konkrete Fehler (7 Stück, Python-Eval 2026-03-31)
| Task | Erwartet | Bekommen | Muster |
|------|----------|----------|--------|
| Quartalsbericht fertigstellen | income | learning | "fertigstellen" → learning |
| Bewerbung schreiben | income | learning | "schreiben" → learning |
| Meeting mit Chef vorbereiten | income | learning | "vorbereiten" → learning |
| Steuererklärung abgeben | maintenance | income | "Steuer" → Geld |
| WWDC-Session anschauen | learning | recharge | "anschauen" → Freizeit |
| Kruder & Dorfmeister Tickets kaufen | recharge | giving_back | Bandname verwirrt |
| Pull Request reviewen | income | learning | "reviewen" → learning |

## Dependencies
- Upstream: FoundationModels Framework, LocalTask Model
- Downstream: Alle Views die `taskType`/`suggestedCategory` anzeigen
- Prompt existiert an 3 Stellen (2x Swift, 1x Python) — müssen synchron bleiben

## Existing Specs
- `docs/specs/ai/AI_002-enrichment-prompt-tuning.md` — Verwandtes Prompt-Tuning (implemented)

## Risks & Considerations
- **3-fach Sync-Pflicht:** SmartTaskEnrichmentService + TaskTitleEngine + eval_prompts.py
- Few-Shot Beispiele könnten Overfitting erzeugen (nur auf die 30 Test-Cases optimiert)
- On-Device ~3B Modell: Zu viele Regeln könnten andere Kategorien verschlechtern

## Analysis

### Type
Feature (Prompt-Tuning)

### Root Cause
1. **Sprachmismatch:** Englischer Prompt mit deutschen Tasks — Verben wie "fertigstellen/schreiben/vorbereiten" werden vom 3B-Modell falsch auf englische Keywords gemappt
2. **Fehlende Negativabgrenzung:** "Steuern" → income (weil "money"), keine Regel für "Behörden = maintenance"
3. **Keine Few-Shot Beispiele:** Im Gegensatz zum Enrichment-Prompt (100% mit Few-Shot)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/SmartTaskEnrichmentService.swift | MODIFY | Kategorisierungs-Prompt auf Deutsch + Few-Shot |
| Sources/Services/TaskTitleEngine.swift | MODIFY | Kategorisierungs-Prompt auf Deutsch + Few-Shot |
| scripts/eval_prompts.py | MODIFY | CATEGORIZATION_INSTRUCTIONS auf Deutsch + Few-Shot |

### Scope Assessment
- Files: 3
- Estimated LoC: ~30
- Risk Level: LOW

### Technical Approach
1. Prompt auf **Deutsch** umstellen (wie Enrichment-Prompt)
2. Erweiterte Kategorie-Beschreibungen ("Berichte, Meetings" bei income, "Steuern, Behörden" bei maintenance)
3. **7 Few-Shot Beispiele** — exakt die 7 Fehlklassifizierungen als Anker
4. Python-Eval zuerst → Score verifizieren → dann Swift synchronisieren

### Implementierungs-Reihenfolge
1. eval_prompts.py: Prompt ändern + Python-Eval ausführen (schneller Feedback-Loop)
2. Score ≥ 90% verifizieren
3. SmartTaskEnrichmentService.swift: Prompt synchronisieren
4. TaskTitleEngine.swift: Prompt synchronisieren
5. Unit Tests + macOS Build
