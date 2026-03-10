---
entity_id: deferred_completion
type: module
created: 2026-03-10
updated: 2026-03-10
status: draft
version: "1.0"
tags: [completion, animation, ux]
---

# DeferredCompletionController

## Approval

- [ ] Approved

## Purpose

Provides a 3-second visual delay when marking tasks as complete. The filled checkbox is shown immediately, the task stays visible in the list, and after ~3 seconds the data is committed and the task animates out. This gives users visual confirmation of their action while allowing them to continue working immediately.

## Source

- **File:** `Sources/Services/DeferredCompletionController.swift`
- **Identifier:** `DeferredCompletionController`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| DeferredSortController | Pattern | Same architectural pattern (freeze + timer + unfreeze) |
| SyncEngine | Service | Called after timer to actually persist completion |
| BacklogView | View | iOS consumer |
| ContentView (macOS) | View | macOS consumer |
| BacklogRow | View | Shows pending completion visual state |
| MacBacklogRow | View | Shows pending completion visual state |

## Implementation Details

### DeferredCompletionController (@MainActor @Observable)

```swift
@MainActor @Observable
final class DeferredCompletionController {
    // Set of task IDs currently in "pending completion" visual state
    private(set) var pendingIDs: Set<String> = []

    // Per-task timers (each task has its own 3-sec countdown)
    private var timers: [String: Task<Void, Never>] = [:]

    // Schedule a deferred completion for a task
    func scheduleCompletion(id: String, onCommit: @escaping () async -> Void)

    // Cancel a pending completion (undo during delay)
    func cancelCompletion(id: String)

    // Check if a task is pending completion
    func isPending(_ id: String) -> Bool

    // Flush all pending completions immediately (app background)
    func flushAll()
}
```

### scheduleCompletion flow:
1. Add `id` to `pendingIDs`
2. Cancel existing timer for `id` (if any)
3. Start new `Task` with 3-second sleep
4. After sleep: call `onCommit()`, remove from `pendingIDs`, cancel timer

### cancelCompletion flow:
1. Cancel timer for `id`
2. Remove `id` from `pendingIDs`
3. Remove timer entry

### flushAll flow:
1. Cancel all timers
2. For each pending ID: call stored `onCommit` immediately
3. Clear `pendingIDs` and `timers`

### View Integration (iOS BacklogView)

```swift
// In completeTask():
// OLD: syncEngine.completeTask(itemID:) → loadTasks()
// NEW:
deferredCompletion.scheduleCompletion(id: item.id) {
    let taskSource = LocalTaskSource(modelContext: modelContext)
    let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
    try? syncEngine.completeTask(itemID: item.id)
    await loadTasks()
}
completeFeedback.toggle()  // Haptic immediately
```

### View Integration (macOS ContentView)

Same pattern. Also applies to `markTasksCompleted(selection)` for batch operations.

### BacklogRow changes

```swift
// New prop:
var isCompletionPending: Bool = false

// Checkbox icon:
Image(systemName: isCompletionPending ? "checkmark.circle.fill" : "circle")
    .foregroundStyle(isCompletionPending ? .green : .secondary)
```

### MacBacklogRow changes

```swift
// New prop:
var isCompletionPending: Bool = false

// Checkbox icon already handles isCompleted, add pending:
let showCompleted = task.isCompleted || isCompletionPending
Image(systemName: showCompleted ? "checkmark.circle.fill" : "circle")
    .foregroundStyle(showCompleted ? .green : .secondary)
// Title strikethrough:
.strikethrough(showCompleted)
```

### Undo Integration

During pending phase (timer active):
- `deferredCompletion.cancelCompletion(id:)` — instant "undo", no data change needed

After commit (timer fired):
- Existing `TaskCompletionUndoService` handles this (Shake/Cmd+Z)

### scenePhase handling

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background {
        deferredCompletion.flushAll()
    }
}
```

## Expected Behavior

- **Input:** User taps completion checkbox on any task row
- **Output:**
  1. Immediately: filled green checkbox + haptic feedback
  2. 3 seconds later: task data saved, task animates out of list
  3. If recurring: new instance appears after task removal
- **Side effects:**
  - CloudKit sync triggered after 3-sec commit (not during delay)
  - RecurrenceService creates next instance after 3-sec commit
  - TaskCompletionUndoService snapshot taken at commit time

## Known Limitations

- If app is force-killed during 3-sec delay, task is NOT marked complete (acceptable: same risk as DeferredSortController)
- FocusBlock completion (during active sprint) does NOT use delay — different UX context
- Notification/Siri completion does NOT use delay — background actions
- TaskInspector (macOS) has pre-existing direct isCompleted write — out of scope, separate ticket

## Changelog

- 2026-03-10: Initial spec created
