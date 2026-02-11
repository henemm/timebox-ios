# Bug 14: Focus Block Zeiteinstellung zeigt "25 Std" statt Minuten

## Problem

DatePicker mit `.hourAndMinute` speichert ein vollständiges `Date`. Wenn die Endzeit über Mitternacht gescrollt wird (z.B. Start 23:00, Ende 00:25), setzt iOS das Datum auf den nächsten Tag. `endTime.timeIntervalSince(startTime)` ergibt dann 25+ Stunden statt 25 Minuten.

## Root Cause

Kein Same-Day-Constraint auf den DatePickern. Die `durationText`-Berechnung ist korrekt, aber die Eingabe-Daten sind falsch.

## Betroffene Dateien

1. `Sources/Views/EditFocusBlockSheet.swift` - iOS Edit Sheet
2. `Sources/Views/BlockPlanningView.swift` - iOS Create Sheet (CreateFocusBlockSheet)
3. `FocusBloxMac/MacPlanningView.swift` - macOS Create Sheet

## Fix

`endTime` bei jeder Änderung auf denselben Kalendertag wie `startTime` normalisieren via `onChange(of: endTime)`. Nur Stunde und Minute von endTime übernehmen, Datum von startTime beibehalten.

## Scope

- 3 Dateien, ~5-10 LoC pro Datei
- Keine neuen Dependencies
- Keine Architektur-Änderung
