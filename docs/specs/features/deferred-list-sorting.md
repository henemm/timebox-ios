---
entity_id: deferred-list-sorting
type: feature
created: 2026-03-03
updated: 2026-03-03
status: draft
version: "1.0"
tags: [backlog, sorting, ux, ios, macos]
---

# Feature Spec: Deferred List Sorting

**Status:** DRAFT
**Datum:** 2026-03-03
**Workflow:** feature-deferred-list-sorting
**Plattformen:** iOS + macOS

## Approval

- [ ] Approved

---

## Problem

When users tap a badge (importance, urgency, category, duration) in a sorted list view, the list re-sorts **immediately**. This causes the tapped item to jump to a different position before the user can tap again. The carousel behavior of importance (cycles 1→2→3) is practically unusable because the item disappears after the first tap.

## Purpose

Defer list re-sorting by 3 seconds after the last badge tap. Data is saved immediately (no integrity loss), but the visual order stays frozen until the timer expires. A 2pt accent-colored border marks items that have pending sort changes.

---

## Behavior Contract

1. **Badge tap** — data saved immediately to SwiftData (no deferred writes)
2. **Item stays** at its current position in the list (no immediate re-sort)
3. **Border appears** — accent-colored 2pt `RoundedRectangle` stroke on the changed item
4. **3-second timer** starts; any further badge tap (same or different item) **resets** the timer to 3s
5. **Multiple items** can be pending simultaneously; each shows its own border
6. **After timeout:**
   - Border fades out (0.3s easeOut)
   - Pause (0.2s)
   - List re-sorts with `.spring` animation
7. Applies to **all sorted ListViews** on **both platforms**

---

## Source

- **File (iOS):** `Sources/Views/BacklogView.swift`
- **File (iOS Row):** `Sources/Views/BacklogRow.swift`
- **File (macOS):** `FocusBloxMac/ContentView.swift`
- **File (macOS Row):** `FocusBloxMac/MacBacklogRow.swift`
- **Tests:** `FocusBloxUITests/DeferredSortUITests.swift`

---

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| BacklogView | view | iOS list host — owns deferred sort state |
| BacklogRow | view | iOS row — renders pending border |
| ContentView (macOS) | view | macOS list host — owns snapshot + deferred sort state |
| MacBacklogRow | view | macOS row — renders pending border |
| LocalTask | model | Task data read/written by badge taps |
| SyncEngine | service | Persists badge-tap changes immediately |
| TaskPriorityScoringService | service | Drives sort order after deferred re-sort (not modified) |

---

## Implementation Details

### iOS — BacklogView.swift

**New state:**

```swift
@State private var pendingResortIDs: Set<String> = []
@State private var resortTimer: Task<Void, Never>? = nil
```

**New helper:**

```swift
private func scheduleDeferred(afterSaving id: String) {
    pendingResortIDs.insert(id)
    resortTimer?.cancel()
    resortTimer = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            pendingResortIDs.removeAll()
        }
        try? await Task.sleep(for: .seconds(0.2))
        guard !Task.isCancelled else { return }
        withAnimation(.spring) {
            refreshLocalTasks()
        }
    }
}
```

**Call-site change:** Badge-tap callbacks that currently call `refreshLocalTasks()` directly are replaced with `scheduleDeferred(afterSaving: task.id)`. Approximately 8 call sites.

**Row rendering:** `isPendingResort: pendingResortIDs.contains(task.id)` passed to each `BacklogRow`.

---

### macOS — ContentView.swift

**New state:**

```swift
@State private var pendingResortIDs: Set<UUID> = []
@State private var displaySnapshot: [LocalTask]? = nil
@State private var resortTimer: Task<Void, Never>? = nil
```

**Snapshot logic:** On the first badge tap in a deferred window, snapshot the current `regularFilteredTasks` order:

```swift
private func scheduleDeferred(afterSaving id: UUID) {
    if displaySnapshot == nil {
        displaySnapshot = regularFilteredTasks
    }
    pendingResortIDs.insert(id)
    resortTimer?.cancel()
    resortTimer = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            pendingResortIDs.removeAll()
        }
        try? await Task.sleep(for: .seconds(0.2))
        guard !Task.isCancelled else { return }
        withAnimation(.spring) {
            displaySnapshot = nil   // falls back to live @Query with new sort
        }
    }
}
```

**List source:** Render from `displaySnapshot ?? regularFilteredTasks` so the frozen snapshot preserves old order during the deferred window.

**Snapshot invalidation:** Clear `displaySnapshot` (and cancel timer) on task create, delete, or complete to avoid stale snapshots.

**Call-site change:** ~4 badge-tap call sites updated.

---

### Shared Row Change — BacklogRow.swift + MacBacklogRow.swift

**New parameter:**

```swift
isPendingResort: Bool
```

**Border overlay:**

```swift
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .strokeBorder(
            isPendingResort ? Color.accentColor : .clear,
            lineWidth: 2
        )
        .animation(.easeOut(duration: 0.3), value: isPendingResort)
)
```

---

## Expected Behavior

- **Input:** User taps a badge (importance / urgency / category / duration) on a task in a sorted list view
- **Output:** Data updated immediately; item stays in place; accent border appears; list re-sorts 3s after the last tap
- **Side effects:** `pendingResortIDs` set grows/shrinks; timer Task is created/cancelled in memory; no additional persistence

---

## Scope

| Change | LoC |
|--------|-----|
| BacklogView.swift — +2 state, 1 helper, ~8 call-site changes | +40 |
| BacklogRow.swift — +1 param, border overlay | +12 |
| ContentView.swift — +3 state, snapshot logic, 1 helper, ~4 call-sites | +60 |
| MacBacklogRow.swift — +1 param, border overlay | +12 |
| DeferredSortUITests.swift — 4 test cases (new file) | +55 |
| Deletions / simplifications | -10 |
| **Total** | **~+170 / -10 LoC** |

5 files, no new dependencies, no Info.plist changes.

---

## NOT In Scope

- **NextUpSection** — sorts by drag order, not attributes
- **MiniBacklogView** — horizontal carousel, different UX paradigm
- Changes to `TaskPriorityScoringService`

---

## Test Plan

File: `FocusBloxUITests/DeferredSortUITests.swift`

| # | Test | Assertion |
|---|------|-----------|
| 1 | `testImportanceTapDoesNotImmediatelyResort` | After badge tap, item is still at original index within 1s |
| 2 | `testPendingBorderAppearsAfterBadgeTap` | Border overlay with accessibilityIdentifier visible after tap |
| 3 | `testTimerResetOnSecondTap` | Second tap within 3s: item still at original position at t=3.5s; re-sorted at t=7s |
| 4 | `testResortHappensAfterThreeSeconds` | Item at original index at t=2s; item at new index at t=4.5s |

Test timing uses `XCTNSPredicateExpectation` to avoid flakiness.

---

## Risks

| Risk | Mitigation |
|------|------------|
| macOS snapshot staleness if task created/deleted/completed during deferred window | Clear `displaySnapshot` and cancel timer on create, delete, complete |
| CloudKit remote refresh arrives during timer | Cancel timer and clear snapshot on `NSPersistentStoreRemoteChange`; let remote data win |
| UI test timing sensitivity (3s waits) | Use `XCTNSPredicateExpectation` with generous timeout; avoid `sleep()` in tests |
| iOS badge-tap call sites missed (item still jumps) | Grep all `refreshLocalTasks()` call sites in BacklogView before implementation |

---

## Known Limitations

- macOS snapshot covers only the currently visible filter; switching filters during the deferred window clears the snapshot
- Timer is per-view, not per-window: opening a second window on macOS starts an independent deferred window

---

## Changelog

- 2026-03-03: Initial spec created
