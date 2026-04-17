# Bug-Analyse: Checkpoint-Feedback (#272)

## Problem
Wenn Henning "commit" sagt aber Screenshot fehlt, passiert nichts. Keine Fehlermeldung, kein Hinweis.

## Root Cause
phase_listener.py schreibt Feedback auf stderr (exit 0). Claude sieht stderr bei exit 0 NICHT.

## Lösung
stdout statt stderr verwenden. Bei exit 0 wird stdout als zusätzlicher Kontext an Claude übergeben. Claude sieht dann z.B. "Checkpoint 3 nicht gesetzt: Screenshot fehlt" und kann Henning erklären was zu tun ist.

## Betroffene Stellen
1. phase_listener.py: Alle print(..., file=sys.stderr) die Feedback über NICHT-gesetzte Checkpoints geben → auf stdout umstellen
2. Betrifft: Screenshot-Gate, Adversary-Findings-Gate, und fehlende Workflow-Zustände

## Nicht betroffen
- Stop-Lock Meldungen (informativ, kein Problem)
- Checkpoint-Erfolgs-Meldungen (funktionieren bereits über workflow.py stdout)
