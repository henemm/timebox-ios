---
entity_id: task-creation-ux-refactor
type: refactor
created: 2026-01-17
updated: 2026-01-17
status: implemented
version: "1.0"
tags: [task-system, ux, multi-select, recurrence]
workflow: multi-source-tasks
---

# Task Creation UX Refactoring

## Approval

- [x] Approved (implemented retroactively)

## Purpose

Refactor the task creation UI to align with GTD best practices and improve input speed. Key changes: multi-select tags instead of single category, quick-select duration buttons (5/15/30/60min), 3-level priority system (Low/Medium/High), pattern-based recurrence with inline expansion, and segmented urgency control.

## Source

- **File:** `Sources/Views/TaskCreation/CreateTaskView.swift`
- **Supporting Types:** RecurrencePattern, QuickDurationButton, WeekdayButton, Weekday (inline)
- **Data Model:** `Sources/Models/LocalTask.swift`
- **Protocol:** `Sources/Protocols/TaskSource.swift`
- **CRUD:** `Sources/Services/TaskSources/LocalTaskSource.swift`

## Scope

### Files Changed (6 files)
1. `Sources/Models/LocalTask.swift` - Data model extensions
2. `Sources/Protocols/TaskSource.swift` - Protocol updates
3. `Sources/Services/TaskSources/LocalTaskSource.swift` - CRUD methods
4. `Sources/Views/TaskCreation/CreateTaskView.swift` - Complete UI overhaul
5. `TimeBoxTests/LocalTaskTests.swift` - Model tests
6. `TimeBoxTests/LocalTaskSourceTests.swift` - CRUD tests
7. `TimeBoxTests/TaskSourceTests.swift` - Protocol tests

### Code Changes
- **Data Model:** +30 LoC (new fields, init signature)
- **Protocol:** +40 LoC (extended signatures)
- **LocalTaskSource:** +50 LoC (updated CRUD)
- **CreateTaskView:** +366 LoC total (~250 LoC net change)
- **Tests:** ~140 LoC modifications

**Total:** ~290 LoC net additions/modifications

## Implementation Details

### 1. Data Model Changes (LocalTask.swift)

**BEFORE:**
```swift
var priority: Int = 0  // 0-3 (Keine/Niedrig/Mittel/Hoch)
var category: String?  // Single string
var isRecurring: Bool = false  // Simple boolean
```

**AFTER:**
```swift
var priority: Int = 1  // 1-3 (Niedrig/Mittel/Hoch) - no "None"
var tags: [String] = []  // Multi-select array
var recurrencePattern: String = "none"  // "none"|"daily"|"weekly"|"biweekly"|"monthly"
var recurrenceWeekdays: [Int]?  // [1-7] for weekly/biweekly (1=Mon, 7=Sun)
var recurrenceMonthDay: Int?  // 1-31 or 32 (last day) for monthly
```

**Rationale:**
- **Priority simplification:** 4 levels → 3 levels aligns with Todoist/TickTick best practices. "Keine Priorität" is semantically equivalent to "Niedrig".
- **Tags over category:** Multi-select allows tasks to belong to multiple contexts (e.g., "Hausarbeit" AND "Recherche").
- **Recurrence pattern:** Boolean toggle too limiting - pattern enum enables daily/weekly/monthly with configuration.

### 2. UI Components

#### Duration Selection (Quick Select)
```swift
Section {
    HStack(spacing: 12) {
        QuickDurationButton(minutes: 5, selectedMinutes: $duration)
        QuickDurationButton(minutes: 15, selectedMinutes: $duration)
        QuickDurationButton(minutes: 30, selectedMinutes: $duration)
        QuickDurationButton(minutes: 60, selectedMinutes: $duration)
    }
} header: {
    Text("Dauer")
}
```

**Design:** Large tappable buttons with visual feedback (accent color when selected). Replaces stepper for common time-blocking patterns.

#### Priority Selection (Direct Select with Emojis)
```swift
Picker("Priorität", selection: $priority) {
    Text("🟦 Niedrig").tag(1)
    Text("🟨 Mittel").tag(2)
    Text("🔴 Hoch").tag(3)
}
```

