---
entity_id: INFRA_014-workflow-hardening
type: infrastructure
created: 2026-04-13
updated: 2026-04-13
status: draft
version: "1.0"
tags: [workflow, quality-gates, tdd]
---

# INFRA_014 — Workflow Hardening

## Approval

- [ ] Approved

## Purpose

Drei gezielte Verbesserungen am Workflow-System, um 5 wiederkehrende Schwachstellen zu beheben, die in einer Praxis-Analyse identifiziert wurden. Ziel: Claude kann keine Workflow-Schritte mehr auslassen, die zu falschen Tests, fehlenden Tests oder unvollstaendigem Scope fuehren.

## Source

- **Files:**
  - `.claude/hooks/edit_gate.py` — Neues Inspect-UI Gate
  - `.claude/hooks/workflow.py` — Neues Feld + Command
  - `.claude/hooks/adversary_dialog.py` — Testplan-Extraktion
  - `.claude/commands/04-tdd-red.md` — Inspect-UI Pflicht
  - `.claude/commands/03-write-spec.md` — Affected-Files Cross-Check
  - `.claude/commands/06-validate.md` — Regressions-Scope-Minimum

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| edit_gate.py | Hook | Blockiert UI-Test-Edits ohne Inspect-UI |
| workflow.py | State Manager | Trackt `inspect_ui_done` Feld |
| adversary_dialog.py | QA Tool | Prueft Spec-Testplan-Vollstaendigkeit |
| 04-tdd-red.md | Command | Erinnert an Inspect-UI Pflicht |

## Massnahme A: Inspect-UI Gate in Phase 5

### Problem
`/inspect-ui` ist laut CLAUDE.md Pflicht vor jedem UI Test, wird aber nicht enforced. Ergebnis: Falsche Accessibility-IDs in Tests, die erst im GREEN auffallen.

### Loesung

**1. Neues Workflow-Feld `inspect_ui_done`** in `workflow.py`:
- Default: `false`
- Wird gesetzt durch neuen Command `mark-inspect-ui-done <screen-name>`
- Minimum 30 Zeichen Notes (wie andere mark-Commands)

**2. Gate in `edit_gate.py`** (Phase 5 — TDD RED):
- Wenn die Zieldatei ein UI-Test ist (`FocusBloxUITests/` im Pfad)
- UND `inspect_ui_done` im Workflow `false` ist
- → BLOCK mit Meldung: "BLOCKED: /inspect-ui nicht ausgefuehrt. Pflicht vor UI-Tests."

**3. Gate in `_validate_transition`** (workflow.py):
- Beim Wechsel phase5_tdd_red → phase6_implement:
- Wenn `ui_test_red_done` gesetzt ist aber `inspect_ui_done` nicht
- → BLOCK: "inspect_ui_done not set — run /inspect-ui before writing UI tests"

**4. Update `04-tdd-red.md`**:
- Neuer Pflicht-Schritt 0: `/inspect-ui` ausfuehren und `mark-inspect-ui-done` setzen
- Checkliste um Punkt erweitern

### Akzeptanzkriterien
- AC-A1: Edit auf `FocusBloxUITests/*.swift` in Phase 5 wird geblockt wenn `inspect_ui_done = false`
- AC-A2: Edit auf `FocusBloxUITests/*.swift` in Phase 5 wird erlaubt wenn `inspect_ui_done = true`
- AC-A3: Edit auf `FocusBloxTests/*.swift` (Unit Tests) wird NICHT blockiert (kein Inspect-UI noetig)
- AC-A4: Phase-Transition phase5→phase6 erfordert `inspect_ui_done` wenn UI-Tests geschrieben wurden

## Massnahme B: Spec-Testplan-Compliance im Adversary

### Problem
Die Spec enthaelt einen Testplan mit konkreten Tests. Aber niemand prueft, ob alle geplanten Tests auch tatsaechlich geschrieben wurden. Fehlende Tests werden erst vom Adversary als "unbewiesen" markiert — aber dann nicht nachgeholt.

### Loesung

**1. Neue Funktion `parse_spec_test_plan()` in `adversary_dialog.py`**:
- Extrahiert `## Test Plan` Section aus der Spec
- Sammelt alle Bullet-Points (geplante Tests)
- Gibt Liste von Test-Beschreibungen zurueck

