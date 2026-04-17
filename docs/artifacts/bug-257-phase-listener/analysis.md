# Bug-Analyse: phase_listener setzt Checkpoints nicht (#257)

## User-Erwartung
Henning tippt "go" und erwartet sofortige Bestätigung dass die Freigabe registriert wurde. Stattdessen: Stille. Kein Feedback, kein Fortschritt. Er muss raten ob es geklappt hat.

## Root Cause

**Die Session-ID wird nicht an den subprocess weitergegeben.**

In `_call_workflow_checkpoint()` (Zeile 154-169) wird `env = os.environ.copy()` verwendet. Das Problem: `CLAUDE_SESSION_ID` steht im UserPromptSubmit-Kontext oft NICHT in `os.environ` — sie kommt nur über das stdin-JSON (`hook_input.get("session_id")`). 

Der subprocess `workflow.py mark-checkpoint2` erbt die Umgebung OHNE Session-ID → `workflow.py` kann den Workflow nicht per Session finden → fällt auf `.active` Symlink zurück → der existiert möglicherweise nicht → `sys.exit(1)` → Checkpoint wird nie gesetzt.

**Beweis:** `spec_approved` (Zeile 262-264) wird DIREKT auf `wf_data` geschrieben (kein subprocess) und funktioniert IMMER. Alle 3 Checkpoints + Finding-Resolution gehen durch subprocess und scheitern intermittierend.

## Betroffene Stellen

1. `_call_workflow_checkpoint()` Zeile 157: `env = os.environ.copy()` — Session-ID fehlt
2. `_resolve_next_finding()` Zeile 135: Gleiches Pattern, gleiches Problem

## Fix

Session-ID explizit ins Environment des subprocess einfügen:

```python
def _call_workflow_checkpoint(checkpoint_num, notes, session_id=""):
    env = os.environ.copy()
    env["WORKFLOW_CALLER"] = "phase_listener"
    if session_id:
        env["CLAUDE_SESSION_ID"] = session_id
    # ... subprocess.run(...)
```

Und in main() die session_id an beide Funktionen durchreichen.

## Blast Radius

| Funktion | Mechanismus | Betroffen? |
|----------|-------------|-----------|
| Checkpoint 1-3 | subprocess | JA |
| Finding-Resolution | subprocess | JA |
| spec_approved | direkt auf dict | NEIN |
| Stop-lock | eigene Datei | NEIN |
| post_bash add-artifact | subprocess | MÖGLICH (unkritisch) |

## Zusätzliche Findings

1. Kein Feedback wenn Checkpoint scheitert — Henning sieht nur Stille
2. "weiter" ist gleichzeitig in CHECKPOINT1, CHECKPOINT2, CHECKPOINT3 und CONTINUE_PHRASES — kann unbeabsichtigte Checkpoints setzen
