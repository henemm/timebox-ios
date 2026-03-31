# Context: AI_002 — Enrichment-Prompt Tuning (67% → 85%+)

## Request Summary
Der Enrichment-Prompt in `SmartTaskEnrichmentService` erreicht nur 67% Feldgenauigkeit (16/24) im Python-Eval. Importance wird systematisch zu niedrig geschätzt, Energy bei kognitiv anspruchsvollen Tasks falsch, und Urgency-Keywords in Titeln ("bis Freitag") werden ignoriert. Ziel: ≥ 85% (≥21/24 Felder).

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | **Hauptdatei** — enthält `performEnrichment()` (Z.246-288) mit System-Instructions und `buildPrompt()` (Z.319-344) |
| `scripts/eval_prompts.py` | **Eval-Script** — Python-basierte Prompt-Evaluation mit 8 Enrichment-Cases (Z.89-99) |
| `Sources/Services/TaskTitleEngine.swift` | Deterministische Urgency/Importance-Extraktion — "dringend"/"wichtig" Keywords (Z.183-189), aber NICHT "bis Freitag" |
| `FocusBloxTests/SmartTaskEnrichmentServiceTests.swift` | Bestehende Unit Tests — Guard-Conditions, User-Value-Preservation, Similar-Task-Context |

## Existing Patterns

### Enrichment-Prompt (aktuell, Swift Z.250-260)
- Deutsche System-Instructions
- Importance: "1=nice to have, 2=should do, 3=must do"
- Dringlichkeit: "Zeitkritische Begriffe (Termin, Frist, morgen, heute) = true"
- Energie: "high = tiefe Fokus-Arbeit, low = Routine"
- Verweis auf ähnliche bestehende Tasks (Few-Shot via Context)

### Deterministische Vorverarbeitung (TaskTitleEngine)
- `extractDeterministicUrgency()`: Nur explizite Keywords ("dringend", "urgent", "asap", "sofort", "eilig")
- `extractDeterministicImportance()`: Nur "wichtig"→3, "unwichtig"→1
- **Lücke:** "bis Freitag", "bis morgen" werden NICHT deterministisch als urgent erkannt

### Python Eval (eval_prompts.py Z.125-132)
- Prompt ist identisch zum Swift-Prompt (gespiegelt)
- 8 Test-Cases mit erwarteten Werten für Importance, Urgent, Energy
- Frische Session pro Task (wie Production-Code)

## Konkrete Fehler (aus Issue #151)
| Task | Feld | Erwartet | Bekommen |
|------|------|----------|----------|
| Steuererklärung abgeben | Importance | 3 | 2 |
| Steuererklärung abgeben | Energy | high | low |
| Einkaufen gehen | Urgent | false | true |
| Gitarre üben | Importance | 1 | 2 |
| Gitarre üben | Energy | low | high |
| Bewerbung bis Freitag fertig | Importance | 3 | 2 |
| Bewerbung bis Freitag fertig | Urgent | true | false |
| Bewerbung bis Freitag fertig | Energy | high | low |

## Ansatz-Optionen
1. **Few-Shot Beispiele im Prompt** — Konkrete deutsche Beispiele die exakt die Grenzfälle abdecken
2. **Klarere Regeln** — "Steuererklärung = Pflicht = 3", "bis [Datum] = urgent"
3. **Deterministische Vorverarbeitung erweitern** — "bis Freitag"/"bis morgen" in TaskTitleEngine als urgent erkennen
4. **@Guide Descriptions verbessern** — Klarere Beschreibungen in der Generable-Struct

## Dependencies
- Upstream: `FoundationModels` Framework (Apple), `LocalTask` Model, `TaskTitleEngine`
- Downstream: Alle Views die `importance`, `urgency`, `taskType`, `aiEnergyLevel` anzeigen

## Existing Specs
- `docs/specs/rework/1.2-1.3-refiner-impl.md` — Refiner (entfernt in RW_1.5)
- Kein eigener Spec für Enrichment-Prompt-Qualität vorhanden

## Risks & Considerations
- On-Device-Modell (~3B Parameter) hat begrenzte Reasoning-Fähigkeiten → Few-Shot ist effektiver als komplexe Regeln
- Prompt-Änderungen betreffen BEIDE Stellen: Swift + Python-Eval (müssen synchron bleiben)
- Deterministische Urgency-Erweiterung ("bis Freitag") könnte False Positives erzeugen
- @Guide Descriptions in der Generable-Struct sind ein zweiter Kanal neben den System-Instructions

## Analysis

### Type
Feature (Prompt-Tuning + deterministische Erweiterung)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/SmartTaskEnrichmentService.swift | MODIFY | Few-Shot Beispiele im System-Prompt + klarere @Guide Descriptions |
| Sources/Services/TaskTitleEngine.swift | MODIFY | "bis [Wochentag/heute/morgen]" → urgent (deterministisch) |
| scripts/eval_prompts.py | MODIFY | ENRICHMENT_INSTRUCTIONS + @Guide sync |
| FocusBloxTests/TaskTitleEngineTests.swift | MODIFY | TDD RED: Tests für "bis Freitag" Urgency |
| FocusBloxTests/SmartTaskEnrichmentServiceTests.swift | MODIFY | Tests für Few-Shot buildPrompt |

### Scope Assessment
- Files: 5
- Estimated LoC: +80-110
- Risk Level: LOW-MEDIUM

### Technical Approach
**Zwei Hebel, Reihenfolge: Hebel 2 (deterministisch) vor Hebel 1 (AI-Prompt).**

**Hebel 2 — Deterministische Urgency (TaskTitleEngine):**
- `extractDeterministicUrgency()` erweitern: Pattern `\bbis\s+(morgen|heute|Montag|...|Sonntag)\b`
- Greift VOR dem AI-Prompt → task.urgency bereits gesetzt → AI überschreibt nicht
- False-Positive-sicher: "von A bis Z", "bis auf weiteres" matchen NICHT

**Hebel 1 — Prompt-Tuning (SmartTaskEnrichmentService):**
- 3-4 Few-Shot Beispiele in System-Instructions:
  - "Steuererklärung abgeben" → importance=3, energy=high
  - "Gitarre üben" → importance=1, energy=low
  - "Dringend: Server ist down" → importance=3, urgent=true, energy=high
- Klarere @Guide Descriptions mit Ankern

### Implementierungs-Reihenfolge
1. TDD RED: Tests für "bis [Datum]" Urgency + Few-Shot buildPrompt
2. Hebel 2: TaskTitleEngine "bis [Wochentag]"-Matcher
3. Hebel 1: Prompt Few-Shot + @Guide tuning
4. Python-Sync: eval_prompts.py aktualisieren
5. Validation: Unit Tests + Python Eval ≥ 85%

### Dependencies
- Upstream: FoundationModels Framework, LocalTask Model, AppSettings
- Downstream: LocalTaskSource.createTask(), FocusBloxApp (Batch-Enrichment), macOS App
- `extractDeterministicUrgency` wird an 4 Stellen aufgerufen (CreateTaskIntent, TaskTitleEngine, SmartTaskEnrichmentService, LocalTaskSource)