**2. Neue Funktion `check_test_coverage()` in `adversary_dialog.py`**:
- Input: Spec-Testplan + Pfade zu Test-Dateien
- Liest die Test-Dateien und extrahiert `func test*()` Methoden
- Vergleicht: Fuer jeden Spec-Testplan-Punkt → gibt es eine passende Testmethode?
- Output: Liste von fehlenden Tests

**3. Neuer CLI-Command `coverage`**:
```bash
python3 adversary_dialog.py coverage <spec-path> <test-file1> [test-file2...]
```
Output: Abgleich Spec-Tests vs. tatsaechliche Tests mit PASS/MISSING pro Punkt.

**4. Integration in `06-validate.md`**:
- Task 2 (SPEC COMPLIANCE) fuehrt zusaetzlich `coverage` aus
- Fehlende Tests = FAIL der Validation

### Akzeptanzkriterien
- AC-B1: `parse_spec_test_plan()` extrahiert Testplan-Punkte aus Spec
- AC-B2: `check_test_coverage()` erkennt fehlende Tests korrekt
- AC-B3: `coverage` CLI gibt Abgleich-Report aus
- AC-B4: 06-validate nutzt coverage-Check in Task 2

## Massnahme C: Affected-Files Cross-Check beim Spec-Write

### Problem
Die Analyse in Phase 2 listet affected_files oft unvollstaendig auf. Dann muss in Phase 5/6 mehrfach zurueck zu Phase 4, um Dateien nachzuregistrieren.

### Loesung

**1. Update `03-write-spec.md`** — Neuer Pflicht-Schritt nach Spec-Erstellung:
- Alle in der Spec genannten Dateipfade extrahieren (Code-Bloecke, Source-Verweise)
- Gegen `affected_files` im Workflow-State abgleichen
- Fehlende Dateien automatisch mit `set-affected-files` nachregistrieren
- Warnung ausgeben wenn > 2 Dateien nachregistriert werden (Zeichen fuer schwache Analyse)

**2. Kein neuer Hook** — nur Prompt-Update in der Command-Datei.

### Akzeptanzkriterien
- AC-C1: `03-write-spec.md` enthaelt Cross-Check-Schritt
- AC-C2: Anleitung zum automatischen Nachregistrieren fehlender Dateien
- AC-C3: Warnung bei > 2 nachregistrierten Dateien

## Bonus: Regressions-Scope-Minimum

### Problem
Nur 28 von 2096 Tests im Regressions-Lauf geprueft. Das ist zu wenig.

### Loesung
- Update `06-validate.md` Task 3 (REGRESSION CHECK):
  - Mindestens ALLE Tests der betroffenen Module ausfuehren
  - Plus: `./scripts/sim.sh unit FocusBloxTests` fuer die volle Unit-Suite
  - UI-Regression: Mindestens die 3 Haupt-Test-Suiten

### Akzeptanzkriterien
- AC-D1: 06-validate enthaelt Mindest-Regressions-Scope
- AC-D2: Betroffene Module + volle Unit-Suite + 3 UI-Suiten als Minimum definiert

## Test Plan

### Unit Tests (Python)
1. `test_inspect_ui_gate_blocks_ui_test_without_preflight` — Edit auf UITest-Datei ohne inspect_ui_done → BLOCK
2. `test_inspect_ui_gate_allows_ui_test_with_preflight` — Edit auf UITest-Datei mit inspect_ui_done → ALLOW
3. `test_inspect_ui_gate_ignores_unit_tests` — Edit auf Unit-Test-Datei ohne inspect_ui_done → ALLOW
4. `test_parse_spec_test_plan_extracts_items` — Spec mit Test Plan → korrekte Liste
5. `test_check_test_coverage_finds_missing` — Testplan mit 3 Punkten, nur 2 Tests → 1 MISSING
6. `test_check_test_coverage_all_present` — Alle Tests vorhanden → 0 MISSING

### Manuelle Verifikation
- Workflow-Durchlauf mit neuem Gate: /inspect-ui vergessen → BLOCKED Meldung
- Coverage-Check auf bestehender Spec → korrekte Ausgabe

## Known Limitations

- Testplan-Matching ist fuzzy (Name-Aehnlichkeit, nicht exakte 1:1 Zuordnung)
- Affected-Files Cross-Check ist Prompt-basiert, kein Hook-Enforcement
- Regressions-Minimum ist Prompt-basiert, kein automatischer Scope-Check

## Changelog

- 2026-04-13: Initial spec created
