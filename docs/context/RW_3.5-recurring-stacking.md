# Context: RW_3.5 — Recurring Stacking

## Request Summary

Wenn ein User wiederkehrende Aufgaben mehrfach nicht erledigt, entstehen mehrere offene Instanzen derselben Serie. Diese sollen visuell zu einer Zeile mit Badge "x3" gruppiert werden, und die Prioritaet soll mit der Anzahl aufgelaufener Instanzen steigen.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | `recurrenceGroupID`, `isTemplate`, `isVisibleInBacklog` — Grundlage der Gruppierung |
| `Sources/Models/PlanItem.swift` | `recurrenceGroupID` wird aus LocalTask uebernommen (line 27) |
| `Sources/Services/TaskPriorityScoringService.swift` | Scoring-Formel: `eisenhower + deadline + neglect + completeness + nextUp + blocker` — neuer `stackingBoost` Faktor noetig |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `fetchIncompleteTasks()` liefert flache Liste — neue Query fuer Instanz-Zaehlung pro Gruppe noetig |
| `Sources/Services/RecurrenceService.swift` | Template/Child-Beziehung, `createNextInstance()`, `deduplicateChildInstances()` |
| `Sources/Views/BacklogView.swift` | Hauptview: Priority/Recent/Overdue/Recurring Modes, Aktiv/Parkdeck Sections — Gruppierungslogik muss hier rein |
| `Sources/Views/BacklogRow.swift` | iOS Task-Zeile: braucht `stackedCount` Parameter + Badge |
| `FocusBloxMac/ContentView.swift` | macOS Backlog: gleiche Gruppierungslogik noetig |
| `FocusBloxMac/MacBacklogRow.swift` | macOS Task-Zeile: braucht `stackedCount` Parameter + Badge |

## Existing Patterns

### Recurring-Modell
- `recurrenceGroupID: String?` verbindet alle Instanzen einer Serie
- `isTemplate: Bool` = Mutter-Instanz (unsichtbar im Backlog)
- Child-Instanzen haben konkretes `dueDate`, sichtbar wenn `isVisibleInBacklog = true`
- Beim Abschliessen: `createNextInstance()` erzeugt naechstes Kind

### Priority Scoring (aktuell)
```
min(100, eisenhower[0-50] + deadline[0-25] + neglect[0-15] + completeness[0-5] + nextUp[0-5] + blocker[0-9])
```
Kein Faktor fuer aufgelaufene Instanzen.

### Backlog View Modes
- `priority`: Aktiv (sortiert nach Score) → Parkdeck (collapsed)
- `recent`: Nach Erstelldatum
- `overdue`: Ueberfaellige Tasks
- `recurring`: Nur Templates
- Overdue-Section erscheint in allen Modi ausser `overdue`

### Parkdeck (RW_2.4)
- `isInParkdeck`: `isParked || priorityTier == .eventually || priorityTier == .someday`
- Aktive vs. Parkdeck Sections mit Swipe-Actions

### Completion Flow
- `completeTask()` in BacklogView nutzt `item.id` direkt
- Bei Stacking muss die aelteste Instanz (fruehestes `dueDate`) erledigt werden, nicht die angezeigte

## Dependencies

### Upstream (was unser Code nutzt)
- `PlanItem` als ViewModel-Wrapper um `LocalTask`
- `SyncEngine.sync()` fuer Datenladen
- `DeferredSortController` fuer Sort-Lock Logik
- `TaskPriorityScoringService` fuer Score-Berechnung

### Downstream (was unseren Code nutzt)
- `DayView` zeigt auch Backlog-Tasks (Morning Mode Vorschlaege)
- `MorningCoachingService` nutzt Priority Scores
- `EmotionalNudgeService` checkt aufgelaufene/verschobene Tasks
- macOS `ContentView` hat eigene Backlog-Ansicht

## Existing Specs
- `docs/specs/rework/3.5-recurring-stacking.md` — Feature-Skizze (noch nicht approved)

## Risks & Considerations

1. **Completion-Logik**: Beim Abhaken muss die aelteste Instanz erledigt werden, nicht die "repraesentative" — sonst entstehen Dateninkonsistenzen
2. **Stacking + Parkdeck**: Gestackte Serie koennte durch Boost aus Parkdeck in Aktiv springen — gewuenscht?
3. **Stacking + Next Up**: Kann eine gestackte Serie als "Next Up" markiert werden? Wenn ja, welche Instanz?
4. **Stacking + Overdue**: Alle Instanzen sind per Definition ueberfaellig — wie zaehlt die Overdue-Section?
5. **Stacking in anderen Views**: DayView Morning-Vorschlaege, Emotional Nudge — muessen die auch stacken?
6. **macOS Paritaet**: Beide Plattformen muessen gleich gruppieren
7. **Performance**: Gruppierung ist O(n) — bei vielen Tasks kein Problem, aber Fetch-Query sollte effizient sein

