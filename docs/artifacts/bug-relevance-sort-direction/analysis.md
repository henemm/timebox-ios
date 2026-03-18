# BUG_109: Backlog sortiert Relevanz aufsteigend statt absteigend

## Symptom

Backlog-Liste zeigt Tasks mit niedrigster Relevanz oben, hoechste unten.
Screenshot zeigt Reihenfolge: 18, 43, 40, 71, 75 (aufsteigend).
Erwartet: 75, 71, 43, 40, 18 (absteigend — wichtigste oben).

## Plattform

iOS (Backlog Tab). macOS moeglicherweise auch betroffen (gleiche Sortier-Patterns).

## Root Cause (Hypothese)

Sortierrichtung in der Backlog-View ist invertiert. Die Relevanz-Berechnung selbst ist korrekt.

## Verdaechtige Code-Stellen

- `Sources/Views/BacklogView.swift` — Tier-basierte Sortierung + Tier-Reihenfolge
- `Sources/Views/CoachBacklogView.swift` — Coach-Variante
- `FocusBloxMac/ContentView.swift` — macOS-Variante

## Fix-Plan

1. **Mock-Tests bauen** die das Szenario aus dem Screenshot nachbilden (PFLICHT, erster Schritt)
2. **Sortierrichtung fixen** in der betroffenen View
