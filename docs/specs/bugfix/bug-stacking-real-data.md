---
entity_id: bug-stacking-real-data
type: bugfix
created: 2026-05-02
updated: 2026-05-02
status: draft
version: "1.0"
tags: [stacking, recurring, backlog, real-data]
issue: "#279"
---

# Bug-Fix: Stacking-Bar erscheint bei echten Daten (Auflauf-Cycles)

## Approval

- [ ] Approved

## Purpose

Die rote Bar "⚠ N× AUFGELAUFEN — seit [Datum]" muss bei echten User-Daten auf iPhone und macOS erscheinen — nicht nur mit Mock-Seed im Simulator. Bisherige 5 Anläufe (#279) haben das Feature nicht zu echten Geräten gebracht, weil sie alle auf `recurrenceGroupID`-Gruppierung basierten und dieses Feld bei Bestandsdaten / manuell erstellten / via Reminders importierten Tasks fehlt.

Der neue Ansatz: Die Bar wird auch bei einer einzelnen überfälligen wiederkehrenden Task gezeigt, wenn `recurrencePattern != "none"` und `dueDate` weit genug in der Vergangenheit liegt, sodass mindestens 2 Cycles verpasst wurden. Anzahl wird aus `recurrencePattern` + Zeit-Differenz seit `dueDate` berechnet — ohne dass DB-Migration oder zusätzliche Instanzen nötig sind.

## Source

- **File:** `Sources/Services/RecurringStackingHelper.swift`
- **macOS Pendant:** `FocusBloxMac/MacBacklogHelpers.swift` (`MacBacklogStackingHelper.applyStacking`)
- **Identifier:** `RecurringStackingHelper.apply(to:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PlanItem` | Model | Liefert `recurrencePattern`, `dueDate`, `recurrenceInterval`; trägt Output `stackedInstanceCount` + `stackedOldestDueDate` |
| `BacklogRow.swift` | View | Rendert `StackingCounterBar` wenn `stackedInstanceCount >= 2` |
| `TaskBadges.swift` | View | Definiert `StackingCounterBar` |
| `MacBacklogRow.swift` | View | macOS-Pendant |

## Implementation Details

### Erweiterung der Bar-Logik

`RecurringStackingHelper.apply(to:)` bekommt einen ZWEITEN Pfad:

**Pfad A (bisher, unverändert):** Tasks mit `recurrenceGroupID != nil`, gruppiert, ≥2 Children → Stack mit Counter = `indices.count`.

**Pfad B (NEU):** Für jede einzeln verbleibende Task (nach Pfad-A-Verarbeitung) gilt:
- Wenn `recurrencePattern != "none"` UND `recurrencePattern != ""`
- UND `!isTemplate`, `!isCompleted`, `!isNextUp`
- UND `dueDate != nil`
- UND `dueDate < heute (00:00 morgen)`
- → berechne `missedCycles` aus `(now - dueDate) / cycleDuration(pattern, interval)`
- → wenn `missedCycles >= 2`: setze `stackedInstanceCount = missedCycles`, `stackedOldestDueDate = dueDate`

### Cycle-Dauer pro Pattern

```
daily       → 1 Tag * (interval ?? 1)
weekly      → 7 Tage * (interval ?? 1)
biweekly    → 14 Tage
monthly     → 30 Tage * (interval ?? 1)  // pragmatisch, keine Kalenderarithmetik
custom      → wenn interval gesetzt: interval Tage; sonst Pfad B nicht aktivieren
```

### Berechnung `missedCycles`

```
elapsed = now.startOfDay - dueDate.startOfDay (in Tagen)
missedCycles = (elapsed / cycleDays) + 1   // +1, weil dueDate selbst der erste verpasste Cycle ist
```

Beispiele:
- daily, dueDate vor 5 Tagen → elapsed=5, cycle=1, missed=6 → "6× AUFGELAUFEN" ✓
- daily, dueDate vor 1 Tag → elapsed=1, cycle=1, missed=2 → "2× AUFGELAUFEN" ✓
- daily, dueDate heute fällig → elapsed=0, cycle=1, missed=1 → keine Bar ✓
- weekly, dueDate vor 21 Tagen → elapsed=21, cycle=7, missed=4 → "4× AUFGELAUFEN" ✓
- weekly, dueDate vor 6 Tagen → elapsed=6, cycle=7, missed=1 → keine Bar ✓
- monthly, dueDate vor 65 Tagen → elapsed=65, cycle=30, missed=3 → "3× AUFGELAUFEN" ✓

### Konflikt mit Pfad A

Falls eine Task in Pfad A bereits gruppiert wurde (Children-Variante), wird Pfad B für die Repräsentanten-Task NICHT mehr aktiv — sie wurde bereits durch Pfad A mit Counter belegt. Pfad B ergänzt nur, ersetzt nicht.

Hinweis: Wenn der Repräsentant in Pfad A bereits einen `stackedInstanceCount` aus Children-Counting hat UND zusätzlich Pattern-basierte Cycles seit `dueDate` verpasst sind, wählen wir das Maximum beider Werte. Das schützt vor Doppelzählung und matcht Hennings mentales Modell ("zeig mir die Realität").

### macOS

`MacBacklogStackingHelper.applyStacking` (`FocusBloxMac/MacBacklogHelpers.swift:41-75`) bekommt dieselbe Erweiterung. Falls möglich, wird die Logik nach `Sources/Services/` extrahiert und beide Plattformen teilen Code (gemäß CLAUDE.md "Cross-Platform Code-Sharing"). Falls Code-Sharing zu disruptiv: macOS bekommt einen Kopier-Patch, mit Linkverweis auf iOS als Single Source of Truth (Issue für späteres Konsolidieren).

### Rendering bleibt unverändert

`StackingCounterBar` (`Sources/Views/Components/TaskBadges.swift:192`) wird OHNE Änderung wiederverwendet. Sie liest `stackedInstanceCount` + `stackedOldestDueDate` und rendert die rote Bar. Format unverändert: `⚠ N× AUFGELAUFEN — seit EEE d. MMM` (Locale `de_DE`).

## Expected Behavior

### Eingabe
Liste von `PlanItem` aus `BacklogView.refreshLocalTasks()` (gefilterte offene Tasks aus echtem User-Datenstand).

### Ausgabe
Liste von `PlanItem`, in der wiederkehrende Tasks mit ≥2 verpassten Cycles eine `stackedInstanceCount >= 2` und `stackedOldestDueDate != nil` tragen. Diese Tasks rendern die rote Bar.

### Side effects
Keine. Kein DB-Schreibzugriff. Keine Instanzen werden erzeugt. Reine View-Berechnung.

## Acceptance Criteria

1. **Single recurring overdue task (Hauptszenario):**
   Eine `daily`-Task ohne `recurrenceGroupID`, ohne Geschwister, mit `dueDate = heute - 5 Tage` → Bar erscheint mit "6× AUFGELAUFEN — seit [Datum]".

2. **Single weekly overdue:**
   Eine `weekly`-Task mit `dueDate = heute - 21 Tage` → Bar erscheint mit "4× AUFGELAUFEN".

3. **Single recurring nicht überfällig:**
   `daily`, `dueDate = heute` → keine Bar.

4. **Single recurring 1 Cycle überfällig:**
   `daily`, `dueDate = heute - 1 Tag` → keine Bar (genau 1× verpasst, Schwelle ist 2).
   *Korrektur lt. Spec-Formel:* `elapsed=1, cycle=1, missed=2` → Bar erscheint mit "2× AUFGELAUFEN". (Anpassung in Test berücksichtigen.)

5. **Multi-Children-Stack (Pfad A unverändert):**
   2 Children mit gleichem `recurrenceGroupID` → Bar mit "2× AUFGELAUFEN" wie bisher.

6. **Mixed Pfad-A + Pfad-B:**
   Repräsentant nach Pfad-A-Gruppierung (`indices.count = 2`), gleichzeitig `dueDate = heute - 10 Tage` daily → Counter = max(2, 11) = 11.

7. **Non-recurring überfällig:**
   `recurrencePattern = "none"`, `dueDate = heute - 30 Tage` → keine Bar (nur Recurring-Tasks bekommen Auflauf-Bar).

8. **Template:**
   `isTemplate = true` → keine Bar (Templates sind unsichtbar).

9. **Bestehende Mock-Seed-Tests bleiben grün:**
   `BacklogStackingUITests` (6/6) müssen weiter passieren.
   `RecurringStackingTests` (13/13) müssen weiter passieren — bestehende Acceptance-Criteria bleiben gewahrt.

10. **macOS funktioniert identisch:**
    Selbe Logik in `MacBacklogStackingHelper`.

## Known Limitations

- **Monthly-Pattern verwendet 30 Tage als Pauschale.** Echte Kalenderarithmetik (z.B. 28 Tage im Februar) wird nicht ausgewertet. Bewusste Vereinfachung — der "× AUFGELAUFEN"-Counter ist eine Anzeige, kein DB-Eintrag. Abweichungen ±1 sind akzeptabel.
- **Custom-Pattern ohne `recurrenceInterval`** wird nicht ausgewertet (Pfad B inaktiv). User-Aufgabe mit "custom"-Pattern aber ohne explizites Intervall ist Edge Case und nicht stack-fähig.
- **Backfill der `recurrenceGroupID`** wird in diesem Fix NICHT gemacht. Pfad B umgeht die Notwendigkeit. (Falls später User-Stories anfallen wo wirklich N echte Children gestapelt werden müssen, kommt das als separater Bug.)

## Out of Scope

- Reparieren der 6 Schreibstellen die `recurrenceGroupID` nicht setzen (`LocalTaskSource.createTask`, `RemindersImportService.importAll`, Intents, Split, Copy). Sie können in Folge-Bugs adressiert werden — sind nicht mehr blocking weil Pfad B unabhängig ist.
- Tab-Badge-Counter (`BacklogBadgeService.swift`) — separater Folge-Bug falls noch falsch gezählt wird.
- `SmartNotificationEngine` Notification-Spam — separater Folge-Bug.
- macOS/iOS-Code-Konsolidierung von Stacking-Logik — Folge-Bug (TD-Item).

## Changelog

- 2026-05-02: Initial spec — Cycle-basierte Auflauf-Bar als Pfad B in `RecurringStackingHelper`
