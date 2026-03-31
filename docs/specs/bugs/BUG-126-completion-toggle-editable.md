---
entity_id: BUG-126-completion-toggle-editable
type: module
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [bug, backlog, completion, deferred-sort, ios, macos]
---

# BUG-126: Completion-Toggle während 3-Sekunden-Fenster editierbar

## Approval

- [x] Approved (2026-03-31)

## Purpose

Completion soll sich wie jede andere Task-Änderung (Importance, Urgency, Category, Duration) verhalten: Der 3-Sekunden-Timer wird bei jedem weiteren Tap resettet, der Task bleibt editierbar. Aktuell blockiert der Guard in BacklogRow/MacBacklogRow den zweiten Tap, anstatt ihn als Undo zu interpretieren.

## Source

- **Files:**
  - `Sources/Views/BacklogRow.swift` (Zeile 35 — Guard)
  - `Sources/Views/BacklogView.swift` (Callback-Verdrahtung, Timer-Koordination)
  - `FocusBloxMac/MacBacklogRow.swift` (Zeile 37 — Guard)
  - `FocusBloxMac/ContentView.swift` (Callback-Verdrahtung, Timer-Koordination)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DeferredCompletionController` | Service | `cancelCompletion(id:)` für Undo-Tap; `scheduleCompletion(id:onCommit:)` für Neu-Start |
| `DeferredSortController` | Service | `scheduleDeferredResort(id:)` resetten wenn Completion gestartet/gecancelt wird |

## Implementation Details

### 1. BacklogRow.swift — Guard ändern + onCancelCompletion Callback

Neuer Callback auf der View:
```swift
var onCancelCompletion: (() -> Void)?  // Undo completion during pending phase
```

Guard-Logik ersetzen (Zeile 34-37):
```swift
Button {
    if isBlocked { return }
    if isCompletionPending {
        onCancelCompletion?()   // Undo: Timer abbrechen, Checkbox zurücksetzen
    } else {
        onComplete?()           // Normal: Completion starten
    }
}
```

### 2. MacBacklogRow.swift — identisch wie BacklogRow

Neuer Callback:
```swift
var onCancelCompletion: (() -> Void)?
```

Guard-Logik ersetzen (Zeile 36-39): gleiche Logik wie iOS.

### 3. BacklogView.swift — Callbacks verdrahten + Timer-Koordination

Im `onComplete`-Callback (wo `completionController.scheduleCompletion` aufgerufen wird):
- VOR `scheduleCompletion`: `sortController.scheduleDeferredResort(id:)` aufrufen — damit der Sort-Timer ebenfalls läuft/resettet wird.

Im neuen `onCancelCompletion`-Callback:
```swift
completionController.cancelCompletion(id: item.id.uuidString)
sortController.scheduleDeferredResort(id: item.id.uuidString)
```

Badge-Tap-Handler (Importance, Urgency etc.): wenn `completionController.isPending(id)` → Completion-Timer resetten (nicht abbrechen!). `scheduleCompletion` erneut aufrufen (resettet internen Timer). Sort-Timer wie bisher resetten.

### 4. ContentView.swift (macOS) — identisch wie BacklogView

Dieselbe Koordinationslogik für `onCancelCompletion` und Badge-Taps.

### Zusammenfassung der Timer-Synchronisation

| Auslöser | Sort-Timer | Completion-Timer |
|----------|-----------|-----------------|
| Completion-Tap (neu) | reset | start |
| Completion-Tap (Undo) | reset | cancel |
| Badge-Tap (während Completion pending) | reset | reset (Completion bleibt!) |
| Badge-Tap (normal) | reset | — |

## Expected Behavior

- **Completion-Tap (kein pending):** Checkbox füllt sich, Task bleibt 3 Sek. sichtbar, Timer startet.
- **Completion-Tap (während pending):** Checkbox leert sich sofort (Undo), kein Commit, Sort-Timer resettet.
- **Badge-Tap (während Completion pending):** Badge-Änderung wird sofort wirksam, Completion bleibt pending, ALLE Timer resetten auf 3 Sek.
- **Ergebnis:** Jede Änderung — egal ob Completion oder Badge — resettet alle laufenden Timer.

## Known Limitations

- Badge-Tap während Completion-Pending resettet den Timer, bricht aber die Completion NICHT ab. Task bleibt visuell als "erledigt" markiert.
- Nur ein expliziter zweiter Tap auf die Checkbox bricht die Completion ab.

## Test Plan

### Unit Tests (DeferredCompletionController)

1. **cancelCompletion entfernt ID aus pendingIDs** — `scheduleCompletion` aufrufen, dann `cancelCompletion`, `isPending` muss false sein.
2. **cancelCompletion verhindert Commit** — onCommit-Callback darf nach `cancelCompletion` nicht aufgerufen werden.

### UI Tests (iOS — BacklogUITests)

1. **Completion-Undo:** Task tippen → Checkbox füllt sich (isCompletionPending=true) → nochmal tippen → Checkbox leert sich (isCompletionPending=false), kein Commit.
2. **Badge-Tap während Completion resettet Timer:** Task tippen (pending) → Importance-Badge tippen → Checkbox BLEIBT gefüllt, Badge-Änderung sichtbar, Timer resettet.
3. **Completion nach Undo erneut starten:** Undo-Tap → erneut Completion-Tap → Checkbox füllt sich wieder (neuer Timer startet).

### UI Tests (macOS — MacBacklogUITests)

1. **Completion-Undo auf macOS:** gleiche Szenarien wie iOS.

## Changelog

- 2026-03-31: Initial spec erstellt (BUG-126)
