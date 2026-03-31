# INFRA_010: Session-Cleanup bei Crash

## Problem
Wenn eine Claude-Session abstürzt, bleibt ihr Eintrag in `.sessions.json` stehen.
Über Zeit sammeln sich tote Einträge an, die `workflow.py list` verunreinigen.

## Lösung
Neue Funktion `_prune_orphaned_sessions()` in `workflow.py`:
- Prüft jeden Eintrag in `.sessions.json`
- Entfernt Einträge, deren referenziertes Workflow-JSON **nicht mehr existiert**
- Nutzt `_locked_sessions()` für Thread-Safety

### Orphan-Erkennung (sicher)
Ein Eintrag ist verwaist wenn: `_workflow_file(workflow_name).exists() == False`

Das bedeutet: Der Workflow wurde bereits archiviert (`cmd_complete`) oder manuell gelöscht,
aber die Session-Zuordnung blieb stehen (Crash, manueller Abbruch).

### Aufruforte
1. **`cmd_list()`** — vor dem Auflisten der Workflows
2. **`session_start.py`** — beim Start einer neuen Session

### Was NICHT gemacht wird
- Keine Prozess-Erkennung (unzuverlässig, plattformabhängig)
- Keine Zeitstempel-basierte Erkennung (würde Datenformat ändern)
- Keine Bestätigungs-Dialoge (unsichtbares Aufräumen)

## Betroffene Dateien
1. `.claude/hooks/workflow.py` — `_prune_orphaned_sessions()` + Aufruf in `cmd_list()`
2. `.claude/hooks/session_start.py` — Aufruf nach Session-ID-Export

## Scope
~30 LoC, 2 Dateien, Size S
