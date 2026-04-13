# Phase 7: Validation

You are starting the **Validation Phase**.

## CRITICAL: ALL TESTS MUST PASS

**Before validation can succeed:**
1. ALL Unit Tests must PASS
2. ALL UI Tests must PASS
3. NO manual testing requests allowed

## Prerequisites

Check workflow state:
```bash
python3 .claude/hooks/workflow.py status
```

Required:
- `current_phase`: `phase6_implement` or later
- `ui_test_red_done`: `true`
- `ui_test_red_result`: contains "failed"

### Adversary-Dialog Artifact (PFLICHT)

Pruefe ob ein Dialog-Artifact existiert:
```bash
python3 .claude/hooks/adversary_dialog.py validate docs/artifacts/<workflow-name>/adversary-dialog.md
```

Ohne bestandenes Dialog-Artifact darf die Validation NICHT starten.
Das Artifact muss:
- Alle Checklisten-Punkte bewiesen haben ([x])
- Mindestens 2 Dialog-Runden dokumentieren
- Aktuell sein (< 60 Min)

## Your Tasks

### Step 1: Parallele Validierung (4x Haiku)

Dispatche **4 parallele Haiku-Agenten** fuer umfassende Validierung:

```
Task 1 (general-purpose/haiku) - TEST CHECK:
  "Fuehre ALLE Tests aus:
  ./scripts/sim.sh unit [TestClass]  (Unit Tests)
  ./scripts/sim.sh test [TestClass]  (UI Tests)
  Report: Anzahl passed/failed, Laufzeit, Fehlerdetails."

Task 2 (general-purpose/haiku) - SPEC COMPLIANCE:
  "Lies die Spec: [spec_file_path]
  Pruefe jeden Acceptance Criterion gegen die Implementation.

  ZUSAETZLICH (INFRA_014): Testplan-Coverage-Check:
  python3 .claude/hooks/adversary_dialog.py coverage [spec_file_path] [test-file1] [test-file2...]
  Fehlende Tests = FAIL der Validation.

  Report: Welche Kriterien sind erfuellt, welche nicht?
  Testplan-Coverage: N/M Tests implementiert."

Task 3 (general-purpose/haiku) - REGRESSION CHECK:
  "Fuehre einen Regressions-Check mit MINDEST-SCOPE aus (INFRA_014):

  MINIMUM (PFLICHT):
  1. Volle Unit-Suite: ./scripts/sim.sh unit FocusBloxTests
  2. 3 Haupt-UI-Test-Suiten:
     ./scripts/sim.sh test BacklogViewUITests
     ./scripts/sim.sh test DayViewUITests
     ./scripts/sim.sh test CoachTabLayoutUITests
  3. Alle Tests der direkt betroffenen Module

  OPTIONAL (empfohlen bei grossem Scope):
  4. Volle UI-Test-Suite

  Report: Anzahl Tests ausgefuehrt, passed/failed, Regressionen?"

Task 4 (general-purpose/haiku) - SCOPE CHECK:
  "Vergleiche die geaenderten Dateien mit der Spec.
  Wurden Dateien ausserhalb des Specs geaendert?
  Wurden mehr als 5 Dateien / 250 LoC geaendert?"
```

### Step 2: Ergebnis-Auswertung

Werte die 4 Reports aus:

**Step 2a: Alle Checks bestanden**
-> Weiter zu Step 3

**Step 2b: Fehler gefunden -> Auto-Fix (general-purpose/Sonnet)**

Bei Fehlern dispatche einen **general-purpose/Sonnet Subagenten**:

```
Task (general-purpose/sonnet): "Folgende Validierungsfehler wurden gefunden:
  [Fehler-Liste aus den 4 Haiku-Reports]

  Behebe die Fehler. Beachte:
  - Nur die gemeldeten Fehler fixen, keine anderen Aenderungen
  - Scoping Limits einhalten
  - Tests nach dem Fix erneut ausfuehren"
```

Nach dem Fix: Dispatche die relevanten Haiku-Checks erneut zur Verifikation.

