---
entity_id: bug-279-recurring-stacking
type: bugfix
created: 2026-04-19
updated: 2026-04-19
status: draft
version: "1.0"
tags: [recurrence, backlog, stacking, badge]
---

# Bug 279 — Wiederkehrende Tasks: Angehäufte Instanzen werden nicht visualisiert

## Approval

- [ ] Approved

## Purpose

Wenn ein wiederkehrender Task mehrere Zyklen lang nicht erledigt wird, akkumulieren sich stille Instanzen im Backlog ohne sichtbaren Hinweis. Dieser Fix macht die Anhäufung sichtbar (Badge, Untertitel, Farb-Tint) und stellt sicher, dass alle verpassten Instanzen beim App-Start tatsächlich erzeugt werden.

## Source

Zwei unabhängige Root Causes:

**Problem A — Repair-Service erzeugt nur einen Nachfolger:**
- **File:** `Sources/Services/RecurrenceService.swift`
- **Identifier:** `repairOrphanedRecurringSeries()`

**Problem B — isNextUp-Instanzen werden in Stacking-Gruppe einbezogen:**
- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `applyRecurringStacking()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RecurrenceService.repairOrphanedRecurringSeries()` | function | Muss alle fehlenden Instanzen für verpasste Zyklen erzeugen (nicht nur einen Nachfolger) |
| `BacklogView.applyRecurringStacking()` | function | Muss isNextUp-Instanzen aus der Stacking-Gruppierung ausschliessen |
| `BacklogRow` | view | Zeigt neuen Untertitel "N Instanzen seit [Datum]" für gestackte Tasks |
| `TaskBadges.StackingBadge` | component | Badge wird orange ab 2 Instanzen (bisher erst ab 3) |
| `PlanItem` | model | Braucht Feld `stackedOldestDueDate` für den Untertitel |
| `MacBacklogHelpers` | helper | Template-Filter-Lücke schliessen (macOS-Parität) |

## Implementation Details

### Fix A — Repair-Service: Alle verpassten Zyklen erzeugen

`repairOrphanedRecurringSeries()` iteriert heute beginnend rückwärts bis zum letzten vorhandenen dueDate der Serie und erzeugt für jeden fehlenden Zyklus eine neue Instanz. Maximale Anzahl neu erzeugter Instanzen: 30 (Schutz vor unbegrenztem Wachstum).

### Fix B — applyRecurringStacking(): isNextUp ausschliessen

Beim Aufbau der Stacking-Gruppen werden Tasks mit `isNextUp == true` nicht in die Gruppe einbezogen. Sie verbleiben in der Heute-Sektion ohne Badge-Manipulation.

### Darstellung gestackter Tasks (ab 2 Instanzen)

- **StackingBadge:** "x2", "x3" ... — IMMER orange (bisher erst ab 3)
- **Hintergrund-Tint:** orange ab 2 Instanzen (bisher erst ab 3)
- **Untertitel in BacklogRow:** "3 Instanzen seit Mo, 14. Apr" (lokalisiertes ältestes dueDate)
- **stackedOldestDueDate:** neues optionales Feld in `PlanItem`, wird von `applyRecurringStacking()` gesetzt

### macOS-Parität

`MacBacklogHelpers.swift` erhält denselben Template-Filter wie die iOS-Seite, damit Template-Einträge nicht fälschlicherweise in der Stacking-Logik auftauchen.

## Expected Behavior

- **Input:** Wiederkehrender Task, dessen letzte abgehakte Instanz 3 Zyklen zurückliegt
- **Output:** Eine Zeile im Backlog mit Badge "x3", orangem Tint und Untertitel "3 Instanzen seit [ältestes dueDate]"
- **Side effects:**
  - Repair-Service erzeugt beim App-Start fehlende Instanzen (max. 30 pro Serie)
  - Beim Abhaken einer gestackten Instanz sinkt der Badge-Counter um 1
  - isNextUp-Instanzen (Heute-Sektion) bleiben von der Stacking-Visualisierung unberührt
  - macOS zeigt identisches Verhalten

## Known Limitations

- Repair erzeugt maximal 30 fehlende Instanzen pro Serie (Schutz vor unbegrenztem Wachstum bei sehr alten, nie erledigten Tasks)
- Untertitel zeigt das älteste dueDate der gestackten Instanzen — nicht das Erstell-Datum der Serie

## Changelog

- 2026-04-19: Initial spec created
