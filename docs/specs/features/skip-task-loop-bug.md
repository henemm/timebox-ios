# Bug Fix: Skip Task Loop Bug

## Bug ID: Bug 15

## Problem

When a Focus Block has only 1 task and the user taps "Überspringen" (skip), the same task restarts instead of ending the block.

**Root Cause:**
```swift
// In skipTask():
updatedTaskIDs.remove(at: index)
updatedTaskIDs.append(taskID)  // With 1 task: array unchanged!
```

With only 1 task, moving it to the "end" results in the same array. The next iteration shows the same task.

## Solution

Before moving the task to the end, check if this is the last remaining (non-completed) task. If so, add it to `completedTaskIDs` instead of moving it.

**Semantically:** "Skip last task" = "I don't want to do this task" = effectively done/skipped.

This triggers the existing `allTasksCompletedView` which shows "Alle Tasks erledigt!" with option to start Sprint Review.

## Implementation

**File:** `Sources/Views/FocusLiveView.swift`

**Change in `skipTask()` function:**

```swift
private func skipTask(taskID: String, block: FocusBlock) {
    NotificationService.cancelTaskNotification(taskID: taskID)

    Task {
        do {
            let tasks = tasksForBlock(block)
            let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }

            // NEW: If this is the last remaining task, mark as completed instead of looping
            if remainingTasks.count == 1 && remainingTasks.first?.id == taskID {
                // Treat "skip last task" as "complete" to end the block
                var updatedCompletedIDs = block.completedTaskIDs
                updatedCompletedIDs.append(taskID)

                // Preserve time spent
                var updatedTaskTimes = block.taskTimes
                if let startTime = taskStartTime {
                    let secondsSpent = Int(Date().timeIntervalSince(startTime))
                    updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: block.taskIDs,  // Keep order unchanged
                    completedTaskIDs: updatedCompletedIDs,
                    taskTimes: updatedTaskTimes
                )
            } else {
                // Original logic: move to end of queue
                var updatedTaskIDs = block.taskIDs
                if let index = updatedTaskIDs.firstIndex(of: taskID) {
                    updatedTaskIDs.remove(at: index)
                    updatedTaskIDs.append(taskID)
                }

                var updatedTaskTimes = block.taskTimes
                if let startTime = taskStartTime {
                    let secondsSpent = Int(Date().timeIntervalSince(startTime))
                    updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: updatedTaskIDs,
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: updatedTaskTimes
                )
            }

            skipFeedback.toggle()
            lastOverdueReminderTime = nil
            taskStartTime = nil
            lastTaskID = nil
            await loadData()

            if let updatedBlock = activeBlock {
                updateLiveActivity(for: updatedBlock)
            }
        } catch {
            errorMessage = "Task konnte nicht übersprungen werden."
        }
    }
}
```

## Test Plan

### UI Test (TDD RED → GREEN)

**File:** `FocusBloxUITests/SkipTaskLoopUITests.swift`

```swift
func testSkipLastTaskEndsBlock() throws {
    // Setup: Create Focus Block with 1 task
    // Action: Tap "Überspringen"
    // Assert: "Alle Tasks erledigt!" view is shown, NOT the same task again

    // Verify by checking for:
    let completedView = app.staticTexts["Alle Tasks erledigt!"]
    XCTAssertTrue(completedView.waitForExistence(timeout: 5))
}
```

### Expected Behavior After Fix

| Scenario | Before Fix | After Fix |
|----------|------------|-----------|
| 1 task, skip | Same task restarts (loop) | "Alle Tasks erledigt!" shown |
| 2 tasks, skip first | Second task shown | Second task shown (unchanged) |
| 2 tasks, skip both | Loop on last task | "Alle Tasks erledigt!" after 2nd skip |

## Affected Files

| File | Change |
|------|--------|
| `Sources/Views/FocusLiveView.swift` | Modify `skipTask()` function |
| `FocusBloxUITests/SkipTaskLoopUITests.swift` | NEW - UI test |

## Scope

- **LoC Changed:** ~30 lines (refactor within existing function)
- **Risk:** Low - isolated change in one function
- **Side Effects:** None - only affects skip behavior for last task
