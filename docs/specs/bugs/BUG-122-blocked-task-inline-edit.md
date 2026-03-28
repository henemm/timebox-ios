---
entity_id: BUG-122-blocked-task-inline-edit
type: bugfix
created: 2026-03-28
updated: 2026-03-28
status: draft
version: "1.0"
tags: [backlog, blocked-tasks, inline-edit, badges]
---

# BUG_122: Blocked Tasks — Inline Badge Editing fehlt

## Approval

- [ ] Approved

## Purpose

Blocked Tasks (Tasks mit `blockerTaskID`) koennen auf iOS keine Attribute ueber Inline-Badges aendern. Die Badges (Importance, Urgency, Category, Duration) werden gerendert, reagieren aber nicht auf Taps, weil `blockedRow()` die Callbacks nicht uebergibt.

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `blockedRow(_ item: PlanItem)` (Zeile ~1112)

## Root Cause

`blockedRow()` erstellt eine `BacklogRow` mit nur 2 von 10 moeglichen Callbacks:

```swift
// IST-Zustand (fehlerhaft)
BacklogRow(
    item: item,
    onEditTap: { handleEditTap(item) },
    onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
    isBlocked: true
)
```

Zum Vergleich — `backlogRowWithSwipe()` uebergibt alle Callbacks (Zeile 1060).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `BacklogRow` | View | Rendert Badges mit optionalen Callbacks (nil = no-op) |
| `TaskBadges.swift` | View | ImportanceBadge/UrgencyBadge rufen `onCycle?()` / `onToggle?()` |
| `DeferredSortController` | Service | Freeze/Unfreeze nach Badge-Tap (kein Risiko — blocked Tasks sind nicht in `backlogTasks`) |
| `SyncEngine` | Service | `updateTask`/`updateDuration` (keine `isBlocked`-Pruefung) |

## Implementation Details

### Fix: Callbacks in `blockedRow()` ergaenzen

```swift
// SOLL-Zustand
private func blockedRow(_ item: PlanItem) -> some View {
    BacklogRow(
        item: item,
        onDurationTap: { selectedItemForDuration = item },
        onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
        onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
        onCategoryTap: { selectedItemForCategory = item },
        onEditTap: { handleEditTap(item) },
        onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
        isBlocked: true,
        isPendingResort: deferredSort.isPending(item.id)
        // onComplete: nil — INTENTIONAL: blocked Tasks koennen nicht completed werden
        // onAddToNextUp: nil — INTENTIONAL: blocked Tasks nicht manuell in Next Up
        // onStartFocusSprint: nil — INTENTIONAL: blocked Tasks koennen keinen Sprint starten
    )
    // Swipe-Actions bleiben unveraendert
}
```

### Was NICHT geaendert wird

| Callback | Begruendung |
|----------|-------------|
| `onComplete` | Blocked Tasks koennen nicht completed werden (Blocker muss erst erledigt sein) |
| `onAddToNextUp` | Blocked Tasks sollen nicht in Next Up (logisch nicht actionable) |
| `onStartFocusSprint` | Sprint auf blocked Task widerspricht Dependency-Semantik |
| `effectiveScore` | Blocked Tasks werden nicht nach Score sortiert (Position = unter Blocker) |

## Expected Behavior

- **Vorher:** Badges auf blocked Tasks sichtbar aber nicht tippbar
- **Nachher:** Importance, Urgency, Category, Duration per Badge-Tap editierbar
- **Side effects:** `isPendingResort` zeigt Puls-Border nach Badge-Tap (visuelles Feedback)

## Scope

| Metrik | Wert |
|--------|------|
| Produktions-Dateien | 1 |
| Test-Dateien | 1 (neu) |
| Geschaetzte LoC | +8 (Prod) / +70 (Tests) |
| Risiko | LOW |
| Plattform | iOS (macOS nicht betroffen) |

## Test Plan

### UI Tests (BlockedTaskInlineBadgeUITests.swift)

| Test | Beschreibung | Accessibility ID |
|------|-------------|-----------------|
| `testBlockedTask_importanceBadgeCycles` | Tap auf Importance Badge aendert Wert | `importanceBadge_<id>` |
| `testBlockedTask_urgencyBadgeToggles` | Tap auf Urgency Badge toggelt Wert | `urgencyBadge_<id>` |
| `testBlockedTask_categoryBadgeOpensSheet` | Tap auf Category Badge oeffnet Picker | `categoryBadge_<id>` |
| `testBlockedTask_durationBadgeOpensSheet` | Tap auf Duration Badge oeffnet Picker | `durationBadge_<id>` |
| `testBlockedTask_checkboxRemainsDisabled` | Checkbox bleibt disabled (Regression-Guard) | `completeButton_<id>` |

### Referenz fuer Test-Setup

Bestehender Test `FocusBloxUITests/BlockedTaskSwipeUITests.swift` — Pattern fuer blocked Task Erstellung + Navigation.

## Known Limitations

- Blocked Tasks erscheinen NICHT in `backlogTasks` (Top-Level-Liste). `freezeSortOrder()` hat daher keinen Effekt auf ihre Position — das ist korrekt und erwartet.
- macOS hat dieses Problem nicht (`makeBacklogRow` uebergibt immer alle Callbacks).

## Changelog

- 2026-03-28: Initial spec created
