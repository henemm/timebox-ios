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
python3 .claude/hooks/workflow_state_multi.py status
```

Required:
- `current_phase`: `phase6_implement` or later
- `ui_test_red_done`: `true`
- `ui_test_red_result`: contains "failed"

## Your Tasks

### Step 1: Parallele Validierung (4x Haiku)

Dispatche **4 parallele Haiku-Agenten** fuer umfassende Validierung:

```
Task 1 (general-purpose/haiku) - TEST CHECK:
  "Fuehre ALLE Tests aus:
  xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
    -destination 'id=548B4A2F-FDFF-4F9E-8335-1A7A7B98E492'
  Report: Anzahl passed/failed, Laufzeit, Fehlerdetails."

Task 2 (general-purpose/haiku) - SPEC COMPLIANCE:
  "Lies die Spec: [spec_file_path]
  Pruefe jeden Acceptance Criterion gegen die Implementation.
  Report: Welche Kriterien sind erfuellt, welche nicht?"

Task 3 (general-purpose/haiku) - REGRESSION CHECK:
  "Fuehre die vollstaendige Test-Suite aus (nicht nur Feature-Tests).
  Report: Gibt es Regressionen? Welche Tests die vorher gruen waren
  sind jetzt rot?"

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
python3 -c "
import sys; sys.path.insert(0, '.claude/hooks')
from workflow_state_multi import load_state, save_state, add_test_artifact

state = load_state()
active = state['active_workflow']

# Add GREEN test artifact
add_test_artifact(active, {
    'type': 'ui_test_output',
    'path': 'docs/artifacts/[workflow]/validation-test-output.txt',
    'description': 'ALL TESTS PASSED: [N] unit tests, [M] UI tests green',
    'phase': 'phase7_validate'
})

# Update flags
state['workflows'][active]['ui_test_green_done'] = True
state['workflows'][active]['ui_test_green_result'] = 'All [N] tests passed'
state['workflows'][active]['current_phase'] = 'phase7_validate'
save_state(state)
"

python3 .claude/hooks/workflow_state_multi.py phase phase7_validate
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

## Next Step

**Only when ALL tests pass:**

> "Validation successful. All checks passed. Ready for commit."

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase8_complete
```

## FORBIDDEN

- "Bitte auf Device testen"
- "Bitte manuell pruefen"
- "UI Test fehlgeschlagen, bitte testen"
- Any request for manual testing

**Automated tests ARE the validation. If they fail, FIX THE CODE.**
