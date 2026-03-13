# Bug Analysis: FocusBlock Task Disappearing (Bug 81) + Completed Search (Bug 82)

**Date:** 2026-03-09
**Reporter:** Henning
**Platform:** iOS

## Bug Descriptions

**Bug 81:** FocusBlock Edit Sheet — Task zuweisen, Sheet schliessen, erster Task verschwunden.
**Bug 82:** Backlog "Erledigte" View — Suche filtert nicht, hat keine Auswirkung.

## Agent Investigation Results

### Agent 1: History Check
- Bug 23: Task-Sichtbarkeit nach Block-Zuordnung (commit ab5f53e) — direkter Vorgaenger
- Bug 56: EditTaskSheet nil-conversion (ERLEDIGT, hielt)
- Bug 74: Sheet dismiss on save (ERLEDIGT, hielt)
- Bug 76: macOS Task loses selection (ERLEDIGT, hielt)
- Generic Search: Implemented for all views EXCEPT completed (by oversight)

### Agent 2: Data Flow Trace (FocusBlock)
- Sheet presented via `.sheet(item: $blockForTasks) { block in ... }`
- `block` is a **struct** (value type) → captured as snapshot at sheet presentation
- `FocusBlockTasksSheet` has `@State private var taskOrder` initialized once in `.onAppear`
- `onAssignTask` callback calls `assignTaskToBlock(taskID:block:)` with STALE `block`
- Each assignment: `var updatedTaskIDs = block.taskIDs` → uses ORIGINAL taskIDs, not current

### Agent 3: Data Flow Trace (Completed Search)
- `.searchable(text: $searchText)` applied to entire NavigationStack
- `matchesSearch()` function exists and works
- ALL views use `matchesSearch()` in computed properties EXCEPT `completedView`
- `completedView` directly iterates `ForEach(completedTasks)` — NO filter applied

### Agent 4: All Writers
- 55+ write locations for FocusBlock data identified
- All go through `eventKitRepo.updateFocusBlock()` which serializes to EventKit notes
- `completedTasks` loaded from `syncEngine.syncCompletedTasks(days: 7)` without search

### Agent 5: Blast Radius
- Both platforms share FocusBlock serialization logic
- macOS has same stale-block pattern in MacPlanningView
- macOS does NOT have `.searchable()` → Bug 82 is iOS-only

## Hypotheses

### Bug 81: FocusBlock Tasks Disappearing

#### Hypothesis 1: Stale block snapshot causes task overwrite (HIGHEST)
- **Evidence FOR:**
  - `block` is `let` in FocusBlockTasksSheet (line 8) — never updated
  - `block` captured in `.sheet(item:)` closure as value type snapshot
  - Each `onAssignTask` call starts from same stale `block.taskIDs`
  - Sequence: Block=[], assign A→save [A], assign B→save [B] (stale! A lost)
- **Evidence AGAINST:** None — code clearly shows this behavior
- **Probability:** HIGH (95%)
- **Location:** `BlockPlanningView.swift:397-424` (assignTaskToBlock uses stale block)

#### Hypothesis 2: Race condition between parallel saves
- **Evidence FOR:** Each assignment creates a new `Task { }` that runs concurrently
- **Evidence AGAINST:** Subsummed by Hypothesis 1 — same root cause
- **Probability:** HIGH (part of Hypothesis 1)

#### Hypothesis 3: taskOrder not updated after assignment (NEW — from Challenge)
- **Evidence FOR:**
  - `@State private var taskOrder` initialized in `.onAppear` — fires only ONCE
  - No `.onChange(of: tasks)` to refresh `taskOrder` when underlying data changes
  - After `assignTaskToBlock` saves + `loadData()` runs, `tasks` updates but `taskOrder` stays stale
  - Explains Symptom 2: "Tasks erscheinen nicht oben, erst nach erneutem Oeffnen"
  - `.onAppear` fires again only when Sheet is dismissed and reopened
- **Evidence AGAINST:** None — `.onAppear` semantics confirmed
- **Probability:** HIGH (95%)
- **Location:** `FocusBlockTasksSheet.swift:42-44` (missing `.onChange(of: tasks)`)
- **Note:** This is a SECOND, independent root cause for Bug 81, not part of Hypothesis 1

#### Hypothesis 4: EventKit save fails silently
- **Evidence FOR:** `guard let event = eventStore.event(withIdentifier:)` returns silently on nil
- **Evidence AGAINST:** Would affect ALL saves, not just first task
- **Probability:** LOW (5%)

### Bug 82: Completed Tasks Search

#### Hypothesis 1: matchesSearch() not applied to completedView (CONFIRMED)
- **Evidence FOR:**
  - `nextUpTasks`: uses `matchesSearch($0)` ✓ (BacklogView.swift:88)
  - `backlogTasks`: uses `matchesSearch($0)` ✓ (BacklogView.swift:93)
  - `recurringTasks`: uses `matchesSearch($0)` ✓ (BacklogView.swift:98)
  - `completedView`: `ForEach(completedTasks)` — NO filter ✗ (BacklogView.swift:1069)
- **Evidence AGAINST:** None
- **Probability:** HIGH (99%)
- **Location:** `BacklogView.swift:1069`

#### Hypothesis 2: .searchable() not connected
- **Evidence AGAINST:** `.searchable()` is on NavigationStack (line 311), works for other tabs
- **Probability:** LOW (1%)

## Root Causes (Confirmed)

### Bug 81 — Root Cause A: Stale FocusBlock Snapshot
`FocusBlockTasksSheet` captures `block` as value type snapshot. Each `onAssignTask` callback
reads `block.taskIDs` which is the ORIGINAL task list. When user assigns multiple tasks rapidly,
each assignment starts from the same base → earlier assignments are overwritten.
**Erklaert:** "erster Task verschwunden"

### Bug 81 — Root Cause B: taskOrder nicht aktualisiert
`@State private var taskOrder` in `FocusBlockTasksSheet` wird nur in `.onAppear` gesetzt.
Nach einem Task-Assignment läuft `loadData()`, aber `taskOrder` wird nie aktualisiert
(kein `.onChange(of: tasks)`). Der zugewiesene Task erscheint nicht in der UI, obwohl er
gespeichert wurde. Erst beim Sheet-Schliessen und Wiederoeffnen faeuert `.onAppear` erneut.
**Erklaert:** "Tasks erscheinen nicht oben, erst nach erneutem Oeffnen"

### Bug 82: Missing Search Filter
`completedView` in BacklogView directly iterates `completedTasks` without applying
`matchesSearch()`. Every other view mode applies this filter, but `completedView` was missed.

## Blast Radius

### Bug 81:
- macOS `MacPlanningView` hat identisches Pattern (Zeile 339: `assignTaskToBlockFromSheet`)
  → **MUSS mit-gefixt werden** (nicht nur Blast-Radius-Notiz)
- `FocusBlockTasksSheet` ist Shared Code in `Sources/` → taskOrder-Fix gilt fuer beide Plattformen
- `TaskAssignmentView` may have same issue (3 assignment call sites)

### Bug 82:
- iOS only (macOS has no .searchable())
- Only affects "Erledigte" tab
- No other views affected (all others already filter)
- **Zusaetzlich:** Wenn Suche alle Tasks filtert, zeigt Empty State "Keine erledigten Tasks"
  statt "Keine Suchergebnisse" — separates UX-Problem, niedrige Prio