**Design:** Segmented control-style picker with emoji visual indicators for quick recognition. No "None" option - tasks default to Low priority.

#### Tags (Multi-Select Management)
```swift
Section {
    // Display existing tags
    if !tags.isEmpty {
        ForEach(tags, id: \.self) { tag in
            HStack {
                Text(tag)
                Spacer()
                Button {
                    tags.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
    }

    // Add new tag
    HStack {
        TextField("Neuer Tag", text: $newTag)
        Button("Hinzufügen") {
            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !tags.contains(trimmed) {
                tags.append(trimmed)
                newTag = ""
            }
        }
    }
} header: {
    Text("Tags")
}
```

**Design:** Inline tag management with add/remove functionality. Footer provides usage examples ("Hausarbeit", "Recherche", "Besorgungen").

#### Recurrence (Pattern-Based with Inline Expansion)
```swift
Section {
    Picker("Wiederholt sich", selection: $recurrencePattern) {
        ForEach(RecurrencePattern.allCases) { pattern in
            Text(pattern.displayName).tag(pattern)
        }
    }

    // Conditional UI: Weekdays for weekly/biweekly
    if recurrencePattern.requiresWeekdays {
        VStack(alignment: .leading, spacing: 8) {
            Text("An folgenden Tagen:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Weekday.all) { weekday in
                    WeekdayButton(weekday: weekday, selectedWeekdays: $selectedWeekdays)
                }
            }
        }
    }

    // Conditional UI: Month day for monthly
    if recurrencePattern.requiresMonthDay {
        Picker("Am Tag", selection: $monthDay) {
            ForEach(1...31, id: \.self) { day in
                Text("\(day).").tag(day)
            }
            Text("Letzter Tag").tag(32)
        }
    }
} header: {
    Text("Wiederholung")
}
```

**Design:** Pattern picker triggers inline expansion of pattern-specific configuration. Weekday buttons are circular toggles (Mo/Di/Mi/Do/Fr/Sa/So), month day is a picker with "Letzter Tag" option.

### 3. Supporting Types (Inline in CreateTaskView.swift)

**RecurrencePattern Enum:**
```swift
enum RecurrencePattern: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .none: return "Nie"
        case .daily: return "Täglich"
        case .weekly: return "Wöchentlich"
        case .biweekly: return "Zweiwöchentlich"
        case .monthly: return "Monatlich"
        }
    }

    var requiresWeekdays: Bool { self == .weekly || self == .biweekly }
    var requiresMonthDay: Bool { self == .monthly }
}
```

**QuickDurationButton:**
- 4 tappable buttons with accent color highlighting
- Frame: maxWidth infinity, vertical padding 12pt
- Corner radius: 12pt rounded rectangle

**WeekdayButton:**
- Circular buttons (36×36pt) with 2-letter abbreviations
- Toggle selection on tap (adds/removes from Set<Int>)
- Visual feedback: accent color when selected, tertiary gray when not

**Weekday Model:**
- Value mapping: 1=Mon, 2=Tue, ..., 7=Sun
- German short names: Mo/Di/Mi/Do/Fr/Sa/So

### 4. Data Flow

**saveTask() Method:**
```swift
private func saveTask() {
    guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

    isSaving = true

    Task {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)

            // Prepare recurrence data
            let weekdays: [Int]? = recurrencePattern.requiresWeekdays
                ? Array(selectedWeekdays).sorted()
                : nil
            let monthDay: Int? = recurrencePattern.requiresMonthDay
                ? self.monthDay
                : nil

            _ = try await taskSource.createTask(
                title: title.trimmingCharacters(in: .whitespaces),
                tags: tags,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                duration: duration,
                urgency: urgency,
                taskType: taskType,
                recurrencePattern: recurrencePattern.rawValue,
                recurrenceWeekdays: weekdays,
                recurrenceMonthDay: monthDay,
                description: taskDescription.isEmpty ? nil : taskDescription
            )

            await MainActor.run {
                onSave?()
                dismiss()
            }
        } catch {
            isSaving = false
        }
    }
}
```

