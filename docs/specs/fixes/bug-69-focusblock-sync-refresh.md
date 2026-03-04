---
entity_id: bug-69-focusblock-sync-refresh
type: bugfix
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [eventkit, sync, focusblock, cross-platform]
---

# Bug 69: FocusBlock Auto-Refresh bei EventKit-Aenderungen

## Approval

- [ ] Approved

## Purpose

FocusBlocks (EventKit Calendar Events) werden nicht automatisch aktualisiert wenn sie sich auf einem anderen Geraet aendern. Ursache: Fehlender `EKEventStoreChangedNotification` Listener + kein scenePhase-Refresh fuer EventKit.

## Problem

- FocusBlock auf iOS erstellt -> macOS zeigt ihn erst nach 1-2 Minuten (manueller Refresh noetig)
- Kein `EKEventStoreChangedNotification` Listener im gesamten Code (0 Treffer)
- Kein scenePhase-Handler fuer EventKit in Planning-Views
- Apple Calendar App zeigt Aenderungen schneller (hat eigene Listener)

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/EventKitRepository.swift | MODIFY | EKEventStoreChangedNotification Listener + eventStoreChangeCount Property |
| Sources/Views/BlockPlanningView.swift | MODIFY | .onChange(of: eventStoreChangeCount) -> loadData() |
| FocusBloxMac/MacPlanningView.swift | MODIFY | .onChange(of: eventStoreChangeCount) -> loadCalendarEvents() |

## Implementation Details

### 1. EventKitRepository.swift

```swift
// Neues Property (tracked by @Observable)
var eventStoreChangeCount = 0

// Im init oder lazy: NotificationCenter Observer
private var eventStoreObserver: Any?

func startObservingEventStoreChanges() {
    eventStoreObserver = NotificationCenter.default.addObserver(
        forName: .EKEventStoreChanged,
        object: eventStore,
        queue: .main
    ) { [weak self] _ in
        self?.eventStoreChangeCount += 1
    }
}
```

### 2. BlockPlanningView.swift (iOS)

```swift
// Neben bestehenden .task und .onChange(selectedDate):
.onChange(of: eventKitRepo.eventStoreChangeCount) {
    Task { await loadData() }
}
```

### 3. MacPlanningView.swift (macOS)

```swift
// Neben bestehenden .task und .onChange(selectedDate):
.onChange(of: eventKitRepo.eventStoreChangeCount) {
    Task { await loadCalendarEvents() }
}
```

## Expected Behavior

- **Vorher:** FocusBlock auf iOS erstellt -> macOS zeigt nichts bis manueller Refresh
- **Nachher:** FocusBlock auf iOS erstellt -> Apple iCloud Calendar synct -> lokale EventKit-DB aktualisiert -> EKEventStoreChangedNotification feuert -> Views laden automatisch neu
- **Latenz:** Abhaengig von Apple iCloud Calendar Sync-Geschwindigkeit (typisch 5-30s)

## Acceptance Criteria

1. EventKitRepository hat einen EKEventStoreChangedNotification Listener
2. eventStoreChangeCount wird bei jeder Notification incrementiert
3. BlockPlanningView (iOS) reagiert auf eventStoreChangeCount und laedt FocusBlocks neu
4. MacPlanningView (macOS) reagiert auf eventStoreChangeCount und laedt CalendarEvents neu
5. Kein manueller Refresh mehr noetig fuer Cross-Device-Aenderungen
6. Bestehende manuelle Refresh-Mechanismen (Pull-to-Refresh, Date-Change) bleiben erhalten
7. Build erfolgreich auf iOS UND macOS

## Test Plan

### Unit Tests (EventKitRepository)
- test_eventStoreChangeCount_incrementsOnNotification: Post .EKEventStoreChanged -> count increments
- test_eventStoreChangeCount_startsAtZero: Initial value is 0

### UI Tests
- test_bloxTab_autoRefreshOnEventKitChange: Verify planning view refreshes (indirekt via Mock)

## Scoping

- **Files:** 3
- **LoC:** ~+30 (minimal)
- **Risk:** LOW (additive, keine bestehende Logik geaendert)

## Known Limitations

- Refresh-Latenz haengt von Apple iCloud Calendar Sync ab (nicht unsere Kontrolle)
- FocusLiveView hat eigene EventKitRepository-Instanz — profitiert aber automatisch weil jede Instanz den Listener bekommt
- MenuBar-Icon hat eigenes 15s-Polling (behaelt das bei)

## Changelog

- 2026-03-04: Initial spec created (Bug 69 Analysis)
