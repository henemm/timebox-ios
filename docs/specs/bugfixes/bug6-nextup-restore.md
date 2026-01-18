---
entity_id: bug6-nextup-restore
type: bugfix
created: 2026-01-18
updated: 2026-01-18
status: draft
version: "1.0"
tags: [bugfix, next-up, task-assignment]
---

# Bug 6: Task kehrt nicht zu Next Up zurueck nach Block-Entfernung

## Approval

- [ ] Approved

## Problem Description

Wenn ein Task im "Zuordnen"-Tab aus einem Focus Block entfernt wird (via X-Button), verschwindet er komplett aus der UI. Er erscheint weder im Block noch in der "Next Up" Section.

**Erwartetes Verhalten:** Task sollte nach Entfernung aus dem Block automatisch wieder in der "Next Up" Section erscheinen.

## Root Cause Analysis

### Datenfluss beim Zuordnen (funktioniert korrekt)

1. User zieht Task von "Next Up" in Focus Block
2. `assignTaskToBlock()` wird aufgerufen (Zeile 168-192)
3. Task wird zu `block.taskIDs` hinzugefuegt (EventKit)
4. **Zeile 185:** `syncEngine.updateNextUp(itemID: taskID, isNextUp: false)`
5. Task erscheint im Block, verschwindet aus "Next Up" - KORREKT

### Datenfluss beim Entfernen (Bug)

1. User klickt X-Button auf Task im Block
2. `removeTaskFromBlock()` wird aufgerufen (Zeile 195-213)
3. Task wird aus `block.taskIDs` entfernt (EventKit)
4. **FEHLT:** `syncEngine.updateNextUp(itemID: taskID, isNextUp: true)`
5. `loadData()` filtert: `unscheduledTasks = syncedTasks.filter { $0.isNextUp && ... }`
6. Task hat `isNextUp = false` → wird nicht angezeigt - BUG

### Code-Vergleich

```swift
// assignTaskToBlock() - Zeile 168-192
private func assignTaskToBlock(taskID: String, block: FocusBlock) {
    Task {
        do {
            // ... EventKit update ...

            // Remove from Next Up after assignment
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: taskID, isNextUp: false)  // <-- VORHANDEN

            await loadData()
            assignmentFeedback.toggle()
        } catch { ... }
    }
}

// removeTaskFromBlock() - Zeile 195-213
private func removeTaskFromBlock(taskID: String, block: FocusBlock) {
    Task {
        do {
            // ... EventKit update ...

            // FEHLT: try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)

            await loadData()
            assignmentFeedback.toggle()
        } catch { ... }
    }
}
```

## Fix Specification

### Changes Required

**File:** `TimeBox/Sources/Views/TaskAssignmentView.swift`

**Location:** `removeTaskFromBlock()` function, Zeilen 195-213

**Change:** Nach dem EventKit-Update (Zeile 205) und vor `loadData()` hinzufuegen:

```swift
// Restore to Next Up after removal from block
let taskSource = LocalTaskSource(modelContext: modelContext)
let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)
```

### Expected Result After Fix

```swift
private func removeTaskFromBlock(taskID: String, block: FocusBlock) {
    Task {
        do {
            var updatedTaskIDs = block.taskIDs
            updatedTaskIDs.removeAll { $0 == taskID }

            try eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: updatedTaskIDs,
                completedTaskIDs: block.completedTaskIDs
            )

            // Restore to Next Up after removal from block
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)

            await loadData()
            assignmentFeedback.toggle()
        } catch {
            errorMessage = "Task konnte nicht entfernt werden."
        }
    }
}
```

## Test Plan

### Unit Test (TDD RED Phase)

**File:** `TimeBox/TimeBoxTests/NextUpTests.swift`

```swift
/// Test: removeTaskFromBlock should restore isNextUp to true
/// GIVEN: Task with isNextUp = false (assigned to block)
/// WHEN: Task is removed from block
/// THEN: task.isNextUp should be true
func test_removeTaskFromBlock_restoresNextUp() throws {
    // Arrange
    let task = LocalTask(title: "Test Task")
    task.isNextUp = false  // Simulates assigned state
    modelContext.insert(task)
    try modelContext.save()

    // Act
    let taskSource = LocalTaskSource(modelContext: modelContext)
    let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
    try syncEngine.updateNextUp(itemID: task.id, isNextUp: true)

    // Assert
    XCTAssertTrue(task.isNextUp, "Task.isNextUp should be true after removal from block")
}
```

### Manual Test Steps

1. Oeffne den "Zuordnen"-Tab
2. Stelle sicher, dass mindestens ein Task in "Next Up" ist
3. Ziehe den Task in einen Focus Block
4. Verifiziere: Task erscheint im Block, verschwindet aus "Next Up"
5. Klicke den X-Button neben dem Task im Block
6. **Erwartung:** Task erscheint wieder in "Next Up"
7. **Aktuell (Bug):** Task verschwindet komplett

## Impact Assessment

- **Scope:** 1 Datei, ~4 Zeilen Code
- **Risk:** Niedrig - symmetrische Aenderung zu existierender Logik
- **Side Effects:** Keine - verwendet existierende `SyncEngine.updateNextUp()` Methode

## Changelog

- 2026-01-18: Bug analysiert und Spec erstellt
