---
entity_id: feature-021-organize-my-day-intent
type: module
created: 2026-03-30
updated: 2026-03-30
status: draft
version: "1.0"
tags: [intents, siri, shortcuts, day-planning]
---

# FEATURE_021 — OrganizeMyDayIntent

## Approval

- [ ] Approved

## Purpose

`OrganizeMyDayIntent` is a read-only `AppIntent` that orchestrates GapFinder, BehavioralProfileService, and NextUpSuggestionService to suggest which tasks the user should work on today, exposed to Siri and Shortcuts.app without opening the app. It exists to make the day-planning logic (previously only accessible inside DayView) available as a voice command and as a first-class building block in Shortcuts automations.

## Source

- **File:** `Sources/Intents/OrganizeMyDayIntent.swift` (CREATE)
- **Identifier:** `struct OrganizeMyDayIntent: AppIntent`

Secondary change:
- **File:** `Sources/Intents/FocusBloxShortcuts.swift` (MODIFY — add one `AppShortcut` entry)

Test file:
- **File:** `FocusBloxTests/OrganizeMyDayIntentTests.swift` (CREATE)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SharedModelContainer` | struct | Creates App Group ModelContainer for data access without launching the app |
| `LocalTask` | SwiftData model | Fetched from shared container; source of all backlog tasks |
| `PlanItem` | struct | Intermediate representation; `LocalTask` converts to `PlanItem` via existing initializer |
| `EventKitRepository` | class | Provides `fetchCalendarEvents()` and `fetchFocusBlocks()` for the day |
| `GapFinder` | struct | Finds free `TimeSlot`s between calendar events (06:00–22:00, min 30 min) |
| `BehavioralProfileService` | enum | Computes user affinities from 28-day completion history |
| `BehavioralProfile` | struct | Result of `BehavioralProfileService.profile()` |
| `NextUpSuggestionService` | enum | Ranks `PlanItem`s against `TimeSlot`s; returns `[NextUpSuggestion]` |
| `NextUpSuggestion` | struct | Ranked suggestion — contains `planItem`, `slot`, `score` |
| `TaskEntity` | struct | AppIntent output type; constructed from `LocalTask` |
| `FocusBloxShortcuts` | struct | `AppShortcutsProvider` — registers Siri phrases for this intent |
| `TimeSlot` | struct | Free time window returned by `GapFinder.findFreeSlots()` |

## Implementation Details

### OrganizeMyDayIntent.swift

```swift
import AppIntents
import SwiftData

/// Suggests which tasks to work on today by finding calendar gaps and ranking backlog tasks.
/// Read-only — no data is modified.
struct OrganizeMyDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag organisieren"
    static let description = IntentDescription(
        "Findet freie Zeitfenster und schlägt passende Tasks für heute vor."
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> & ProvidesDialog {
        let today = Date()

        // 1. Fetch tasks from App Group SwiftData container
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let tasks = try context.fetch(descriptor)
        let planItems = tasks.map { PlanItem(from: $0) }

        // 2. Fetch calendar data (graceful degradation if EventKit not authorized)
        let repo = EventKitRepository()
        let calendarEvents = (try? await repo.fetchCalendarEvents(for: today)) ?? []
        let focusBlocks = (try? await repo.fetchFocusBlocks(for: today)) ?? []

        // 3. Find free slots in today's calendar
        let gapFinder = GapFinder(
            events: calendarEvents,
            focusBlocks: focusBlocks,
            scheduledTasks: [],
            date: today
        )
        let slots = gapFinder.findFreeSlots(minMinutes: 30, maxMinutes: 60)

        // 4. Build behavioral profile
        let allTasksDescriptor = FetchDescriptor<LocalTask>()
        let allTasks = (try? context.fetch(allTasksDescriptor)) ?? tasks
        let profile = BehavioralProfileService.profile(
            tasks: allTasks,
            focusBlocks: focusBlocks,
            calendarEvents: calendarEvents,
            now: today
        )

        // 5. Rank tasks against slots
        let suggestions = NextUpSuggestionService.suggestions(
            items: planItems,
            slots: slots,
            profile: profile,
            calendarEvents: calendarEvents,
            now: today
        )

        // 6. Build output
        let entities = suggestions.map { TaskEntity(from: $0.planItem.task) }

        let dialog = buildDialog(
            slotCount: slots.count,
            suggestions: suggestions
        )
        return .result(value: entities, dialog: "\(dialog)")
    }

    // MARK: - Dialog Builder

    private func buildDialog(
        slotCount: Int,
        suggestions: [NextUpSuggestion]
    ) -> String {
        guard slotCount > 0 else {
            return "Heute sind keine freien Zeitfenster verfügbar."
        }
        guard !suggestions.isEmpty else {
            return "Du hast \(slotCount) freie \(slotCount == 1 ? "Zeitfenster" : "Zeitfenster"), aber keine passenden Tasks im Backlog."
        }

        let titles = suggestions.prefix(3).map { $0.planItem.title }
        let spoken: String
        if suggestions.count > 3 {
            let extra = suggestions.count - 3
            spoken = titles.joined(separator: ", ") + " und \(extra) \(extra == 1 ? "weitere" : "weitere")"
        } else {
            spoken = titles.joined(separator: ", ")
        }

        return "Du hast \(slotCount) freie \(slotCount == 1 ? "Slot" : "Slots") heute. Ich schlage vor: \(spoken)."
    }
}
```

### FocusBloxShortcuts.swift addition

Add one `AppShortcut` block inside `appShortcuts`:

```swift
AppShortcut(
    intent: OrganizeMyDayIntent(),
    phrases: [
        "Plane meinen Tag in \(.applicationName)",
        "Organisiere meinen Tag in \(.applicationName)",
        "Tagesvorschläge in \(.applicationName)"
    ],
    shortTitle: "Tag organisieren",
    systemImageName: "calendar.badge.clock"
)
```

### Pipeline Overview

```
SharedModelContainer.create()
    └─ ModelContext → fetch [LocalTask] (non-completed)
          └─ [PlanItem]