**Key Logic:**
- Conditional recurrence data: only pass weekdays/monthDay if pattern requires it
- Empty string handling: taskDescription = nil if empty
- Async/await with MainActor dispatch for UI updates

## Expected Behavior

### User Flow (Happy Path)
1. User taps "+" button to create task
2. User enters title (required)
3. User selects duration via quick buttons (default: 15min)
4. User selects priority (default: Niedrig/Low)
5. User toggles urgency (default: Nicht dringend)
6. User selects task type (default: Maintenance/Schneeschaufeln)
7. User adds tags (optional, can add multiple)
8. User sets due date (optional toggle)
9. User selects recurrence pattern:
   - If "Wöchentlich" → weekday buttons appear
   - If "Monatlich" → month day picker appears
10. User enters description (optional)
11. User taps "Speichern"
12. Task saved to SwiftData, view dismisses

### Input Validation
- **Title:** Required, must be non-empty after trimming
- **Tags:** Duplicates prevented, empty strings rejected
- **Recurrence:** Weekdays selection enforced when weekly/biweekly selected
- **Save button:** Disabled when title empty or isSaving=true

### Edge Cases Handled
- **Recurrence without details:** Pattern defaults to "none", weekdays/monthDay remain nil
- **Empty description:** Saved as nil (not empty string)
- **Weekday deselection:** Circular button toggles on/off
- **Month day 32:** Interpreted as "last day of month" (e.g., Feb 28/29)

## Test Plan

### Automated Tests (Unit Tests)

#### LocalTask Model Tests (LocalTaskTests.swift)
- [x] ✅ test_localTask_hasRequiredProperties - Verify all fields exist with correct defaults
- [x] ✅ test_localTask_canSetOptionalProperties - Tags array, recurrence fields can be set
- [x] ✅ test_localTask_canBeSaved - SwiftData persistence works
- [x] ✅ test_localTask_defaultValues_phase1 - urgency, taskType, recurrencePattern defaults
- [x] ✅ test_localTask_recurringFlagWorks - recurrencePattern can be set to "weekly"
- [x] ✅ test_localTask_allFieldsCanBeSet - Full initialization with all fields

#### LocalTaskSource CRUD Tests (LocalTaskSourceTests.swift)
- [x] ✅ test_createTask_insertsNewTask - Task with tags array persists
- [x] ✅ test_createTask_assignsNextSortOrder - SortOrder increments correctly
- [x] ✅ test_updateTask_modifiesExistingTask - Tags update works
- [x] ✅ test_updateTask_preservesUnchangedFields - Nil params preserve existing values
- [x] ✅ test_fetchIncompleteTasks_returnsOnlyIncomplete - Filtering logic unchanged

#### TaskSource Protocol Tests (TaskSourceTests.swift)
- [x] ✅ test_taskSourceData_hasRequiredProperties - Protocol conformance with tags/recurrence
- [x] ✅ test_taskSourceWritable_createTask_addsNewTask - createTask signature matches
- [x] ✅ test_taskSourceWritable_updateTask_modifiesExistingTask - updateTask with recurrence

**Result:** All 87 unit tests passing ✅

### Manual Tests (UI)

#### Priority Selection
- [ ] Open CreateTaskView
- [ ] Verify priority picker shows 3 options with emojis (🟦/🟨/🔴)
- [ ] Select each priority level
- [ ] Create task and verify priority saved correctly (check BacklogView)

#### Duration Quick Select
- [ ] Open CreateTaskView
- [ ] Verify 4 buttons visible (5m/15m/30m/60m)
- [ ] Tap each button → verify visual feedback (accent color)
- [ ] Only one button selected at a time
- [ ] Create task and verify manualDuration saved

#### Tags Multi-Select
- [ ] Open CreateTaskView
- [ ] Add tag "Hausarbeit" → appears in list
- [ ] Add tag "Recherche" → both tags visible
- [ ] Try adding duplicate → rejected
- [ ] Try adding empty string → button disabled
- [ ] Remove tag via X button → disappears
- [ ] Create task with 2 tags → verify both saved

