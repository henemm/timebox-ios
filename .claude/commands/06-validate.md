# /06-validate — Workflow Abschluss & Execution Log

Kein Gate, kein Blocker — diese Seite dokumentiert, was `workflow.py complete` automatisch tut.

## Was passiert bei `workflow.py complete`?

1. **Execution Log schreiben** — vor der Archivierung wird automatisch eine JSON-Datei erstellt
2. **Workflow archivieren** — der Workflow-State wird nach `.claude/workflows/_archive/` verschoben
3. **Active-Link aufräumen** — `.claude/workflows/.active` wird entfernt

## Wo liegt das Execution Log?

```
.claude/workflows/_logs/<workflow-name>-<YYYYMMDD-HHMMSS>.json
```

Das Verzeichnis `_logs/` wird automatisch angelegt wenn es noch nicht existiert.

## Inhalt des Execution Logs

```json
{
  "workflow": "<name>",
  "workflow_type": "bug|feature",
  "outcome": "success",
  "phases_completed": ["phase1_context", "phase2_analyse", ...],
  "tdd_red_confirmed": true,
  "adversary_verdict": "VERIFIED",
  "adversary_run_count": 1,
  "fix_loop_count": 0,
  "scope_loc_delta": 90,
  "completed_at": "<iso-timestamp>"
}
```

- `phases_completed` — alle Phasen die durchlaufen wurden (aus dem Audit Trail)
- `fix_loop_count` — Anzahl der BROKEN → phase5_implement-Iterationen
- `scope_loc_delta` — Summe aller geänderten Zeilen zum Zeitpunkt des Abschlusses

## Fix-Loop-Count im Status

`workflow.py status` zeigt den aktuellen Fix-Loop-Count an:

```
Fix-Loop-Count: 1
```

Dieser Zähler steigt nur wenn der Adversary `BROKEN` vermeldet und danach erneut in `phase5_implement` gegangen wird.