### Step 3: Dokumentation aktualisieren (docs-updater/Sonnet)

Bei erfolgreicher Validierung dispatche den **docs-updater**:

```
Task (general-purpose/sonnet): "Du bist der docs-updater Agent.

  Input:
  - changed_files: [Liste der geaenderten Dateien]
  - feature_summary: [Kurzbeschreibung]
  - spec_file_path: [Pfad zur Spec]

  Aktualisiere alle betroffene Dokumentation."
```

### Step 4: Workflow State aktualisieren

**Only after ALL tests pass:**

```bash
# Register GREEN test artifact
python3 .claude/hooks/workflow.py add-artifact ui_test_output "docs/artifacts/[workflow]/validation-test-output.txt" "ALL TESTS PASSED: [N] unit tests, [M] UI tests green" phase7_validate

# Mark GREEN flags
python3 .claude/hooks/workflow.py mark-green "All [N] unit tests passed"
python3 .claude/hooks/workflow.py mark-ui-green "All [M] UI tests passed"

# Mark REGRESSION CHECK done (PFLICHT — Gate-enforced!)
# Nur setzen wenn Task 3 (Regression Check) tatsaechlich die VOLLE Test-Suite ausfuehrte
python3 .claude/hooks/workflow.py mark-regression-done "Full suite: [N] unit + [M] UI tests, 0 regressions"

# Advance to validation phase
python3 .claude/hooks/workflow.py phase phase7_validate
```

## Validation Report

Erstelle eine Zusammenfassung:

```markdown
## Validation Report: [Workflow Name]

### Test Results
- Unit Tests: [N] passed, [N] failed
- UI Tests: [N] passed, [N] failed
- Full Suite: [N] total, [N] passed

### Spec Compliance
- Acceptance Criteria: [N]/[N] erfuellt
- [Details zu nicht-erfuellten Kriterien]

### Regression Check
- Status: [Keine Regressionen / N Regressionen]

### Scope Check
- Files changed: [N] (Limit: 5)
- LoC changed: +[N]/-[N] (Limit: 250)
- Out-of-scope changes: [Keine / Liste]

### Result: PASS / FAIL
```

## On Test Failure

**If tests fail:**
1. DO NOT say "bitte manuell testen"
2. DO NOT proceed to validation
3. FIX the code
4. Re-run tests
5. Repeat until ALL GREEN

## Docs Update (PFLICHT — Gate-enforced)

**Nach erfolgreicher Validation, VOR phase8_complete:**

1. **GitHub Issue aktualisieren (PFLICHT — Commit-Gate-enforced!):**
   ```bash
   # Issue schliessen oder kommentieren:
   gh issue close <number> --comment "Fixed in <commit-hash>"
   # ODER bei Features/nicht-abgeschlossenen Issues:
   gh issue comment <number> --body "Implemented in <commit-hash>"
   ```

2. **GitHub-Issue-Update markieren (blockiert sonst Commit!):**
   ```bash
   python3 .claude/hooks/workflow.py mark-github-issue-updated "closed #<number> with fix summary"
   ```

3. **`CLAUDE.md`** aktualisieren (nur bei Architektur-Aenderungen)

4. **Docs-Flag setzen** (blockiert sonst phase8_complete):
```bash
python3 .claude/hooks/workflow.py mark-docs-updated "GitHub Issue #<number> closed, docs updated"
```

## Next Step

**Only when ALL tests pass AND docs updated:**

> "Validation successful. All checks passed. Ready for commit."

```bash
# Mark validation as fully complete (PFLICHT — Gate-enforced!)
# Blockiert Commit wenn nicht gesetzt. Setzt regression_check_done voraus.
python3 .claude/hooks/workflow.py mark-validation-done "All 4 checks passed: tests, spec, regression, scope"

python3 .claude/hooks/workflow.py phase phase8_complete
```

## FORBIDDEN

- "Bitte auf Device testen"
- "Bitte manuell pruefen"
- "UI Test fehlgeschlagen, bitte testen"
- Any request for manual testing

**Automated tests ARE the validation. If they fail, FIX THE CODE.**