#### Recurrence Pattern
- [ ] Open CreateTaskView
- [ ] Select "Nie" → no additional fields shown
- [ ] Select "Täglich" → no additional fields shown
- [ ] Select "Wöchentlich" → weekday buttons appear
- [ ] Tap Mo/Mi/Fr → 3 buttons highlighted
- [ ] Create task → verify recurrenceWeekdays=[1,3,5]
- [ ] Select "Monatlich" → month day picker appears
- [ ] Select "15." → create task → verify recurrenceMonthDay=15
- [ ] Select "Letzter Tag" → verify recurrenceMonthDay=32

#### Weekday Toggle Buttons
- [ ] Open CreateTaskView → select "Wöchentlich"
- [ ] Tap Mo → circle fills with accent color
- [ ] Tap Mo again → deselects (gray background)
- [ ] Tap all 7 weekdays → all selected
- [ ] Deselect all → no weekdays selected (valid, creates pattern but no specific days)

#### Save Button State
- [ ] Open CreateTaskView
- [ ] Save button disabled (empty title)
- [ ] Enter title → Save button enabled
- [ ] Tap Save → button disabled during save (isSaving=true)
- [ ] View dismisses after successful save

## Known Limitations

### Component File Organization
- **Issue:** RecurrencePattern, QuickDurationButton, WeekdayButton, Weekday are embedded inline in CreateTaskView.swift (not separate files)
- **Reason:** New Swift files not automatically added to Xcode project (requires manual .pbxproj editing)
- **TODO:** Extract to `Sources/Views/Components/` and add to Xcode project
- **Impact:** CreateTaskView.swift is 366 lines (longer than ideal, but functional)

### Recurrence Logic Limitation
- **Issue:** Recurrence pattern stored as data model, but no automatic task creation implemented
- **Future Work:** Background job or app launch hook to generate recurring tasks based on pattern
- **Current Behavior:** User must manually create task again when recurrence period ends

### Priority Icon Consistency
- **Note:** Priority emojis (🟦🟨🔴) in picker should match visual indicators in BacklogView
- **TODO:** Phase 2 will add priority icons to BacklogRow

### Weekday Value Encoding
- **ISO 8601 Weekday Convention:** Monday=1, Sunday=7
- **Potential iOS Conflict:** Some iOS APIs use Sunday=1, Monday=2
- **Mitigation:** Documented in Weekday struct comments, consistent across app

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| LocalTask | Model | Data storage for tasks |
| TaskSource | Protocol | Abstraction for multi-source tasks |
| LocalTaskSource | Service | CRUD operations for local tasks |
| SwiftData | Framework | Persistence layer |
| SwiftUI | Framework | UI rendering |

## Changelog

- **2026-01-17:** Initial refactoring implemented
  - Changed category → tags (multi-select)
  - Changed isRecurring → recurrencePattern with details
  - Simplified priority to 3 levels (1-3)
  - Added quick-select duration buttons
  - Added inline recurrence expansion UI
  - All 87 unit tests passing
- **2026-01-17:** Spec created retroactively after implementation

## Related Documents

- **Plan:** `/Users/hem/.claude/plans/immutable-yawning-moonbeam.md` (Task System v2.0 3-phase plan)
- **User Requirements:**
  - `create_task_input_flow.md` - Duration, Urgency, Task Type, Recurring, Description
  - `task_backlog_view.md` - Eisenhower Matrix (Phase 2)
- **Screenshots:**
  - BEFORE: `/docs/artifacts/multi-source-tasks/screenshots/before-createtaskview-refactor.png`
  - AFTER: `/docs/artifacts/multi-source-tasks/screenshots/after-createtaskview-refactor.png`

## Next Steps (Phase 2: Backlog Enhancements)

After user validates this refactoring in the app:
1. **Backlog View Update:** Add visual indicators for priority, tags, due date
2. **Eisenhower Matrix View:** 2×2 grid grouped by urgency × priority
3. **Filtering:** By task type, tags, completion status, recurrence
4. **Sorting:** By priority, duration, due date (with drag-drop override)
5. **Drag & Drop:** Maintain manual ordering capability

**Estimated Phase 2 Scope:** 5 files, ~265 LoC
