# Task System v2.0 - OpenSpec Documentation

**Feature ID:** task-system-v2
**Type:** Major Feature Enhancement
**Created:** 2026-01-16
**Status:** In Progress

---

## Overview

Comprehensive enhancement of the Task Management System with:
1. **Enhanced Task Input** - Quick-add with Duration, Urgency, Task Type, Recurring, Description
2. **Backlog View v2** - Eisenhower Matrix, Filtering, Sorting, Visual Indicators
3. **Focus Block Planning** - Time buffer validation (15% safety margin)
4. **Focus Mode & Review** - Post-block reflection with task rescheduling
5. **Sync Infrastructure** - Data model prepared for Notion/external integrations

---

## Phase Roadmap

### Phase 1: Data Model & Enhanced Input ⏳ IN PROGRESS
**Goal:** Extend LocalTask with all required fields and update CreateTaskView

**Files:** 6 files, ~290 LoC
**Priority:** CRITICAL (Foundation for all other features)
**Documentation:**
- [spec.md](./phase1-data-model/spec.md) - Data model extensions + CreateTaskView
- [tests.md](./phase1-data-model/tests.md) - Unit test definitions

**New Fields:**
- `urgency: String` - "urgent" | "not_urgent"
- `taskType: String` - "income" | "maintenance" | "recharge"
- `isRecurring: Bool` - Recurring task flag
- `description: String?` - Long-form task notes
- `externalID: String?` - For Notion/external sync
- `sourceSystem: String` - "local" | "notion" | "todoist"

---

### Phase 2: Backlog Enhancements 📋 PLANNED
**Goal:** Add Eisenhower Matrix view, filtering, and sorting to BacklogView

**Files:** 5 files, ~265 LoC
**Priority:** HIGH (Core planning workflow improvement)
**Documentation:**
- [spec.md](./phase2-backlog/spec.md) - Eisenhower, filters, sorting
- [tests.md](./phase2-backlog/tests.md) - UI test scenarios

**Features:**
- Eisenhower Matrix (2x2 grid: Urgent × Important)
- 5 view modes (List, Eisenhower, Category, Duration, Due Date)
- Filtering by task_type, category, completion, recurring
- Visual indicators (priority icon, category chip, due date badge)

---

### Phase 3: Focus Planning & Review ⏱️ PLANNED
**Goal:** Add time buffer validation and post-block review dialog

**Files:** 4 files, ~210 LoC
**Priority:** MEDIUM (Workflow completion features)
**Documentation:**
- [spec.md](./phase3-focus-review/spec.md) - Buffer validation + review dialog
- [tests.md](./phase3-focus-review/tests.md) - Integration test scenarios

**Features:**
- Time buffer calculation (Nettozeit = Block duration × 0.85)
- Visual feedback (Green/Yellow/Red based on buffer usage)
- Post-block review dialog ("X of Y tasks completed")
- Task rescheduling to backlog top

---

### Phase 4: Sync Infrastructure 🔄 FUTURE
**Goal:** Enable Notion/Todoist integration

**Priority:** LOW (Post-MVP, deferred)
**Scope:** TBD (6-8 files, significant architectural changes)

**Out of Scope for Initial Rollout:**
- Notion OAuth integration
- Conflict resolution UI
- Multi-source task aggregation
- Incremental/delta sync

**Preparation Work:** Phase 1 adds `external_id` and `source_system` fields.

---

## User Requirements Mapping

| Requirement File | Phases Addressed |
|-----------------|------------------|
| create_task_input_flow.md | Phase 1 (All fields) |
| task_backlog_view.md | Phase 2 (Eisenhower, filters, sorting) |
| planning_focus_blocks.md | Phase 3 (Buffer validation) |
| focus_mode_and_review.md | Phase 3 (Review dialog) |
| task_data_integrity_and_sync.md | Phase 1 (Data model) + Phase 4 (Sync) |

---

## Total Scope

**Phase 1-3 Combined:**
- 15 files modified/created
- ~765 LoC
- 3 weeks estimated development time

**Success Criteria:**
- ✅ Phase 1: Tasks can be created with full metadata (duration, urgency, task_type required)
- ✅ Phase 2: Users can filter backlog by Eisenhower quadrants
- ✅ Phase 3: Focus block execution includes review step with task rescheduling
- ✅ Overall: User completes workflow: Quick-add → Eisenhower planning → Focus execution → Reflection

---

## Current Status

| Phase | Status | Started | Completed |
|-------|--------|---------|-----------|
| Phase 1 | ⏳ IN PROGRESS | 2026-01-16 | - |
| Phase 2 | 📋 PLANNED | - | - |
| Phase 3 | ⏱️ PLANNED | - | - |
| Phase 4 | 🔄 FUTURE | - | - |

---

## References

- Main Implementation Plan: `/Users/hem/.claude/plans/immutable-yawning-moonbeam.md`
- Existing OpenSpec Example: `openspec/changes/mock-eventkit-repository/`
- Project Docs: `docs/ACTIVE-todos.md`
