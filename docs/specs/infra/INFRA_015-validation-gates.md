---
entity_id: INFRA_015-validation-gates
type: module
created: 2026-04-13
updated: 2026-04-13
status: draft
version: "1.0"
tags: [workflow, gates, validation, infra]
---

# INFRA_015: Validation Gate Hardening

## Approval

- [ ] Approved

## Purpose

Haertet 3 Gate-Luecken in `workflow.py`, die es Claude ermoeglichen Validierungsschritte zu ueberspringen. Nach dieser Aenderung sind Spec-Validierung, Spec-Compliance-Check, Coverage-Check und Regression-Check technisch erzwungen — nicht nur per Skill-Anweisung.

## Source

- **File:** `.claude/hooks/workflow.py`
- **Identifier:** `_validate_transition()`, `cmd_mark_validation_done()`, `cmd_mark_regression_done()`, neue Commands

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| workflow.py | module | Gate-Logik, Phase-Transitions, mark-Commands |
| 06-validate.md | skill | Validation-Phase Anweisungen |
| 03-write-spec.md | skill | Spec-Phase Anweisungen |
| adversary_dialog.py | tool | coverage-Check Funktion |

## Acceptance Criteria

### AC1: spec_validated Gate
- Neues Flag `spec_validated` in workflow state
- Neuer Command `mark-spec-validated` mit Pflicht-Evidence (min 30 Zeichen)
- `_validate_transition` blockiert `phase4_approved` wenn `spec_validated != true`
- Flag ist protected (nicht via set-field setzbar)

### AC2: spec_compliance_done + coverage_check_done Gates
- Zwei neue Flags im workflow state
- Neuer Command `mark-spec-compliance` mit Pflicht-Evidence (min 30 Zeichen)
- Neuer Command `mark-coverage-check` mit Pflicht-Evidence (min 30 Zeichen)
- `cmd_mark_validation_done` blockiert wenn eines der beiden Flags fehlt
- Beide Flags sind protected

### AC3: mark-regression-done Keyword-Validierung
- Evidence-String muss alle 4 Pflicht-Keywords enthalten:
  - `FocusBloxTests`
  - `BacklogViewUITests`
  - `DayViewUITests`
  - `CoachTabLayoutUITests`
- Ohne alle 4 Keywords: BLOCKED mit klarer Fehlermeldung
- Ueberspringbar nur mit Override-Token

### AC4: Status-Output erweitert
- `cmd_status` zeigt die neuen Flags an:
  - `spec_validated`
  - `spec_compliance_done`
  - `coverage_check_done`

### AC5: Skill-Dateien aktualisiert
- `03-write-spec.md`: Schritt 3 (Spec-Validator) muss `mark-spec-validated` aufrufen
- `06-validate.md`: Task 2 muss `mark-spec-compliance` und `mark-coverage-check` aufrufen

## Expected Behavior

- Wenn Claude versucht ohne Spec-Validierung zur Approval-Phase zu wechseln: BLOCKED
- Wenn Claude versucht ohne Compliance/Coverage-Check die Validation abzuschliessen: BLOCKED
- Wenn Claude `mark-regression-done` ohne vollstaendige Suite-Namen aufruft: BLOCKED
- Alle neuen Flags erscheinen in `workflow.py status` Output

## Implementation Details

### Aenderung 1: Neue mark-Commands (workflow.py)

```python
def cmd_mark_spec_validated(args):
    # Wie mark-visual-inspection: min 30 Zeichen Evidence
    # Setzt spec_validated = True

def cmd_mark_spec_compliance(args):
    # min 30 Zeichen Evidence
    # Setzt spec_compliance_done = True

def cmd_mark_coverage_check(args):
    # min 30 Zeichen Evidence
    # Setzt coverage_check_done = True
```

### Aenderung 2: Gate in _validate_transition (workflow.py)

```python
# Vor phase4_approved:
if not data.get("spec_validated"):
    return "spec_validated not set — run spec-validator and mark-spec-validated"
```

### Aenderung 3: Prerequisites in mark-validation-done (workflow.py)

```python
if not data.get("spec_compliance_done"):
    missing.append("spec_compliance_done (run mark-spec-compliance)")
if not data.get("coverage_check_done"):
    missing.append("coverage_check_done (run mark-coverage-check)")
```

### Aenderung 4: Keyword-Validierung in mark-regression-done (workflow.py)

```python
REQUIRED_REGRESSION_SUITES = [
    "FocusBloxTests", "BacklogViewUITests",
    "DayViewUITests", "CoachTabLayoutUITests"
]
for suite in REQUIRED_REGRESSION_SUITES:
    if suite not in result:
        # BLOCKED
```

## Known Limitations

- Keyword-Validierung in `mark-regression-done` prueft nur ob die Suite-Namen im Text vorkommen, nicht ob sie tatsaechlich ausgefuehrt wurden. Die Ausfuehrung wird durch die Skill-Anweisung sichergestellt.
- Override-Token kann alle Gates umgehen (by design fuer Notfaelle).

## Test Plan

- Unit Test: `mark-spec-validated` mit zu kurzem Text → BLOCKED
- Unit Test: `mark-spec-validated` mit gueltigem Text → OK
- Unit Test: Phase-Transition zu `phase4_approved` ohne `spec_validated` → BLOCKED
- Unit Test: `mark-regression-done` ohne Keywords → BLOCKED
- Unit Test: `mark-regression-done` mit allen Keywords → OK
- Unit Test: `mark-validation-done` ohne `spec_compliance_done` → BLOCKED
- Unit Test: `mark-validation-done` ohne `coverage_check_done` → BLOCKED
- Unit Test: `mark-validation-done` mit allen Flags → OK

## Changelog

- 2026-04-13: Initial spec created
