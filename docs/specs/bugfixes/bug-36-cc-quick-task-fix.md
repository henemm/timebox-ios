# Bug 36: CC Quick Task Button funktionslos

## Problem
Control Center "Quick Task" Button tut nichts - kein Dialog, keine App-Öffnung.

## Root Cause Kandidaten
1. **Target Membership** - Intent nur im Widget-Target, nicht im App-Target
2. **OpenURLIntent** - Custom URL Schemes offiziell nicht unterstützt
3. **openAppWhenRun** - Funktioniert möglicherweise nicht im CC-Kontext

## Diagnose-Ansatz
4 CC-Buttons mit unterschiedlichen Mechanismen, jeweils eigenes Symbol:

| Button | Symbol | Mechanismus |
|--------|--------|-------------|
| Test A | `star.fill` | Nur `openAppWhenRun = true`, kein perform-Code → testet ob App überhaupt öffnet |
| Test B | `flame.fill` | App Group Flag + `openAppWhenRun` → flag-basierter Trigger |
| Test C | `link` | `OpenURLIntent` + `openAppWhenRun` → aktueller Ansatz |
| Test D | `bolt.fill` | App Group Flag OHNE `openAppWhenRun` → testet ob Intent überhaupt läuft |

## Erwartete Erkenntnisse
- Wenn A funktioniert aber B/C nicht → Problem in perform()
- Wenn A nicht funktioniert → fundamentales ControlWidget/Target-Problem
- Wenn D Flag setzt aber App nicht öffnet → openAppWhenRun kaputt
- Wenn B funktioniert → App Group Flag ist der Fix

## Betroffene Dateien
- `FocusBloxWidgets/QuickAddTaskControl.swift` (4 Intents + 4 Controls)
- `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` (4 Controls registrieren)

## Scope
- 2 Dateien, ~80 LoC
- Rein diagnostisch - nach Test wird auf den funktionierenden Ansatz reduziert