EventKitRepository()
    ├─ fetchCalendarEvents(for: today) → [CalendarEvent]
    └─ fetchFocusBlocks(for: today)   → [FocusBlock]

GapFinder(events:focusBlocks:date:)
    └─ findFreeSlots(minMinutes:30 maxMinutes:60) → [TimeSlot]

BehavioralProfileService.profile(tasks:focusBlocks:calendarEvents:)
    └─ BehavioralProfile (categoryTimeAffinity, avgTasksPerDay, …)

NextUpSuggestionService.suggestions(items:slots:profile:calendarEvents:)
    └─ [NextUpSuggestion] (ranked by priorityScore × affinityBonus × rescheduleBonus)

→ Output: [TaskEntity] + German dialog string
```

## Expected Behavior

- **Input:** None (intent has no parameters; uses current date as `today`)
- **Output:**
  - `[TaskEntity]` — ranked suggestions for Shortcuts chaining (may be empty)
  - Dialog string in German — always non-empty (one of the four dialog variants below)
- **Side effects:** None. No SwiftData writes, no EventKit writes, no `isNextUp` flags set.

### Dialog Variants

| Condition | Dialog |
|-----------|--------|
| `slots.isEmpty` | "Heute sind keine freien Zeitfenster verfügbar." |
| `slots > 0`, `suggestions.isEmpty` | "Du hast N freie Zeitfenster, aber keine passenden Tasks im Backlog." |
| 1–3 suggestions | "Du hast N freie Slots heute. Ich schlage vor: Task A, Task B." |
| >3 suggestions | "Du hast N freie Slots heute. Ich schlage vor: Task A, Task B, Task C und M weitere." |

### EventKit Authorization — Graceful Degradation

If EventKit access is not granted, `fetchCalendarEvents` and `fetchFocusBlocks` return empty arrays. `GapFinder` then triggers its built-in default-suggestions path (fixed slots at 09:00, 11:00, 14:00, 16:00) so the intent still returns ranked tasks.

## Test Plan

File: `FocusBloxTests/OrganizeMyDayIntentTests.swift`

| Test | Description | Expected |
|------|-------------|----------|
| `testDialogNoSlots` | `buildDialog(slotCount: 0, suggestions: [])` | Returns "Heute sind keine freien Zeitfenster verfügbar." |
| `testDialogNoSuggestions` | `buildDialog(slotCount: 3, suggestions: [])` | Returns "Du hast 3 freie Zeitfenster, aber keine passenden Tasks im Backlog." |
| `testDialogOneSuggestion` | `buildDialog(slotCount: 2, suggestions: [s1])` | Contains "Ich schlage vor: TaskName." |
| `testDialogThreeSuggestions` | `buildDialog(slotCount: 4, suggestions: [s1,s2,s3])` | Lists all 3 titles, no "weitere" |
| `testDialogMoreThanThree` | `buildDialog(slotCount: 5, suggestions: [s1…s5])` | Lists first 3 + "und 2 weitere" |
| `testNoSlotsReturnsEmptyEntities` | Full pipeline with empty EventKit + no tasks → slots via default suggestions | Does not crash, returns [] or valid tasks |
| `testSuggestionOrderMatchesScore` | Inject 3 PlanItems with known scores → first entity matches highest score | entities[0].id == highestScoreTask.id |

Tests cover only the dialog-building logic and the scoring contract; full pipeline tests use mocked services or `BehavioralProfileService.compute()` directly.

## Known Limitations

- **LimitationGuard excluded from v1.** `LimitationGuardService` is not called; no overload warning is shown when suggestions exceed historical daily capacity. Trivially addable in v2 by inserting an `evaluate()` call after `NextUpSuggestionService.suggestions()`.
- **EventKit authorization prompt not triggered.** The intent does not call `requestAccess`; if the user has never opened the app, EventKit returns empty arrays and the fallback path activates. The main app handles the auth prompt on first launch.
- **Cold caches in Intent process.** Both `BehavioralProfileService` and `NextUpSuggestionService` have in-memory caches. These start empty in the extension process but all computations complete in <1 s, well within Intent timeout limits.
- **PlanItem initializer assumption.** The spec assumes `PlanItem(from: LocalTask)` exists. Verified via `DayView` usage. If the initializer signature changes, the intent must be updated accordingly.

## Changelog

- 2026-03-30: Initial spec created
