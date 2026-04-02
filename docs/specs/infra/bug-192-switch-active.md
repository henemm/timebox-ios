# Spec: Bug #192 — workflow.py switch aktualisiert .active nicht

## Problem
`_set_active()` überspringt .active-Symlink-Update wenn CLAUDE_SESSION_ID gesetzt ist (Zeile 247).

## Fix
Entferne `if not session_id:` Bedingung — .active wird IMMER aktualisiert.

## Akzeptanzkriterien
1. Nach `workflow.py switch X` zeigt `.active` Symlink auf `X.json`
2. `.sessions.json` wird weiterhin korrekt aktualisiert wenn session_id vorhanden
3. Ohne session_id funktioniert .active wie bisher
