# Bug #279 — Analyse: Wiederkehrende Tasks häufen sich unsichtbar an

## User-Erwartung (User Advocate)

Der User hakt einen wiederkehrenden Task ab und sieht sofort den nächsten an der gleichen Stelle erscheinen — ohne zu verstehen warum. Es fühlt sich an wie "die App ist kaputt" oder "mein Abhaken funktioniert nicht". Der User weiß nicht, dass mehrere Instanzen aufgelaufen sind.

**Erwartung:** Visuelle Klarheit — der User muss SEHEN, dass 3 Instanzen gestapelt sind (z.B. Badge "x3", gestapelte Karten, oder ein Hinweis).

## Root Cause Analyse

### Befund 1: Stacking existiert bereits, aber funktioniert nicht immer

Das Feature wurde in Commit `d17c4bf` (RW_3.5) implementiert:
- `BacklogView.applyRecurringStacking()` gruppiert Instanzen nach `recurrenceGroupID`
- `BacklogRow` zeigt `StackingBadge` (x2, x3) wenn `stackedInstanceCount >= 2`
- Orange Hintergrund ab `stackedInstanceCount >= 3`

### Befund 2: Instanzen werden nur bei Completion erzeugt

`RecurrenceService.createNextInstance()` wird NUR aufgerufen, wenn eine Instanz abgehakt wird. Wenn der User 3 Tage die App nicht öffnet, existiert trotzdem nur EINE offene Instanz — der Repair-Service (`repairOrphanedRecurringSeries`) erzeugt maximal einen Nachfolger, nicht N für N verpasste Tage.

**→ "Anhäufung" im klassischen Sinne (3 separate Instanzen) passiert selten.**

### Befund 3: Wenn Stacking passiert, kann es durch isNextUp brechen

`applyRecurringStacking()` schließt `isNextUp`-Tasks nicht aus der Gruppenbildung aus. Wenn die älteste Instanz als "Heute" markiert ist, wird sie zum Repräsentant mit dem Badge — aber sie erscheint in der Heute-Sektion, nicht im Backlog. Die restlichen Instanzen im Backlog haben dann kein Badge.

### Befund 4: In-Place-Edits verlieren temporär den Badge

`updateImportance()`, `updateUrgency()`, `updateCategory()`, `updateDuration()` ersetzen `planItems[index]` mit einem frischen PlanItem (stackedInstanceCount = 1). Das Badge verschwindet kurz, bis `scheduleDeferredResort()` → `refreshLocalTasks()` → `applyRecurringStacking()` es wiederherstellt.

### Befund 5: macOS hat separate Implementierung mit Lücken

- `MacBacklogStackingHelper.applyStacking()` filtert nicht nach `!isTemplate` und `!isCompleted`
- Score-Berechnung ohne `stackedInstanceCount` → kein Stacking-Boost auf macOS

## Wahrscheinlichste Root Cause

**Das eigentliche Problem ist zweistufig:**

1. **Instanzen werden nicht proaktiv für verpasste Zyklen erzeugt** — der User sieht nur eine Instanz, nicht die "aufgelaufenen". Das ist das Kernproblem aus Hennings Sicht.

2. **Wenn doch mehrere Instanzen existieren**, funktioniert die Visualisierung meist korrekt — AUSSER bei isNextUp-Aufspaltung oder In-Place-Edits.

## Betroffene Dateien

- `Sources/Services/RecurrenceService.swift` — Instanz-Erzeugung (nur on-completion)
- `Sources/Views/BacklogView.swift` — `applyRecurringStacking()` (isNextUp-Lücke)
- `Sources/Views/BacklogRow.swift` — Badge-Rendering
- `Sources/Views/Components/TaskBadges.swift` — StackingBadge-Komponente
- `FocusBloxMac/MacBacklogHelpers.swift` — macOS Stacking (Template-Filter-Lücke)

## Blast Radius

- Coach View, Timeline View: Zeigen kein Stacking → nicht betroffen
- AI-Priorisierung: `stackingBoost()` gibt +5 pro Extra-Instanz → ändert sich bei Fix
- macOS: Separate Implementierung, eigene Bugs
- Bestehende Tests: `RecurringStackingTests`, `MacBacklogParkdeckStackingTests`, `BacklogStackingUITests`
