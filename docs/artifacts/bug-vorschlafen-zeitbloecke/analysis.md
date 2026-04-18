# Bug-Analyse: Sinnloses Vorschlafen von Zeitblöcken (#252)

## Root Cause

`GapFinder.swift:126` — OR-Bedingung `gaps.isEmpty || isWholeDayFree(...)`:
Sobald der Tag < 120 Min Busy-Time hat, werden echte berechnete Gaps verworfen
und durch starre Default-Stunden [9, 11, 14, 16] ersetzt.

## Zusätzliches Problem

`isWholeDayFree()` zählt VERGANGENE Events mit. Ein Morgen-Meeting (1h) das
schon vorbei ist, lässt den Tag immer noch als "frei" gelten → Default-Slots.

## Scoring-Schwäche

Ohne Verhaltensprofil (`categoryTimeAffinity` / `aiEnergyLevel`) haben alle
Slots die gleiche Gewichtung — keine Tageszeit-Sensitivität.

## Blast Radius

- CoachView, DayView, BlockPlanningView, SmartNotificationEngine
- macOS MacPlanningView (identischer Code)
- OrganizeMyDayIntent (Siri/Shortcuts)
- Fix in GapFinder.swift wirkt automatisch auf alle Aufrufer

## Fix-Strategie

1. `isWholeDayFree` soll nur ZUKÜNFTIGE Busy-Time zählen
2. Default-Slots NUR bei komplett leerem Kalender (0 Events), nicht bei < 120 min
3. Echte Gaps immer bevorzugen wenn vorhanden
