# Kategorie-Schnellzugriff in CoachBacklogView

## Problem
Wenn ein Task in CoachBacklogView in der falschen Sektion landet, muss man den vollen Edit-Sheet oeffnen um die Kategorie zu aendern.

## Loesung
Context Menu mit "Kategorie"-Submenu auf coachRow() fuer schnellen Kategoriewechsel.

## Aenderungen
- `Sources/Views/CoachBacklogView.swift`: `.contextMenu` Modifier auf `coachRow()` mit allen `TaskCategory.allCases`
- Persistierung via `syncEngine.updateTask()` (bestehendes Pattern)

## Test Plan
- UI Test: Long-Press auf Task → "Kategorie" → Kategorie waehlen → Task wechselt Sektion
