# Bug Fix: Tasks springen bei Wichtigkeit/Dringlichkeit-Änderung

## Problem
In der BacklogView (iOS, Priority-Modus) springt ein Task sofort an eine andere Position, wenn Wichtigkeit oder Dringlichkeit geändert wird. Die "Deferred Sort" Mechanik (3-Sekunden-Verzögerung) verhindert dies nicht.

## Root Cause
`updateImportance()` (Zeile 522) und `updateUrgency()` (Zeile 540) ersetzen den PlanItem sofort mit einem neuen, der einen anderen `priorityScore` hat. Die Priority-View sortiert bei jedem Render nach `priorityScore` (Zeile 872). `pendingResortIDs` wird nur für den visuellen Rand verwendet, hat keinen Einfluss auf die Sortierung.

## Fix-Ansatz
macOS hat bereits einen funktionierenden `displaySnapshot`-Mechanismus. Diesen auf iOS portieren:

1. `@State private var sortSnapshot: [String]?` — speichert die aktuelle Reihenfolge der PlanItem-IDs
2. Bei Badge-Tap: `sortSnapshot = backlogTasks.map(\.id)` vor dem PlanItem-Update
3. In der Priority-View: Wenn `sortSnapshot != nil`, nach Snapshot-Reihenfolge sortieren statt nach `priorityScore`
4. Nach 3s: `sortSnapshot = nil` → Live-Sortierung greift wieder

## Betroffene Dateien
- `Sources/Views/BacklogView.swift` — Snapshot-Mechanismus einbauen

## Acceptance Criteria
- [ ] Task bleibt an Ort und Stelle beim Ändern von Wichtigkeit
- [ ] Task bleibt an Ort und Stelle beim Ändern von Dringlichkeit
- [ ] Badge-Farbe aktualisiert sich sofort (visuelles Feedback)
- [ ] Nach 3 Sekunden sortiert sich die Liste neu (mit Animation)
- [ ] Orangener pulsierender Rand während Wartezeit sichtbar
