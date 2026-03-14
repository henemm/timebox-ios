# Bug 99: CoachBacklogView — Next-Up-Swipe fehlt

## Problem

Die CoachBacklogView hat keine Swipe-nach-rechts-Geste zum Hinzufügen/Entfernen von "Next Up". Die normale BacklogView bietet das — im Coach-Modus fehlt es komplett.

Kritisch: Die Intention "fokus" matcht auf `task.isNextUp`. Ohne Next-Up-Swipe ist diese Intention im Coach-Modus unbenutzbar.

## Root Cause

`coachRow()` in CoachBacklogView.swift hat nur `.swipeActions(edge: .trailing)` (Löschen + Bearbeiten), aber kein `.swipeActions(edge: .leading)` für Next-Up.

## Fix

1. `updateNextUp(for:isNextUp:)` Funktion in CoachBacklogView ergänzen (analog BacklogView)
2. `.swipeActions(edge: .leading)` in `coachRow()` hinzufügen:
   - Nicht-Next-Up Tasks: "Next Up" Button (grün)
   - Next-Up Tasks: "Entfernen" Button (orange)

## Affected Files

| File | Change |
|------|--------|
| Sources/Views/CoachBacklogView.swift | MODIFY: swipe action + updateNextUp function |

## Acceptance Criteria

- [ ] Swipe-nach-rechts auf Task zeigt "Next Up" (grün) wenn Task nicht Next-Up ist
- [ ] Swipe-nach-rechts auf Next-Up-Task zeigt "Entfernen" (orange)
- [ ] Nach Swipe wird `isNextUp` korrekt persistiert (SyncEngine.updateNextUp)
- [ ] Task-Liste wird nach Änderung aktualisiert

## Test Plan

- UI Test: Swipe-Geste auf Task im Coach-Modus prüfen (Element-Existenz)
- Unit Test: Nicht nötig (Business-Logik bereits in SyncEngine getestet)

## Scope

- 1 Datei, ~15 LoC
