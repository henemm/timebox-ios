# INFRA_015: Validation Gate Hardening

## Problem

User-Feedback zeigt 5 Stellen wo Claude Validierungsschritte ueberspringt:

1. **Spec Compliance Check** (Task 2 in /06-validate) wird nicht dispatched
2. **Regression Check** unvollstaendig — 3 Pflicht-UI-Suiten fehlen
3. **Spec-Phase verkuerzt** — Spec-Validator-Agent wird uebersprungen
4. **docs-updater Agent** nicht dispatched (manuell statt Agent)
5. **Coverage-Check** (`adversary_dialog.py coverage`) nie ausgefuehrt

## Root Cause

Die Schritte sind in den Skill-Dateien beschrieben, aber die Gates in `workflow.py` erzwingen sie nicht:

- `mark-validation-done` prueft nur: `green_test_done`, `regression_check_done`, `docs_updated`
- `mark-regression-done` akzeptiert beliebigen Text ohne Nachweis
- Kein `spec_validated` Flag existiert
- Kein `spec_compliance_done` oder `coverage_check_done` Flag existiert

## Betroffene Dateien

- `.claude/hooks/workflow.py` — Gate-Logik + neue mark-Commands
- `.claude/commands/06-validate.md` — Skill-Anweisung aktualisieren
- `.claude/commands/03-write-spec.md` — Spec-Validator als Pflicht markieren
