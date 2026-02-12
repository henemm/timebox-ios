# Ticket C: Planungsgenauigkeit (neues Feature)

## Problem

Nutzer will wissen:
- Wie oft musste ich Tasks umplanen (Reschedule-Count)?
- War ich schneller oder langsamer als geplant?
- Vergleich geplante vs tatsaechliche Dauer

## Scope

- Datenmodell: Reschedule-Count tracken (wie oft verschoben)
- Geplante vs tatsaechliche Dauer erfassen
- Stats berechnen: Durchschnittliche Abweichung, Reschedule-Rate
- Anzeige auf beiden Plattformen (iOS + macOS)
- ~5 Dateien, ~250 LoC

## Betroffene Dateien

- `Sources/Models/LocalTask.swift` (neue Properties: rescheduleCount, actualDuration)
- `Sources/Models/ReviewStatsCalculator.swift` (Planungsgenauigkeit berechnen)
- `Sources/Views/DailyReviewView.swift` (Anzeige)
- `FocusBloxMac/MacReviewView.swift` (Anzeige)
- Migration/Schema Update

## Prioritaet

Niedrig - Neues Feature, benoetigt Datenmodell-Aenderung

## Status

Backlog
