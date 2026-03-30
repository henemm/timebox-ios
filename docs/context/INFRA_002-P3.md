# Context: INFRA_002-P3 — QA-Gate für Workflow v3

## Request Summary
`adversary_gate.py` wurde beim v3-Cutover gelöscht, aber `/05-implement` und `implementation-validator.md` referenzieren es noch. Neues `qa_gate.py` erstellen das mit v3-Workflow-System arbeitet (`.claude/workflows/` statt `workflow_state.json`).

## Related Files
| File | Relevanz |
|------|----------|
| `.claude/hooks/bash_gate.py` | Whitelist muss qa_gate.py enthalten |
| `.claude/hooks/workflow.py` | QA-Gate muss Workflow-File lesen/schreiben |
| `.claude/agents/implementation-validator.md` | Referenziert workflow_state_multi + adversary_gate.py |
| `.claude/commands/05-implement.md` | Step 8 referenziert adversary_gate.py |

## Problem
- `adversary_gate.py` (317 LoC) gelöscht beim Cutover
- `implementation-validator.md` importiert `workflow_state_multi` (existiert nicht mehr)
- `/05-implement` verweist auf `adversary_gate.py` (existiert nicht mehr)
- `bash_gate.py` hat `adversary_gate.py` in Whitelist (existiert nicht mehr)

## Scope
- 1 neue Datei: `qa_gate.py` (~100 LoC)
- 3 Dateien ändern: bash_gate.py, implementation-validator.md, 05-implement.md
