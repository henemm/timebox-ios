---
entity_id: feature-012-coachbacklog-effectivescore
type: feature
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.1"
tags: [macos, coach-backlog, priority-score, badges]
---

# FEATURE_012: Coach-Backlog macOS — effectiveScore/Tier/dependentCount

## Approval

- [ ] Approved

## Purpose

`MacCoachBacklogView` übergibt beim Aufbau von `MacBacklogRow`-Instanzen die drei Parameter `effectiveScore`, `effectiveTier` und `dependentCount` nicht. Dadurch zeigt der `PriorityScoreBadge` im Coach-Backlog immer live-berechnete Werte statt frozen Scores (Sprünge beim Editieren), und der DEP-Boost (`dependentCount`) fehlt komplett. Diese Spec beschreibt die minimale Korrektur, um das gleiche Verhalten wie im normalen macOS-Backlog herzustellen.

## Source

- **File:** `FocusBloxMac/MacCoachBacklogView.swift`
- **Identifier:** `MacCoachBacklogView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DeferredSortController` | `@Observable` Service | Liefert `effectiveScore(id:liveScore:)` — frozen Score bei pending Resort |
| `TaskPriorityScoringService` | Service | `calculateScore()` für live Score; `PriorityTier.from(score:)` |
| `MacBacklogRow` | View | Empfänger der drei Parameter — keine Änderung nötig |
| `LocalTask` | Model | Task-Daten (importance, urgency, dueDate, etc.) |

## Implementation Details

### Datei 1: `FocusBloxMac/MacCoachBacklogView.swift`

**1. DeferredSortController via @Environment einbinden**

```swift
@Environment(DeferredSortController.self) private var deferredSort
```

**2. Helper: dependentCount(for:)**

```swift
private func dependentCount(for taskID: String) -> Int {
    tasks.filter { $0.blockerTaskID == taskID }.count
}
```

**3. Helper: scoreFor(_:)**

```swift
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
```

**4. coachRow(_:) — 3 Parameter ergänzen (Score einmalig cachen)**

```swift
private func coachRow(_ task: LocalTask) -> some View {
    let discipline = Discipline.resolveOpen(...)
    let score = scoreFor(task)    // einmalig berechnen
    return MacBacklogRow(
        task: task,
        // ... existing callbacks ...
        disciplineColor: discipline.color,
        dependentCount: dependentCount(for: task.id),
        effectiveScore: score,
        effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: score)
    )
    // ... contextMenu unverändert
}
```

**5. blockedRow(_:) — 3 Parameter ergänzen**

```swift
private func blockedRow(_ task: LocalTask) -> some View {
    let discipline = Discipline.resolveOpen(...)
    let score = scoreFor(task)    // einmalig berechnen
    return MacBacklogRow(
        task: task,
        isBlocked: true,
        disciplineColor: discipline.color,
        dependentCount: dependentCount(for: task.id),
        effectiveScore: score,
        effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: score)
    )
    // ... contextMenu unverändert
}
```

### Datei 2: `FocusBloxMacUITests/MacCoachBacklogScoreUITests.swift` (NEU)

Neue Test-Datei für macOS Coach Backlog Score-Verhalten.

Launch-Setup: `-UITesting -MockData -coachModeEnabled 1 -ApplePersistenceIgnoreState YES`

**Hinweis:** `@AppStorage("coachModeEnabled")` liest aus `UserDefaults.standard`. XCUIApplication-Launch-Argumente in der Form `-key value` werden automatisch in UserDefaults injiziert. `-coachModeEnabled 1` aktiviert Coach Mode ohne Code-Änderung im App-Target.

### Keine weiteren Änderungen

`MacBacklogRow` hat die drei Parameter bereits korrekt implementiert. Kein Änderungsbedarf.

## Expected Behavior

- **Input:** Coach-Backlog öffnen (macOS, `coachModeEnabled = true`)
- **Output:** Jede `MacBacklogRow` im Coach-Backlog zeigt denselben `PriorityScoreBadge` wie im normalen Backlog — inkl. DEP-Boost und frozen Score bei laufendem Resort
- **Side effects:** Keine — `DeferredSortController` ist bereits im App-Environment vorhanden

## Acceptance Criteria

1. `coachTaskList` ist sichtbar wenn `coachModeEnabled = true`
2. `priorityScoreBadge_*` erscheint für Tasks im `coachTaskList`
3. Score-Berechnung verwendet `dependentCount` (nicht konstant 0)
4. Score-Berechnung verwendet `DeferredSortController.effectiveScore` (frozen Score-Support)
5. Build ohne Fehler/Warnings

## Test Plan (UI Tests — TDD RED)

**Datei:** `FocusBloxMacUITests/MacCoachBacklogScoreUITests.swift` (neue Datei)
**Target:** `FocusBloxMacUITests`

| # | Testname | Setup | Assertion | Warum RED |
|---|----------|-------|-----------|-----------|
| T1 | `test_coachBacklog_showsCoachTaskList` | Launch mit `-coachModeEnabled 1` | `coachTaskList` exists | Schlägt fehl wenn Coach mode nicht aktiviert |
| T2 | `test_coachBacklog_tasks_havePriorityScoreBadge` | Launch mit `-coachModeEnabled 1` | `priorityScoreBadge_*` in `coachTaskList` | Schlägt fehl wenn Badge nicht in Coach-Row erscheint |

**TDD RED Rationale:** Die Tests schlagen in der aktuellen Codebase fehl weil:
- T1: `coachTaskList` braucht `coachModeEnabled = true` — Verhalten muss explizit verifiziert werden
- T2: Prüft, dass der Badge in Coach-Rows korrekt gerendert wird — strukturelle Regression-Protection

## Known Limitations

- Exakter Score-Wert ist in UI-Tests nicht sinnvoll prüfbar (keine deterministischen Mock-Werte mit Blocker-Beziehungen in `seedUITestData`)
- DEP-Boost-Korrektheit wird durch Code Review sichergestellt (gleiche Implementierung wie `ContentView.makeBacklogRow()`)
- `DeferredSortController.effectiveScore()` liefert frozen Score nur wenn Resort pending ist — korrekt und identisch zum normalen Backlog

## Changelog

- 2026-03-16: Initial spec created (FEATURE_012)
- 2026-03-16: v1.1 — Score-Caching fix, macOS UI Tests in FocusBloxMacUITests, TDD RED Rationale ergänzt
