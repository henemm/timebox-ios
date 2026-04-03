# INFRA_013 — Test-Definitionen

## Unit Tests (Python)

### adversary_dialog.py

| # | Test | Prueft | Erwartung |
|---|------|--------|-----------|
| 1 | `test_parse_spec_extracts_expected_behavior` | Spec-Parser findet Expected-Behavior-Bullets | Liste mit >= 1 Punkt |
| 2 | `test_parse_spec_empty_section` | Spec ohne Expected-Behavior | Leere Liste + Warnung |
| 3 | `test_checklist_creation` | Jeder Bullet wird zu offenem Item | Alle Items `status=open` |
| 4 | `test_dialog_artifact_format` | Artifact-Markdown ist valide | Enthaelt Header, Checkliste, Runden, Verdict |
| 5 | `test_dialog_minimum_rounds` | Dialog mit nur 1 Runde | Warnung: min. 2 Runden erwartet |

### qa_gate.py (Erweiterung)

| # | Test | Prueft | Erwartung |
|---|------|--------|-----------|
| 6 | `test_checklist_all_checked_passes` | Alle [x] Punkte | VERIFIED |
| 7 | `test_checklist_open_points_fails` | Mind. 1 [ ] Punkt | FAILED + offene Punkte |
| 8 | `test_checklist_too_few_rounds_fails` | < 2 Runden | FAILED + "min. 2 Runden" |
| 9 | `test_checklist_file_missing_fails` | Artifact existiert nicht | FAILED + "not found" |
| 10 | `test_checklist_file_too_old_fails` | Artifact > 60 Min alt | FAILED + "too old" |

## Integrations-Test (manuell via Workflow)

| # | Szenario | Erwartung |
|---|----------|-----------|
| I1 | Normaler Feature-Workflow mit Dialog | Dialog-Artifact vorhanden, VERIFIED |
| I2 | Feature mit Defekt | Dialog-Artifact zeigt BROKEN, Commit blockiert |
| I3 | Infra-Ticket ohne UI | `--no-visual` + Checkliste funktioniert |
