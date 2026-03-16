# Context: FEATURE_012 — Coach-Backlog macOS: effectiveScore/Tier/dependentCount

## Request Summary

`MacCoachBacklogView` übergibt beim Erstellen von `MacBacklogRow` die drei Parameter `effectiveScore`, `effectiveTier` und `dependentCount` nicht. Dadurch zeigt die Badge-Anzeige (PriorityScoreBadge) immer live-berechnete Werte statt frozen Scores, und der `dependentCount`-Boost fehlt komplett.

## Root Cause (konkret)

In `MacCoachBacklogView.coachRow()` und `blockedRow()` werden `MacBacklogRow(...)` ohne diese Parameter aufgerufen:

```swift
// IST (falsch):
MacBacklogRow(task: task, ..., disciplineColor: discipline.color)

// SOLL (wie in ContentView.makeBacklogRow):
MacBacklogRow(task: task, ..., disciplineColor: discipline.color,
    dependentCount: dependentCount(for: task.id),
    effectiveScore: scoreFor(task),
    effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: scoreFor(task)))
```

`MacCoachBacklogView` hat zudem keinen Zugriff auf `DeferredSortController` (`@Environment`), der den frozen Score liefert.

## Related Files

| File | Relevanz |
|------|----------|
| `FocusBloxMac/MacCoachBacklogView.swift` | **Hauptdatei — muss geändert werden** |
| `FocusBloxMac/MacBacklogRow.swift` | Hat `dependentCount`, `effectiveScore`, `effectiveTier` als Parameter (bereits korrekt) |
| `FocusBloxMac/ContentView.swift` | **Referenzimplementierung** — `makeBacklogRow()` (L1104–1151), `dependentCount()` (L332), `scoreFor()` (L344) |
| `Sources/Services/DeferredSortController.swift` | Stellt `effectiveScore(id:liveScore:)` und `isPending(_:)` bereit |
| `Sources/Services/TaskPriorityScoringService.swift` | `calculateScore()`, `PriorityTier.from()` |
| `Sources/Models/PlanItem.swift` | `dependentCount` Feld (Int = 0) |

## Existing Patterns (aus ContentView.swift)

```swift
// dependentCount-Helper (L332):
private func dependentCount(for taskID: String) -> Int {
    visibleTasks.filter { $0.blockerTaskID == taskID }.count
}

// scoreFor-Helper (L344):
private func scoreFor(_ task: LocalTask) -> Int {
    let liveScore = TaskPriorityScoringService.calculateScore(
        importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
        createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
        estimatedDuration: task.estimatedDuration, taskType: task.taskType,
        isNextUp: task.isNextUp,
        dependentTaskCount: dependentCount(for: task.id)
    )
    return deferredSort.effectiveScore(id: task.id, liveScore: liveScore)
}

// DeferredSortController injection (L73):
@Environment(DeferredSortController.self) private var deferredSort
```

## Fix-Scope

**1 Datei:** `FocusBloxMac/MacCoachBacklogView.swift`

Änderungen:
1. `@Environment(DeferredSortController.self) private var deferredSort` hinzufügen
2. `dependentCount(for:)` Helper-Funktion (2 Zeilen, aus ContentView kopiert)
3. `scoreFor(_:)` Helper-Funktion (7 Zeilen, aus ContentView kopiert)
4. In `coachRow()`: 3 Parameter ergänzen
5. In `blockedRow()`: 3 Parameter ergänzen (dependentCount + effectiveScore + effectiveTier)

**LoC-Schätzung:** ~+20 Zeilen

## Analysis

### Type
Feature (fehlende Parameter-Weitergabe)

### Affected Files

| File | Change Type | Beschreibung |
|------|-------------|-------------|
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY | `@Environment` + 2 Helper + Parameter in coachRow/blockedRow |
| `FocusBloxUITests/CoachBacklogViewUITests.swift` | MODIFY | Neue UI-Tests: priorityScoreBadge in Coach-Backlog sichtbar |

### Scope Assessment
- **Dateien:** 2
- **Estimated LoC:** +25 / -0
- **Risk Level:** LOW — identisches Pattern wie ContentView.makeBacklogRow()

### Technical Approach

**MacCoachBacklogView.swift:**
1. `@Environment(DeferredSortController.self) private var deferredSort` ergänzen
2. `dependentCount(for: String) -> Int` Helper (2 Zeilen, identisch zu ContentView L332)
3. `scoreFor(_ task: LocalTask) -> Int` Helper (7 Zeilen, identisch zu ContentView L344)
4. `coachRow()`: `dependentCount:`, `effectiveScore:`, `effectiveTier:` ergänzen
5. `blockedRow()`: dieselben 3 Parameter ergänzen

**UI-Tests:**
- Test: Coach-Backlog (macOS) zeigt `priorityScoreBadge_` für Tasks an
- Test: Score ist > 0 (dependentCount-Boost korrekt)

### Open Questions
Keine.

## Dependencies

- `DeferredSortController` muss via `.environment()` im App-Lifecycle bereits eingebunden sein (ist es — ContentView nutzt es)
- `tasks: [LocalTask]` Array ist bereits in `MacCoachBacklogView` vorhanden (für dependentCount-Filter)

## Risks & Considerations

- Kein neues Risiko — identisches Pattern wie in `ContentView.makeBacklogRow()`
- `DeferredSortController` ist bereits im Environment (wird von ContentView genutzt)
- `blockedRow()` bekommt normalerweise keinen `effectiveScore` — ist aber korrekt, da blocked tasks weiterhin angezeigt werden sollen (mit Score 0 oder live-score macht keinen Unterschied für blocked tasks, aber Konsistenz ist besser)
