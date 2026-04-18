---
entity_id: slot-suggestions-redesign
type: bug-fix
created: 2026-04-18
updated: 2026-04-18
status: draft
version: "2.0"
tags: [coach-view, gap-finder, suggestions, morning]
---

# Slot-Vorschläge → Zeitbudget-Anzeige (Bug #252)

## Approval

- [ ] Approved

## Purpose

Die Slot-Karten im Coach Morning View (Uhrzeiten + Task-Toggles + "Block erstellen")
wirken willkürlich. Feste Zeitblöcke mit algorithmisch zugeordneten Tasks bringen
keinen echten Mehrwert — der User soll selbst entscheiden WANN er WAS tut.

**Neues Konzept:** Statt Slot-Karten zeigt der Morning View nur noch:
- **Zeitbudget:** "Du hast heute X Min frei" (Kalender-Kontext)
- **Task-Vorschläge:** bleiben wie bisher (unabhängig von Slots)

## Was entfernt wird

1. `morningSlotSection` — die gesamte Slot-Karten-UI (Zeile 365-460 in CoachView)
2. `slotCard()` — einzelne Slot-Karte mit Task-Toggles und "Block erstellen"
3. `createBlockForSlot()` — erstellt Kalender-Event aus Slot
4. `slotCandidates` State — Task-Kandidaten pro Slot
5. `selectedTasksPerSlot` State — User-Selektion in Slot-Karten
6. `candidatesPerSlot()` Aufruf in `loadAllData()`
7. `GapFinder.createDefaultSuggestions()` — starre Default-Uhrzeiten
8. `GapFinder.isWholeDayFree()` — Bypass-Logik
9. `GapFinder.defaultSuggestionHours` — [9, 11, 14, 16]

## Was hinzukommt

Eine einfache **Zeitbudget-Anzeige** im Morning Content:

```
☀️ Dein Tag: X Min frei
```

Berechnung: Summe aller freien Minuten aus `GapFinder.findFreeSlots()`.
Wird nur angezeigt wenn > 0 Min frei.

## Was bleibt

- `morningTopTasks` / Task-Vorschläge ("Vorschläge für heute") — unverändert
- `GapFinder.findFreeSlots()` Core-Logik — weiterhin für Zeitbudget-Berechnung
- `NextUpSuggestionService.suggestions()` — weiterhin für Task-Vorschläge
- `addToToday()` — User kann Tasks weiterhin für heute einplanen
- `freeSlots` State — weiterhin berechnet, nur noch für Zeitbudget

## Source

- **Files:** `Sources/Views/CoachView.swift`, `Sources/Models/GapFinder.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `GapFinder` | model | Berechnet freie Minuten (vereinfacht) |
| `CoachView` | view | Morning Content: Slot-Karten → Zeitbudget |

## Implementation Details

### CoachView.swift

1. `morningSlotSection`, `slotCard()`, `createBlockForSlot()` entfernen
2. `slotCandidates`, `selectedTasksPerSlot` State entfernen
3. `candidatesPerSlot()` Aufruf in `loadAllData()` entfernen
4. Neue `timebudgetView`: Zeigt "Dein Tag: X Min frei" basierend auf `freeSlots`
5. In `morningContent`: `morningSlotSection` ersetzen durch `timebudgetView`

### GapFinder.swift

1. `createDefaultSuggestions()` entfernen
2. `isWholeDayFree()` entfernen
3. `defaultSuggestionHours` entfernen
4. Zeile 126: `if gaps.isEmpty || isWholeDayFree(...)` → `return gaps` (direkt zurückgeben)
5. Core-Logik (echte Gaps finden) bleibt für Zeitbudget-Berechnung

## Expected Behavior

- **Leerer Kalender:** "Dein Tag: 960 Min frei" (06:00-22:00) + Task-Vorschläge
- **Normaler Tag:** "Dein Tag: 180 Min frei" + Task-Vorschläge
- **Voller Kalender:** "Dein Tag: 30 Min frei" oder gar keine Anzeige + Task-Vorschläge
- **Keine Slot-Karten mehr** — kein "Block erstellen", keine Task-Toggles in Slots

## Known Limitations

- "Block erstellen" aus Slot fällt weg — User kann Blöcke weiterhin über die Planen-View erstellen
- DayView und BlockPlanningView nutzen GapFinder weiterhin für ihre Slot-Anzeige — dort keine Änderung

## Changelog

- 2026-04-18 v1: Initial spec mit Slot-Redesign
- 2026-04-18 v2: Grundsätzlicher Richtungswechsel — Slot-Karten entfernen, Zeitbudget-Anzeige statt dessen
