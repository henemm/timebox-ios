---
entity_id: next-up-staging-area
type: feature
created: 2026-01-18
status: implemented
workflow: backlog-purpose-analysis
---

# Next Up Staging Area

## Approval

- [x] Approved for implementation

## Purpose

Ermöglicht Nutzern, Tasks bewusst als "Next Up" zu markieren - eine Staging Area für Tasks, die als nächstes erledigt werden sollen. Diese Tasks erscheinen dann im Tab "Zuordnen" als verfügbare Tasks für Focus Blocks.

## Scope

**Betroffene Dateien:**
- `TimeBox/Sources/Models/LocalTask.swift` - neues Property `isNextUp`
- `TimeBox/Sources/Models/PlanItem.swift` - neues Property `isNextUp`
- `TimeBox/Sources/Services/SyncEngine.swift` - neue Methode `updateNextUp`
- `TimeBox/Sources/Views/BacklogView.swift` - NextUpSection oben
- `TimeBox/Sources/Views/TaskAssignmentView.swift` - zeigt nur Next Up Tasks
- `TimeBox/Sources/Views/NextUpSection.swift` - neue Komponente (NEU)

**Geschätzt:** +180/-20 LoC

## Implementation Details

### 1. Datenmodell-Erweiterung

**LocalTask.swift:**
```swift
/// Marks task as staged for "Next Up" (ready for assignment)
var isNextUp: Bool = false
```

**PlanItem.swift:**
```swift
let isNextUp: Bool

// In init(localTask:):
self.isNextUp = localTask.isNextUp
```

### 2. SyncEngine-Erweiterung

```swift
func updateNextUp(itemID: String, isNextUp: Bool) throws {
    guard let task = try findTask(byID: itemID) else { return }
    task.isNextUp = isNextUp
    try modelContext.save()
}
```

### 3. NextUpSection Komponente

Horizontaler ScrollView mit Task-Chips oben im BacklogView:
- Zeigt alle Tasks mit `isNextUp == true`
- Tap auf Chip entfernt aus Next Up
- Collapsed wenn leer (nur Hinweistext)

### 4. BacklogView Anpassung

- NextUpSection oben (vor Backlog-Liste)
- "↑" Button an jeder Task-Row zum Hinzufügen zu Next Up
- Tasks mit `isNextUp == true` erscheinen auch in normaler Liste

### 5. TaskAssignmentView Anpassung

- `unscheduledTasks` zeigt nur Tasks mit `isNextUp == true`
- Wenn Task einem Block zugeordnet wird: `isNextUp = false`

## Test Plan

### Automated Tests (TDD RED)

#### Unit Tests (`TimeBoxTests/NextUpTests.swift`)

- [ ] `testLocalTaskIsNextUpDefaultsFalse` - GIVEN new LocalTask WHEN created THEN isNextUp is false
- [ ] `testPlanItemPreservesIsNextUp` - GIVEN LocalTask with isNextUp=true WHEN PlanItem created THEN isNextUp is true
- [ ] `testSyncEngineUpdateNextUp` - GIVEN task WHEN updateNextUp(true) THEN task.isNextUp is true

#### UI Tests (`TimeBoxUITests/NextUpUITests.swift`)

- [ ] `testNextUpSectionExists` - GIVEN BacklogView WHEN displayed THEN NextUpSection is visible
- [ ] `testAddToNextUpButton` - GIVEN task in backlog WHEN tap ↑ button THEN task appears in NextUpSection
- [ ] `testTaskAssignmentShowsOnlyNextUp` - GIVEN tasks with isNextUp=true WHEN open Zuordnen THEN only those tasks visible

### Manual Tests

- [ ] Task zu Next Up hinzufügen (↑ Button)
- [ ] Task aus Next Up entfernen (Chip antippen)
- [ ] Mehrere Tasks in Next Up → alle im Zuordnen-Tab sichtbar
- [ ] Task einem Block zuordnen → verschwindet aus Next Up

## Acceptance Criteria

- [x] `isNextUp` Property in LocalTask und PlanItem vorhanden
- [x] NextUpSection im BacklogView oben sichtbar
- [x] Tasks können per Button zu Next Up hinzugefügt werden
- [x] Tasks können aus Next Up entfernt werden
- [x] Zuordnen-Tab zeigt nur Next Up Tasks
- [x] Nach Zuordnung zu Block: Task verlässt Next Up
- [x] Build erfolgreich, keine neuen Test-Failures (109 Tests bestanden)

## User Flow

```
1. Backlog öffnen
   └→ Tasks durchsuchen (verschiedene Views)
   └→ ↑ Button für "Das mache ich als nächstes"

2. Next Up Section
   └→ Zeigt ausgewählte Tasks
   └→ Tap zum Entfernen

3. Zuordnen-Tab
   └→ Nur Next Up Tasks verfügbar
   └→ In Blöcke ziehen

4. Nach Zuordnung
   └→ Task automatisch aus Next Up entfernt
```

## Changelog

- 2026-01-18: Initial spec created based on approved concept
