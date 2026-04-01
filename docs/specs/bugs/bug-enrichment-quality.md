---
entity_id: bug-enrichment-quality
type: bugfix
created: 2026-04-01
updated: 2026-04-01
status: draft
version: "1.0"
tags: [ai, enrichment, importance, urgency, duration, prompt]
---

# Bug: Enrichment-Qualität — Importance/Urgency willkürlich, Duration fehlt

## Approval

- [ ] Approved

## Purpose

Beim Batch-Enrichment ("Bestehende Tasks analysieren") werden Importance und Urgency willkürlich auf hohe Werte gesetzt (viele Tasks bekommen importance=3, urgency=urgent). Duration bleibt oft nil. Drei Ursachen identifiziert: Feedback-Schleife im Batch-Kontext, fehlende Duration-Promotion, Prompt-Bias.

## Source

- **File:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **Identifier:** `func reanalyzeAllTasks()`, `func reanalyzeTask()`, `func performEnrichment()`, `func buildPrompt()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FoundationModels Framework | framework | AI-Inferenz (On-Device ~3B Modell) |
| LocalTask | model | Datenmodell mit importance/urgency/estimatedDuration/suggestedDuration |
| TaskTitleEngine | service | Deterministische Keyword-Extraktion (Steps 1-5 in reanalyzeTask) |
| TaskPriorityScoringService | service | Downstream-Consumer von importance/urgency |

## Implementation Details

### Hebel 1: Feedback-Schleife unterbrechen

**Problem:** `buildPrompt()` (Zeile 409) ruft `fetchRecentTaskContext()` pro Task auf. Beim Batch-Lauf werden die ersten (falsch) enrichten Tasks sofort zum Kontext für alle folgenden → Snowball importance=3.

**Fix:** In `reanalyzeAllTasks()` den Context EINMAL vor der Schleife laden. Neuer Parameter `cachedContext: String` an `reanalyzeTask()` → `performEnrichment()` → `buildPrompt()` durchreichen. Bei Batch: cached Context verwenden. Bei Einzel-Enrichment: wie bisher dynamisch laden.

### Hebel 2: Duration-Promotion in reanalyzeTask()

**Problem:** `performEnrichment()` schreibt Duration zu `task.suggestedDuration` (Zeile 350-353), aber `confirmSuggestions()` wird in `reanalyzeTask()` nie aufgerufen → `estimatedDuration` bleibt nil.

**Fix:** Nach Step 6 in `reanalyzeTask()`: Wenn `estimatedDuration == nil` und `suggestedDuration` gesetzt → direkt übertragen:
```swift
if task.estimatedDuration == nil, let dur = task.suggestedDuration {
    task.estimatedDuration = dur
    changed = true
}
```

### Hebel 3: Prompt-Balance + .anyOf() Constraints

**Problem:** System-Prompt definiert importance=3 als "must do (Pflichten, Deadlines, Finanzen)" — zu viele Alltagstasks fallen darunter. TaskEnrichment struct hat keine `.anyOf()` Constraints (im Gegensatz zu TaskSuggestion).

**Fix A — Prompt anpassen (Zeile 304-307):**
```
"Wichtigkeit (1-3):"
"  1 = nice to have (Freizeit, Hobby, optional, kein Zeitdruck)"
"  2 = should do (die MEISTEN Alltagstasks: Haushalt, Einkaufen, Termine, Besorgungen, Routine)"
"  3 = must do (NUR echte Pflichten mit Konsequenzen: Steuererklärung, Arzttermin, Deadlines, Finanzen)"
""
"WICHTIG: Im Zweifel importance=2. Nur bei echten Pflichten mit spürbaren Konsequenzen importance=3."
"Dringlichkeit: true NUR wenn ein konkretes Datum/Frist existiert (morgen, heute, bis [Datum]). Ohne Datum → false."
```

**Fix B — .anyOf() Constraints auf TaskEnrichment (Zeile 58-71):**
```swift
@Guide(description: "Importance", .anyOf(["1", "2", "3"]))
let suggestedImportance: Int

@Guide(description: "Category", .anyOf(["income", "maintenance", "recharge", "learning", "giving_back"]))
let suggestedTaskType: String

@Guide(description: "Cognitive energy", .anyOf(["high", "low"]))
let suggestedEnergyLevel: String

@Guide(description: "Duration in minutes", .anyOf(["5", "15", "30", "60"]))
let suggestedDurationMinutes: Int
```

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `Sources/Services/SmartTaskEnrichmentService.swift` | MODIFY | Alle 3 Hebel |

**Scope:** 1 Datei, ~40 LoC | **Risk:** MEDIUM (AI-Prompt-Änderung beeinflusst alle Enrichments)

## Expected Behavior

- **Input:** User klickt "Bestehende Tasks analysieren" mit 263 Tasks
- **Output:** Tasks bekommen ausgewogene Importance-Verteilung (~60% importance=2, ~25% importance=1, ~15% importance=3). Duration wird für die meisten Tasks gesetzt. Urgency nur bei Tasks mit echtem Zeitdruck.
- **Side effects:** Bestehende manuell gesetzte Werte werden NICHT überschrieben (Guards bleiben)

## Acceptance Criteria

1. Batch-Enrichment setzt NICHT mehr überwiegend importance=3 — Verteilung muss mindestens 50% importance≤2 sein
2. Duration wird für ≥80% der Tasks gesetzt (nicht nil)
3. Urgency=urgent nur bei Tasks mit echtem Zeitbezug (Datum, Frist)
4. Bestehende User-gesetzte Werte werden nicht überschrieben
5. iOS Build erfolgreich
6. Bestehende Unit Tests (KeywordSystemTests, TaskTitleEngineTests, SmartTaskEnrichmentServiceTests) grün

## Known Limitations

- On-Device ~3B Modell ist nicht-deterministisch — exakte Prozentwerte können variieren
- Python-Eval-Script muss mit geändertem Prompt synchronisiert werden (separates Ticket)
- Guardrail-Violations (Apple Safety Filter) werden nicht gefixt (separates Problem)

## Changelog

- 2026-04-01: Initial spec created (workflow bug-enrichment-quality, nach Challenge korrigiert)
