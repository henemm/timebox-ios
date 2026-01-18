---
entity_id: next-up-bugfix
type: bugfix
created: 2026-01-18
status: draft
workflow: next-up-bugfix
---

# Next Up Staging Area - Bugfixes

## Approval

- [x] Approved for implementation (2026-01-18)

## Purpose

Behebt 4 Bugs im Next Up Staging Area Feature (Bug 3 Drag&Drop ist deferred).

## Bugs

| Bug | Problem | Root Cause |
|-----|---------|------------|
| 1 | Tasks doppelt sichtbar (Next Up + Quadrant) | Filter ohne `!isNextUp` |
| 2 | Next Up horizontal statt vertikal | `ScrollView(.horizontal)` |
| 4 | Zuordnen-Tab horizontal statt vertikal | `ScrollView(.horizontal)` |
| 5 | Tasks verschwinden nach Zuordnung | `tasksForBlock()` sucht nur in `unscheduledTasks` |

## Scope

**Betroffene Dateien:**
- `TimeBox/Sources/Views/BacklogView.swift` - Filter erweitern
- `TimeBox/Sources/Views/NextUpSection.swift` - Layout aendern
- `TimeBox/Sources/Views/TaskAssignmentView.swift` - Layout + Logik fixen

**Geschaetzt:** ~60 LoC Aenderungen

## Implementation Details

### Bug 1: isNextUp Filter

Alle Filter-Properties in BacklogView.swift erweitern:

```swift
// Vorher:
private var backlogTasks: [PlanItem] {
    planItems.filter { !$0.isCompleted }
}

// Nachher:
private var backlogTasks: [PlanItem] {
    planItems.filter { !$0.isCompleted && !$0.isNextUp }
}
```

Betroffene Properties:
- `backlogTasks`
- `doFirstTasks`, `scheduleTasks`, `delegateTasks`, `eliminateTasks`
- `tasksByCategory`
- `tasksByDuration`
- `tasksByDueDate` (alle Filter in dieser Property)

### Bug 2: NextUpSection vertikal

```swift
// Vorher (Zeile 38):
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 8) { ... }
}

// Nachher:
VStack(spacing: 6) {
    ForEach(tasks) { task in
        NextUpRow(task: task) { onRemoveFromNextUp(task.id) }
    }
}
```

Neue `NextUpRow` Komponente (analog zu BacklogRow, aber kompakter).

### Bug 4: TaskAssignmentView vertikal

```swift
// Vorher (Zeile 108):
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 8) { ... }
}

// Nachher:
VStack(spacing: 6) {
    ForEach(unscheduledTasks) { task in
        DraggableTaskRow(task: task)
    }
}
```

Neue `DraggableTaskRow` Komponente.

### Bug 5: tasksForBlock Logik

```swift
// State hinzufuegen:
@State private var allTasks: [PlanItem] = []

// In loadData():
let syncedTasks = try await syncEngine.sync()
allTasks = syncedTasks.filter { !$0.isCompleted }
unscheduledTasks = syncedTasks.filter { $0.isNextUp && !$0.isCompleted }

// tasksForBlock aendern:
private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
    block.taskIDs.compactMap { taskID in
        allTasks.first { $0.id == taskID }  // statt unscheduledTasks
    }
}
```

## Test Plan

### Unit Tests (TDD RED)

- [ ] `testBacklogTasksExcludesNextUp` - GIVEN task with isNextUp=true WHEN backlogTasks computed THEN task not included
- [ ] `testDoFirstTasksExcludesNextUp` - GIVEN urgent+important task with isNextUp=true WHEN doFirstTasks computed THEN task not included

### UI Tests (TDD RED)

- [ ] `testNextUpSectionVerticalLayout` - GIVEN 2 tasks in Next Up WHEN displayed THEN tasks appear vertically
- [ ] `testTaskVisibleInBlockAfterAssignment` - GIVEN task assigned to block WHEN view refreshes THEN task visible in block

### Manual Tests

- [ ] Task zu Next Up → verschwindet aus Matrix-Quadrant
- [ ] Mehrere Next Up Tasks → untereinander angezeigt
- [ ] Zuordnen-Tab → Tasks vertikal
- [ ] Task in Block ziehen → erscheint im Block

## Acceptance Criteria

- [ ] Tasks mit `isNextUp=true` erscheinen NUR in Next Up Section
- [ ] Next Up Section zeigt Tasks vertikal
- [ ] Zuordnen-Tab zeigt Tasks vertikal
- [ ] Nach Zuordnung zu Block: Task im Block sichtbar
- [ ] Build erfolgreich
- [ ] Alle bestehenden Tests gruen

## Changelog

- 2026-01-18: Initial bugfix spec created
