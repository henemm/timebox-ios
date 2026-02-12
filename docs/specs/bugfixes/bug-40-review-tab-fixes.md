---
entity_id: bug-40-review-tab-fixes
type: bugfix
created: 2026-02-12
status: draft
workflow: bug-40-review-tab-fixes
---

# Bug 40: Review Tab zeigt erledigte Tasks nicht

## Approval

- [ ] Approved by PO

## Problem

1. macOS Review Tab zeigt "Noch keine Tasks erledigt" obwohl Tasks im FocusBlock erledigt wurden
2. Kategorie-Kalendereintraege erscheinen nicht im Review

## Root Cause

1. `MacReviewView` nutzt `@Query LocalTask { $0.isCompleted }` (SwiftData). Aber `markTaskComplete()` in FocusLiveView/MacFocusView setzt nur `FocusBlock.completedTaskIDs` (Kalender-Event), NICHT `LocalTask.isCompleted`.
2. Kategorie-Events werden zwar geladen, aber nur in der Weekly-View verarbeitet.

## Scope

- **Files:** 3 Dateien
- **Estimated:** ~30 LoC

## Implementation Details

### Fix 1: LocalTask.isCompleted synchronisieren

`FocusLiveView.swift` + `MacFocusView.swift`: In `markTaskComplete()` auch `LocalTask.isCompleted = true` setzen:
```swift
// Nach FocusBlock-Update auch SwiftData aktualisieren
let fetchDescriptor = FetchDescriptor<LocalTask>()
if let localTasks = try? modelContext.fetch(fetchDescriptor),
   let task = localTasks.first(where: { $0.id == taskID }) {
    task.isCompleted = true
    try? modelContext.save()
}
```

### Fix 2: DayReview mit FocusBlock-Daten (macOS)

`MacReviewView.swift`: `DayReviewContent` erhaelt auch FocusBlocks und zeigt Block-basierte Completions.

### Betroffene Dateien

1. `Sources/Views/FocusLiveView.swift` - markTaskComplete() + LocalTask sync
2. `FocusBloxMac/MacFocusView.swift` - markTaskComplete() + LocalTask sync
3. `FocusBloxMac/MacReviewView.swift` - DayReview mit FocusBlock-Daten

## Test Plan

### Unit Tests

- [ ] Test 1: LocalTask.isCompleted nach markTaskComplete
- [ ] Test 2: Review zeigt completedTaskIDs-basierte Tasks

## Acceptance Criteria

- [ ] Review Tab zeigt erledigte Tasks korrekt (macOS + iOS)
- [ ] Build kompiliert ohne Errors
- [ ] Alle Tests gruen
