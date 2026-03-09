# Bug: Watch Notification Actions wirkungslos

## Problem
Interaktive Notification-Actions (NextUp, Postpone, Complete) auf der Apple Watch
werden still ignoriert. Task-Status aendert sich auf keiner Plattform.

## Root Cause
Watch App (`FocusBloxWatchApp.swift`) registriert keinen `UNUserNotificationCenterDelegate`.
Wenn User eine Notification-Action auf Watch klickt, findet watchOS keinen Handler.

iOS und macOS registrieren den Delegate korrekt. Watch nicht.

## Zusaetzliche Komplikation
Das Watch-Target kompiliert nur Dateien aus `FocusBloxWatch Watch App/`.
`NotificationActionDelegate` und `NotificationService` aus `Sources/` sind nicht verfuegbar.
Ein eigener, minimaler Watch-Handler ist noetig.

## Fix

### Neue Datei: `FocusBloxWatch Watch App/WatchNotificationDelegate.swift`
- `@MainActor final class WatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate`
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` extrahiert `taskID` + `actionIdentifier`
- `handleAction(_:taskID:)` mit Switch ueber die 3 Action-IDs:
  - `ACTION_NEXT_UP`: `task.isNextUp = true`, `nextUpSortOrder = maxOrder + 1`
  - `ACTION_POSTPONE`: `task.dueDate += 1 Tag`
  - `ACTION_COMPLETE`: `task.isCompleted = true`, `task.completedAt = Date()`, `task.isNextUp = false`
- `task.modifiedAt = Date()` + `context.save()` fuer CloudKit-Sync
- `willPresent` Callback: `.banner, .sound`

### Aenderung: `FocusBloxWatch Watch App/FocusBloxWatchApp.swift`
- `@State private var notificationDelegate: WatchNotificationDelegate?`
- In `body`: `.onAppear` auf ContentView hinzufuegen
- Darin: Notification-Kategorien registrieren + Delegate erstellen + als UNCenter delegate setzen
- Starke Referenz in `@State` halten (verhindert Deallocation)

### Action-IDs (hardcoded, passend zu iOS NotificationService)
- `ACTION_NEXT_UP`
- `ACTION_POSTPONE`
- `ACTION_COMPLETE`
- Kategorie: `DUE_DATE_INTERACTIVE`

## Dateien
- 1 neue: `WatchNotificationDelegate.swift` (~50 LoC)
- 1 geaendert: `FocusBloxWatchApp.swift` (~15 LoC)

## Blast Radius
- Alle 3 Watch Notification Actions gefixt
- Kein Einfluss auf iOS/macOS (eigener Code)
