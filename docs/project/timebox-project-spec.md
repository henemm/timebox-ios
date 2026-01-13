# PROJECT SPECIFICATION: TimeBox (iOS Native)

> Ursprüngliche Anforderungen von Henning - Referenzdokument

## 1. SYSTEM CONTEXT & TECH STACK
- **Role:** Expert iOS Architect building a production-grade app.
- **Platform:** iOS 17+
- **Language:** Swift 6
- **UI Framework:** SwiftUI (No Storyboards, No UIKit unless strictly necessary).
- **Architecture:** MVVM + Repository Pattern + Dependency Injection.
- **Persistence Strategy (Hybrid):**
  - **Remote Source of Truth:** Apple EventKit (Reminders & Calendar).
  - **Local Metadata:** SwiftData (for storing 'sortOrder' and 'duration' which Apple APIs lack).

## 2. CORE CONCEPT
We are building a **Time-Blocking Companion App** for Apple Reminders.
- **Problem:** Apple Reminders lacks manual sorting (ranking) and duration fields.
- **Solution:** We pull reminders from Apple, augment them locally with a user-defined sort order and duration, and then drag-and-drop them into free slots in the Apple Calendar.

## 3. DOMAIN MODEL SPECS (The "Shadow Database" Pattern)

### A. SwiftData Model: `TaskMetadata`
This persists the data that Apple doesn't support.
```swift
@Model
class TaskMetadata {
    var reminderID: String // Matches EKReminder.calendarItemIdentifier
    var sortOrder: Int     // Allows manual ranking (0, 1, 2...)
    var manualDuration: Int? // In minutes (e.g., 15, 30, 60)

    init(reminderID: String, sortOrder: Int) { ... }
}
```

### B. View Model: `PlanItem` (Non-Persistent)
The unified object used in the UI.

**Properties:**
- `id`: UUID
- `title`: String (from EKReminder)
- `isCompleted`: Bool (from EKReminder)
- `priority`: Int (mapped from EKReminder.priority)
- `tags`: [String] (parsed from Title/Notes, e.g. "#30min")
- `effectiveDuration`: Int (Logic: Check TaskMetadata.manualDuration -> IF nil, check Regex in Title for #(\d+)min -> IF nil, default to 15).
- `rank`: Int (from TaskMetadata.sortOrder)

## 4. SERVICE LAYER SPECS

### Service 1: `EventKitRepository`
**Responsibility:** Sync with Apple.

**Functions:**
- `requestAccess()`
- `fetchReminders()` -> Returns [EKReminder]
- `fetchCalendarEvents(for: Date)` -> Returns [EKEvent]
- `scheduleTask(item: PlanItem, start: Date)` -> Creates EKEvent, marks EKReminder as complete.

### Service 2: `SyncEngine` (The Brain)
**Responsibility:** Merge Apple Data with SwiftData.

**Logic:**
1. Fetch all EKReminders.
2. Fetch all TaskMetadata.
3. Create PlanItem objects.
4. If a Reminder is new, create default TaskMetadata (append to end of list).
5. If a Reminder was deleted in Apple app, delete orphaned TaskMetadata.

**Return:** List of PlanItem sorted by rank (Ascending).

## 5. UI/UX SPECIFICATIONS (Critical)

### View A: `BacklogView` (The Sorting Table)
- **Style:** List with `.plain` style.
- **Visuals:**
  - Each row shows Title and a "Duration Badge" (e.g., a capsule showing "30m").
  - If duration is missing/default, highlight badge in yellow.
- **Interaction:**
  - Manual Reordering: Users must be able to drag rows up/down.
  - Action: On move, update `TaskMetadata.sortOrder` for all affected items and save context immediately.
  - Feedback: Use `.sensoryFeedback(.impact, trigger: ...)` on drop.

### View B: `PlanningView` (The Time-Blocker)
- **Layout:** Split View (Calendar Day View on top/left, Backlog List on bottom/right).
- **Proportionality:** Task rows in the list should visually approximate their duration height relative to the calendar timeline.
- **Drag & Drop:**
  - Enable `.draggable` on Backlog items.
  - Enable `.dropDestination` on the Calendar Timeline.
  - Snap Logic: When dropping a 30m task into a 60m gap, snap to start time.

## 6. EXECUTION PLAN (Step-by-Step)

### STEP 1: The Foundation
1. Set up the SwiftData model (`TaskMetadata`).
2. Implement `EventKitRepository` (Permissions + Fetch).
3. Implement the `SyncEngine` to merge data and print a debug list of PlanItems to the console.
4. **Goal:** Prove we can read Reminders and link them to local SortOrders.
5. **Do not implement UI yet.**

### STEP 2: BacklogView (TBD)

### STEP 3: PlanningView (TBD)

---

*Dieses Dokument dient als Referenz. Einzelne Entities werden in `docs/specs/` als separate Specs angelegt.*
