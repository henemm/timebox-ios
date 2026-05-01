# Bug: Gestackte wiederkehrende Tasks ohne Anzahl-Badge — Re-Open

**Datum:** 2026-04-30
**Workflow:** bug-recurring-stack-count-badge
**Vorgaenger-Anlaeufe:** 5 (commits `2767a92`, `d17c4bf`, `62e4dd0`, `5604f09`, `56dc58c`)

## User-Erwartung (User Advocate)

Der User hat eine wiederkehrende Aufgabe (z.B. "Sport machen", wöchentlich). Wenn er sie mehrfach verpasst hat, sollen die offenen Eintraege als **EINE Zeile mit Anzahl-Badge** erscheinen — nicht 5 separate Zeilen, die die Liste aufblähen.

> "Ein einziger Eintrag mit einer sichtbaren Zahl daneben. Ich sehe sofort: das ist eine Aufgabe, aber ich bin X-mal im Rückstand. Die Liste bleibt sauber. Ich weiß trotzdem Bescheid."

## Live-Reproduktion (heute, 30.04.2026)

`./scripts/sim.sh test BacklogStackingUITests` → **7 von 7 Tests rot**:

| Test | Ergebnis |
|------|----------|
| `test_seriesWithThreeInstances_showsBadgeX3` | FAIL — Badge "x3" nicht sichtbar |
| `test_seriesWithTwoInstances_showsBadgeX2` | FAIL — Badge "x2" nicht sichtbar |
| `test_stackedSeries_rendersAsSingleRow` | FAIL — 0 Wochenreview-Rows |
| `test_singleInstanceSeries_hasNoStackingBadge` | FAIL — Anker fehlt (es gibt gar keine Badges) |
| `test_stackedTaskShowsSubtitle` | FAIL — "X Instanzen seit"-Untertitel fehlt |
| `test_stackingBadgeExistsForTwoInstances` | FAIL — kein "x2"-Badge |
| `test_stackingBadgeExistsForThreeInstances` | FAIL |

Bug ist beweisbar live, nicht nur theoretisch.

## Drei konkurrierende Hypothesen (aus 5 parallelen Investigatoren)

### Hypothese 1 — Filter-Pipeline blockt Children
*(Wiederholungs-Check + previous-attempts.md vom 2026-04-27)*

Recurring-Children erreichen `planItems` gar nicht. `LocalTaskSource.fetchIncompleteTasks` filtert sie via `isVisibleInBacklog` raus, bevor `applyRecurringStacking()` läuft. Beweis: voriger Test zeigte "0 Wochenreview-Rows".

**Pro:** Erklärt das Test-Symptom "0 Rows".
**Contra:** Code-Lesung zeigt: `isVisibleInBacklog` lässt `dueDate < startOfTomorrow` durch. Mock-Children haben heute/-1T/-7T/-14T → alle `< morgen` → sollten passieren.

### Hypothese 2 — Stacked-Survivor wird in "Überfällig" versteckt
*(Datenfluss-Trace)*

`applyRecurringStacking()` läuft korrekt und setzt `stackedInstanceCount=3` auf den Repräsentant. Aber: Repräsentant = ältester Child (-14T) → `dueDate < heute` → landet in `overdueTasks`. `tasksForTierGroup` (Z. 137-141) **schließt explizit alle overdueIDs aus**. Stacked-Rows erscheinen also nur in der "Überfällig"-Sektion oben.

**Pro:** Code-Pfad ist nachweisbar (BacklogView.swift:138).
**Contra:** Erklärt nicht, warum die UI-Tests trotzdem rot sind — sie suchen Badge **überall** auf dem Screen, nicht in einer bestimmten Sektion. "Überfällig"-Sektion ist seit #295-Fix (commit `59d73b9`, heute) im Accessibility-Tree exposed.

### Hypothese 3 — Mock-Daten werden nicht (mehr) geseedet
*(implizit aus Bug-Intake)*

Trotz Sentinel-Fix in `56dc58c` werden die Recurring-Children nicht in den ModelContext eingefügt — z.B. weil das Sentinel-Lookup falsch macht oder `seedUITestData()` nicht beim UI-Test-Launch läuft.

**Pro:** Erklärt warum auch der "x2-Badge" Test rot ist.
**Contra:** Müsste durch direkte ModelContext-Inspektion verifiziert werden.

## Spannung & Empfehlung

⚡ **Spannung:** H1 sagt "Children fehlen", H2 sagt "Children sind da, aber in falscher Sektion versteckt", H3 sagt "Mock-Daten fehlen ganz".

**Meine Entscheidung:** Da alle 7 UI-Tests rot sind — **nicht nur die mit Sektions-Suche** — ist H2 allein keine ausreichende Erklärung. Die Tests fragen `app.staticTexts.matching(label == 'x3' AND identifier BEGINSWITH 'stackingBadge_')` ohne Sektions-Constraint. Wenn der Badge irgendwo gerendert wäre, würden sie ihn finden.

→ **H1 oder H3 ist Root Cause.** Die Children kommen entweder gar nicht erst in den ModelContext (H3) oder werden im Filter-Pfad zwischen ModelContext und `planItems` blockiert (H1).

**Diagnose-Schritt für Phase 4/5:** Ein Unit-Test gegen `LocalTaskSource.fetchIncompleteTasks()` mit den exakten Mock-Daten zeigt sofort, ob die Children durchkommen. Falls nein → H1 (Filter-Bug). Falls ja → `applyRecurringStacking()` direkt prüfen (H2 oder Render-Bug).

## Blast Radius (5. Investigator)

`isVisibleInBacklog` wird auch genutzt in:
- macOS `ContentView.swift:142`
- `Array+MenuBarPopoverFilter.swift:10`
- `CoachView`, `DayView` (über `fetchIncompleteTasks`)

→ Filter direkt zu lockern ist **gefährlich**. Empfehlung: Stacking VOR dem Visibility-Filter, oder Stacked-Rows separat behandeln (nicht als overdue klassifizieren).

## Was anders als bei den 5 Vor-Anläufen

Alle bisherigen Anläufe haben am `applyRecurringStacking()` rumgebastelt (Threshold senken, Felder hinzufügen, macOS-Pendant) — **keiner hat verifiziert, dass die Children überhaupt im `planItems`-Array landen**. Diesmal: erst Diagnose, dann gezielter Fix.

## Plattform-Status

- iOS: Bug bestätigt (7/7 UI-Tests rot)
- macOS: Noch nicht live geprüft, aber identische Architektur (`MacBacklogHelpers.applyStacking()` mit gleicher Pipeline)

## Affected Files (Vorab-Schätzung — wird in Phase 3 fixiert)

Maximal 4-5 Files:
1. `Sources/Views/BacklogView.swift` — `applyRecurringStacking()` Reihenfolge / Tier-Klassifikation
2. `Sources/Models/LocalTask.swift` — ggf. `isVisibleInBacklog` Recurring-Edge-Case
3. `Sources/Services/TaskSources/LocalTaskSource.swift` — ggf. Stacking-bewusster Pre-Filter
4. `FocusBloxMac/MacBacklogHelpers.swift` — Plattform-Parität
5. (Tests werden in Phase 4 hinzugefügt — strikte Anti-Silent-Pass-Tests)
