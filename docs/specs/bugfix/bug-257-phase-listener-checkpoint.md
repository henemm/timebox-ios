---
entity_id: bug-257-phase-listener-checkpoint
type: bugfix
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [hooks, phase-listener, checkpoint]
---

# Bug #257 — phase_listener setzt Checkpoints nicht

## Approval

- [ ] Approved

## Problem

`_call_workflow_checkpoint()` und `_resolve_next_finding()` in `phase_listener.py` rufen `workflow.py` per subprocess auf, aber die Session-ID aus dem Hook-Input wird nicht ins subprocess-Environment übergeben. `workflow.py` findet den Workflow nicht und scheitert leise.

## Root Cause

`phase_listener.py` Zeile 157: `env = os.environ.copy()` kopiert nur die Prozess-Umgebung. Die Session-ID kommt aber oft nur über stdin-JSON (`hook_input.get("session_id")`) — nicht über `os.environ["CLAUDE_SESSION_ID"]`.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `.claude/hooks/phase_listener.py` | Session-ID an subprocess durchreichen + "weiter" Keyword-Konflikt lösen |

## Fix

### 1. Session-ID an subprocess-Aufrufe durchreichen

Beide Funktionen (`_call_workflow_checkpoint` und `_resolve_next_finding`) erhalten `session_id` als Parameter und setzen es ins Environment:

```python
def _call_workflow_checkpoint(checkpoint_num: int, notes: str, session_id: str = "") -> None:
    env = os.environ.copy()
    env["WORKFLOW_CALLER"] = "phase_listener"
    if session_id:
        env["CLAUDE_SESSION_ID"] = session_id
    # ... rest bleibt gleich
```

```python
def _resolve_next_finding(wf_data, wf_path, status, session_id=""):
    # ... gleicher Fix
```

In `main()`: `session_id` an alle Aufrufe durchreichen.

### 2. "weiter" aus Checkpoint-Phrases entfernen

"weiter" steht in CHECKPOINT1_PHRASES, CHECKPOINT2_PHRASES, CHECKPOINT3_PHRASES und CONTINUE_PHRASES — das ist mehrdeutig. Entfernen aus den Checkpoint-Listen, nur in CONTINUE_PHRASES belassen.

## Test Plan

1. **test_session_id_passed_to_subprocess**: _call_workflow_checkpoint mit session_id aufrufen → env enthält CLAUDE_SESSION_ID
2. **test_session_id_passed_to_resolve_finding**: _resolve_next_finding mit session_id → env enthält CLAUDE_SESSION_ID
3. **test_weiter_not_in_checkpoint_phrases**: "weiter" darf nicht in CHECKPOINT1/2/3_PHRASES sein
4. **test_weiter_still_in_continue_phrases**: "weiter" muss in CONTINUE_PHRASES bleiben

## Known Limitations

- UserPromptSubmit Hooks geben kein sichtbares Feedback an den User (nur stderr). Wenn ein Checkpoint scheitert, sieht Henning nur Stille. Das ist ein grundlegendes Hook-Design-Problem, kein phase_listener-Problem.
