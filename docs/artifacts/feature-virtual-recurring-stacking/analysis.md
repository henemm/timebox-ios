# Feature: Virtuelles Stacking — Analyse

## User-Erwartung (User Advocate)

- User sieht "Waesche waschen x3" und versteht: "3 Wochen liegen gelassen"
- Abhaken → Badge sinkt von x3 auf x2 → klares Feedback
- Hauptverwirrung: Aufgabe taucht sofort wieder auf nach dem Abhaken
- Zweitverwirrung: Was bedeutet "x3" genau? Braucht beim ersten Mal Erklaerung
- Wunsch: Moeglichkeit "alle auf einmal abhaken" (bewusste Entscheidung)
- Kognitives Problem: "Abhaken = ich habe das gerade gemacht" vs. "Ich erkenne an, dass ich das haette tun sollen"

## Technische Analyse (Feature Planner)

### Betroffene Dateien (5 Stueck)

1. **RecurrenceService.swift** — `repairOrphanedRecurringSeries()`: Loop (30 Instanzen) auf max 1 reduzieren
2. **RecurringStackingHelper.swift** — Pfad A (echte Gruppierung) entfernen, Pfad B universell
3. **BacklogView.swift** — `completeTask()` Sibling-Suche entfernen
4. **MacBacklogHelpers.swift** — Pfad A entfernen (macOS-Paritaet!)
5. **FocusBloxApp.swift** — Einmalige Migration: mehrere offene → 1 behalten

### Scope

+42 / -70 LoC, 5 Dateien. Innerhalb Scoping-Limits.

### Kritische Design-Entscheidung

`createNextInstance` setzt aktuell `dueDate = altes dueDate + 1 Zyklus`.
Bei virtuellem Stacking: Badge "x3" → abhaken → neue Instanz mit dueDate +1 Zyklus → immer noch ueberfaellig → Badge "x2". Das ist korrekt und gewuenscht.
