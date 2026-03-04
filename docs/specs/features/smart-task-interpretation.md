---
entity_id: smart-task-interpretation
type: feature
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [ai, enrichment, task-title, similar-tasks]
---

# Smart Task Interpretation + Similar-Task Learning

## Approval

- [ ] Approved

## Purpose

TaskTitleEngine soll idiomatische Phrasen ("Erinnere mich...", "Ich muss noch...") korrekt bereinigen und erweiterte Datumsangaben (uebermorgen, naechste Woche, Wochentage) extrahieren. SmartTaskEnrichmentService soll von aehnlichen bestehenden Tasks lernen und deren Attribute (Kategorie, Importance, Urgency) uebernehmen.

## Source

- **File A:** `Sources/Services/TaskTitleEngine.swift`
- **File B:** `Sources/Services/SmartTaskEnrichmentService.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| FoundationModels | Framework | Apple Intelligence on-device AI |
| LocalTask | Model | SwiftData Task-Model mit Attributen |
| LocalTaskSource | Service | Ruft beide Services auf (KEINE Aenderung) |

## Feature A: TaskTitleEngine Prompt-Verbesserung

### A1: relativeDateFrom() erweitern

Neue Mappings zusaetzlich zu "today/heute" und "tomorrow/morgen":

| Input | Output |
|-------|--------|
| "uebermorgen" | +2 Tage |
| "naechste woche" | Naechster Montag |
| "montag" bis "sonntag" | Naechster entsprechender Wochentag |

### A2: System-Prompt erweitern

Neue Regeln im LanguageModelSession Instructions-Block:
- Entferne Einleitungsfloskeln: "Erinnere mich...", "Ich muss noch...", "Vergiss nicht..."
- Extrahiere dabei Zeitangaben: "heute", "morgen", "naechste Woche", "bis Freitag"
- Bereinigte Titel beschreiben die AKTION, nicht die Erinnerung

### A3: @Guide Descriptions erweitern

- `title`: Hinweis auf Floskel-Entfernung ("Erinnere mich daran X" -> "X")
- `dueDateRelative`: Neue Werte "uebermorgen", "naechste woche", Wochentage

## Feature B: Similar-Task-Lernen

### B1: fetchRecentTaskContext()

Neue private Methode in SmartTaskEnrichmentService:
- Fetch: Letzte 30 Tasks (sortiert nach createdAt desc) mit mindestens 1 gesetztem Attribut (importance != nil ODER urgency != nil ODER taskType nicht leer)
- Output: Kompakter String, eine Zeile pro Task: "- Titel | Kat: X | Imp: Y | Urg: Z"

### B2: buildPrompt() erweitern

Neuer Block in buildPrompt():
- Ruft fetchRecentTaskContext() auf
- Fuegt Kontext ein: "Bestehende Tasks des Nutzers:\n[context]"
- Instruktion: "Wenn du aehnliche Tasks findest, uebernimm deren Attribute-Muster"

### B3: System-Prompt erweitern

Neue Regel im LanguageModelSession Instructions-Block:
- "Orientiere dich an den Attributen aehnlicher bestehender Tasks wenn vorhanden"

## Expected Behavior

### Feature A
- **Input:** "Erinnere mich heute daran Herrn Mueller anzurufen"
- **Output:** title="Herrn Mueller anrufen", dueDate=heute, isUrgent=true
- **Input:** "Ich muss uebermorgen noch Steuern machen"
- **Output:** title="Steuern machen", dueDate=+2 Tage

### Feature B
- **Input:** Neue Task "Lohnsteuer abgeben", bestehende Tasks mit "Steuer..." haben category=income, importance=3
- **Output:** Neue Task bekommt category=income, importance=3 (uebernommen von aehnlichen Tasks)
- **Fallback:** Ohne aehnliche Tasks verhaelt sich alles wie bisher

- **Side effects:** Enrichment minimal langsamer (1 extra Fetch + laengerer Prompt), irrelevant da async

## Test Plan

### Unit Tests (Feature A)
1. `relativeDateFrom("uebermorgen")` → Date +2 Tage
2. `relativeDateFrom("naechste woche")` → naechster Montag
3. `relativeDateFrom("freitag")` → naechster Freitag
4. AI-Test (wenn verfuegbar): "Erinnere mich heute daran X" → title ohne Floskel, dueDate=heute

### Unit Tests (Feature B)
5. `fetchRecentTaskContext()` gibt kompakten String zurueck mit Task-Infos
6. `fetchRecentTaskContext()` ignoriert Tasks ohne Attribute
7. `buildPrompt()` enthaelt "Bestehende Tasks" Block wenn Kontext vorhanden
8. `buildPrompt()` funktioniert ohne Kontext (leerer Fetch)

### UI Tests
9. Quick Capture: Task mit "Erinnere mich..." → Titel bereinigt
10. Enrichment: Task aehnlich zu bestehender → Attribute uebernommen

## Known Limitations

- On-device AI (Foundation Models) muss verfuegbar sein — Tests mit `guard isAvailable` oder `XCTSkip`
- Wochentag-Berechnung: "Freitag" an einem Freitag → naechste Woche Freitag (nicht heute)
- Similar-Task-Lernen basiert auf AI-Interpretation, nicht deterministischem Matching

## Scope

- **Dateien:** 2 Source + 2 Test = 4 Dateien
- **LoC:** ~70 (Feature A: ~30, Feature B: ~40)
- **Risiko:** LOW

## Changelog

- 2026-03-04: Initial spec created