---

## Analysis

### Type
Feature

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/TaskPriorityScoringService.swift` | MODIFY | Neuer `stackingBoost` Faktor (+5 pro Instanz, max +15) |
| `Sources/Views/BacklogView.swift` | MODIFY | Gruppierung nach `recurrenceGroupID`, Stacking-Count an Rows, Completion aelteste Instanz |
| `Sources/Views/BacklogRow.swift` | MODIFY | `stackedCount` Parameter + Stacking-Badge + visuelle Eskalation |
| `FocusBloxMac/ContentView.swift` | MODIFY | Gleiche Gruppierungslogik fuer macOS Backlog |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | `stackedCount` Parameter + Badge (macOS) |
| `Sources/Models/PlanItem.swift` | MODIFY | Property fuer Stacking-Count (extern gesetzt) |
| `FocusBloxUITests/BacklogStackingUITests.swift` | CREATE | UI Tests: Badge, Completion, Scoring |
| `FocusBloxTests/RecurringStackingTests.swift` | CREATE | Unit Tests: Gruppierung, Scoring-Boost |

### Scope Assessment
- **Production Files:** 6 MODIFY
- **Test Files:** 2 CREATE
- **Estimated LoC:** +200/-20 (Production), +150 (Tests)
- **Risk Level:** MEDIUM — Completion-Logik ist kritisch, Gruppierung aendert Backlog-Darstellung fundamental

### Technical Approach (Empfehlung)

**Architektur:** Gruppierungslogik als reine Funktion auf `[PlanItem]` — kein neues Model, keine DB-Aenderung.

1. **Scoring-Boost** in `TaskPriorityScoringService`: Neuer Parameter `stackedInstanceCount: Int = 0`, Boost-Funktion `+5 * max(0, count - 1)` capped bei +15
2. **Gruppierung** in BacklogView: Nach dem Fetch `planItems` nach `recurrenceGroupID` gruppieren. Pro Gruppe: repraesentative PlanItem (aeltestes dueDate) + Count. Nicht-recurring Items bleiben ungrouped.
3. **Completion**: `completeTask()` erhaelt GroupID statt ItemID bei gestackten Tasks → findet aelteste Instanz → markiert diese als erledigt
4. **Badge UI**: Neues `StackingBadge` in `BacklogRow` — analog zu bestehendem `RecurrenceBadge`
5. **macOS**: Identische Logik in ContentView/MacBacklogRow

**Phasierung (wegen LoC-Limit):**
- **Phase A:** Scoring-Boost + Gruppierungslogik + iOS UI (~200 LoC, 4 Dateien)
- **Phase B:** macOS Paritaet + Edge Cases (~100 LoC, 2 Dateien)

### Related Specs
| Spec | Status | Relevanz |
|------|--------|----------|
| `rework/3.5-recurring-stacking.md` | Skizze | PRIMARY |
| `rework/2.4-backlog-ux-rework-impl.md` | Implemented | Parkdeck-Pattern (Sections, Collapse) |
| `ios/feature-026-priority-sort-coach-boost.md` | Implemented | Scoring-System + Tiers |
| `features/recurring-tasks-phase1b.md` | Implemented | `recurrenceGroupID` Fundament |
| `features/backlog-010-deferred-sort-controller.md` | Implemented | Score-Freezing bei Edits |

### Completion Flow (kritischer Pfad)
```
User tippt Checkbox auf gestacktem "Waesche waschen x3"
  -> BacklogView: Finde alle offenen Instanzen mit gleicher recurrenceGroupID
  -> Sortiere nach dueDate ASC
  -> completeTask(aeltesteInstanz.id)
  -> SyncEngine markiert aelteste als erledigt
  -> RecurrenceService.createNextInstance() erzeugt neue Instanz
  -> Badge sinkt von x3 auf x2
  -> Wenn x1: Badge verschwindet, normale Darstellung
```

### Open Questions (fuer PO)
1. Soll Stacking in **allen** View Modes gelten oder nur Priority?
2. Soll der User gestackte Gruppen **aufklappen** koennen?
3. Wie verhaelt sich Stacking mit **"Next Up"**?
4. Soll Stacking in **Phase A nur iOS** sein, macOS in Phase B?
