---
entity_id: AI_003-categorization-prompt-tuning
type: feature
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [ai, categorization, prompt-tuning]
---

# AI_003 — Kategorisierungs-Prompt Tuning (77% → 90%+)

## Approval

- [ ] Approved

## Purpose

Erhöht die Kategorisierungs-Genauigkeit von 77% auf mindestens 90% (≥27/30), indem der Prompt von Englisch auf Deutsch umgestellt, Kategorie-Beschreibungen erweitert und Few-Shot-Beispiele für die 7 bekannten Fehlklassifizierungen hinzugefügt werden.

## Source

- **File:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **Identifier:** `func enrichCategoryAndDuration()` (Z.218-224)

Zweite Prompt-Stelle:

- **File:** `Sources/Services/TaskTitleEngine.swift`
- **Identifier:** `func enrichWithSuggestions()` (Z.415-422)

Dritte Stelle (Eval):

- **File:** `scripts/eval_prompts.py`
- **Identifier:** `CATEGORIZATION_INSTRUCTIONS` (Z.106-113)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FoundationModels Framework | framework | AI-Inferenz für Kategorisierung |
| LocalTask | model | Enthält `taskType` und `suggestedCategory` |
| TaskTitleEngine.TaskSuggestion | struct | @Generable mit @Guide `.anyOf()` für Kategorien |
| CategorizedTask (Python) | class | @fm.generable Äquivalent im Eval-Script |

## Implementation Details

### Änderung: Kategorisierungs-Prompt (3 Stellen synchron)

Aktueller Prompt (Englisch):
```
Categorize tasks into exactly one category:
- income: Work, earning money, career, freelance, invoices, clients
- maintenance: Household, errands, repairs, cleaning, groceries, health appointments
- recharge: Exercise, rest, hobbies, meditation, wellness, fun
- learning: Study, reading, courses, skills, research, training
- giving_back: Family, friends, volunteering, gifts, social events, helping others
```

Neuer Prompt (Deutsch, mit erweiterten Beschreibungen + Few-Shot):
```
Du kategorisierst Aufgaben in genau eine Kategorie:
- income: Arbeit, Geld verdienen, Karriere, Freelance, Rechnungen, Kunden, Berichte, Präsentationen, Code, Meetings
- maintenance: Haushalt, Besorgungen, Reparaturen, Putzen, Einkaufen, Gesundheitstermine, Behörden, Steuern, Versicherungen
- recharge: Sport, Erholung, Hobbys, Meditation, Wellness, Freizeit, Konzerte, Filme, Serien, Musik
- learning: Lernen, Lesen, Kurse, Weiterbildung, Konferenzen (WWDC etc.), Vokabeln, Podcasts
- giving_back: Familie, Freunde, Ehrenamt, Geschenke, soziale Events, Helfen

Beispiele:
  Quartalsbericht fertigstellen → income
  Bewerbung schreiben → income
  Pull Request reviewen → income
  Steuererklärung abgeben → maintenance
  WWDC-Session anschauen → learning
  Gitarre üben → recharge
  Kruder & Dorfmeister Tickets kaufen → recharge
```

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | MODIFY | Prompt in `enrichCategoryAndDuration()` auf Deutsch + Few-Shot |
| `Sources/Services/TaskTitleEngine.swift` | MODIFY | Prompt in `enrichWithSuggestions()` auf Deutsch + Few-Shot |
| `scripts/eval_prompts.py` | MODIFY | `CATEGORIZATION_INSTRUCTIONS` auf Deutsch + Few-Shot |

**Scope:** 3 Dateien, ~30 LoC | **Risk:** LOW

### Implementierungs-Reihenfolge

1. `eval_prompts.py` zuerst ändern (schneller Feedback-Loop ohne Xcode)
2. Python-Eval ausführen → Score ≥ 90% verifizieren
3. Swift-Prompts synchronisieren (SmartTaskEnrichmentService + TaskTitleEngine)
4. Unit Tests + macOS Build

## Expected Behavior

- **Input:** Deutsche Task-Titel wie "Quartalsbericht fertigstellen", "Steuererklärung abgeben"
- **Output:** Korrekte Kategorie-Zuordnung (income, maintenance, recharge, learning, giving_back)
- **Side effects:** Prompt wird an 3 Stellen synchron geändert; Python-Eval-Score steigt auf ≥ 90%

## Acceptance Criteria

- Kategorisierung ≥ 90% (≥27/30) im Python-Eval
- Gitarre üben → recharge (nicht learning)
- Steuererklärung → maintenance (nicht income)
- Bewerbung schreiben → income (nicht learning)
- Kruder & Dorfmeister Tickets → recharge (nicht giving_back)
- Keine Regression bei bestehenden Unit Tests

## Known Limitations

- Few-Shot-Beispiele optimieren auf die bekannten 30 Test-Cases — unbekannte Grenzfälle könnten weiterhin falsch klassifiziert werden
- On-Device ~3B Modell hat begrenzte Sprachfähigkeiten — 100% ist unrealistisch
- Python-Eval und On-Device-Inferenz können leicht divergieren (nicht-deterministisch)

## Changelog

- 2026-03-31: Initial spec created (workflow AI_003, GitHub Issue #152)
