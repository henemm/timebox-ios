---
entity_id: bug-41-liveactivity-timer
type: bugfix
created: 2026-02-12
status: draft
workflow: bug-41-liveactivity-timer
---

# Bug 41: LiveActivity Timer Fixes

## Approval

- [ ] Approved by PO

## Problem

1. LiveActivity Timer zählt nach Block-Ende weiter hoch statt bei 0:00 zu stoppen
2. Timer zeigt immer Block-Endzeit, nicht die Task-spezifische Restzeit

## Root Cause

1. `Text(context.attributes.endDate, style: .timer)` zählt automatisch HOCH wenn endDate in der Vergangenheit liegt. SwiftUI default Verhalten.
2. `FocusBlockActivityAttributes.ContentState` hat kein `taskEndDate` Feld. Widget kann nur Block-Countdown anzeigen.

## Scope

- **Files:** 4 Dateien
- **Estimated:** ~40 LoC

## Implementation Details

### Fix 1: Timer stoppt bei 0:00

`FocusBlockLiveActivity.swift`: `Text(endDate, style: .timer)` ersetzen durch `Text(timerInterval: Date.now...endDate, countsDown: true)` - stoppt automatisch bei 0:00.

### Fix 2: Task-Timer statt Block-Timer

1. `FocusBlockActivityAttributes.swift`: `taskEndDate: Date?` zu ContentState hinzufuegen
2. `LiveActivityManager.swift`: `updateActivity()` akzeptiert `taskEndDate` Parameter
3. `FocusLiveView.swift`: `updateLiveActivity()` berechnet `taskEndDate` aus `taskStartTime + estimatedDuration`
4. `FocusBlockLiveActivity.swift`: Widget zeigt `taskEndDate` wenn verfuegbar, sonst Block-Endzeit

### Betroffene Dateien

1. `FocusBloxWidgets/FocusBlockLiveActivity.swift` - Timer-Logik + Task-Timer
2. `Sources/Models/FocusBlockActivityAttributes.swift` - taskEndDate im ContentState
3. `Sources/Services/LiveActivityManager.swift` - taskEndDate Parameter
4. `Sources/Views/FocusLiveView.swift` - taskEndDate Berechnung

## Test Plan

### Unit Tests

- [ ] Test 1: ContentState mit taskEndDate erstellbar
- [ ] Test 2: taskEndDate Berechnung korrekt

## Acceptance Criteria

- [ ] Timer stoppt bei 0:00 (kein Hochzaehlen)
- [ ] Timer zeigt Task-Restzeit wenn Task aktiv
- [ ] Build kompiliert ohne Errors
