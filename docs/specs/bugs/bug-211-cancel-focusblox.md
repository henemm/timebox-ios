---
entity_id: bug-211-cancel-focusblox
type: bugfix
created: 2026-04-12
updated: 2026-04-12
status: approved
version: "1.0"
tags: [focus, timer, liveactivity, abort]
---

# Bug #211: FocusBlox abbrechen

## Approval

- [x] Approved

## Purpose

Beim Abbrechen eines laufenden FocusBlox wird der Timer-State nicht zurückgesetzt: LiveActivity läuft weiter, Timer zählt weiter, Abbrechen-Button bleibt aktiv.

## Source

- **File:** `Sources/Views/FocusLiveView.swift`
- **Identifier:** Abort-Button (Zeile 362-364), onDismiss (Zeile 153-163)

## Root Cause

1. Im Abort-Button-Handler fehlt `endActivity()` + `liveActivityStarted = false` + `taskStartTime = nil`
2. `returnIncompleteTasksToNextUp()` wird nur bei `block.isPast` aufgerufen — beim Abort ist Block noch aktiv
3. `.sheet(isPresented:)` hat keinen `onDismiss`-Parameter — Swipe-Down umgeht Cleanup

## Fix

### 1. Abort-Button: LiveActivity sofort beenden
```swift
Button {
    isAbortingBlock = true
    showSprintReview = true
    // NEU: LiveActivity + Timer-State sofort zurücksetzen
    liveActivityManager.endActivity()
    liveActivityStarted = false
    taskStartTime = nil
} label: { ... }
```

### 2. onDismiss: Tasks auch bei aktivem Block zurücksetzen
```swift
onDismiss: {
    isAbortingBlock = false
    reviewDismissed = true
    Task {
        if isAbortingBlock || block.isPast {  // war: block.isPast
            returnIncompleteTasksToNextUp(block: block)
        }
        await loadData()
    }
}
```

ACHTUNG: `isAbortingBlock` wird in Zeile 154 auf `false` gesetzt BEVOR der Check in Zeile 158 passiert. Reihenfolge muss angepasst werden.

### 3. Sheet: onDismiss-Parameter für Swipe-Down
```swift
.sheet(isPresented: $showSprintReview, onDismiss: {
    // Cleanup bei Swipe-Down (wenn onDismiss-Callback nicht aufgerufen wurde)
    if isAbortingBlock {
        isAbortingBlock = false
        reviewDismissed = true
        Task { await loadData() }
    }
}) { ... }
```

## Acceptance Criteria

- [ ] Nach Abbrechen: LiveActivity wird sofort beendet (kein Lock-Screen-Timer mehr)
- [ ] Nach Abbrechen: Timer im App-Dialog stoppt
- [ ] Nach Abbrechen: Abbrechen-Button verschwindet (kein aktiver Block mehr angezeigt)
- [ ] Nach Abbrechen: Unerledigte Tasks werden zu Next Up zurückgesetzt
- [ ] Swipe-Down auf Sprint Review Sheet: State wird korrekt zurückgesetzt
- [ ] Normales Block-Ende (ohne Abort): Funktioniert weiterhin wie bisher

## Blast Radius

- macOS: NICHT betroffen (kein Abort-Button vorhanden)
- Normales Block-Ende: Nicht betroffen (eigener Code-Pfad in checkBlockEnd)
- Task Completion/Skip: Nicht betroffen (eigener Code-Pfad)
