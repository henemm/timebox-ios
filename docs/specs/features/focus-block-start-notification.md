---
entity_id: focus-block-start-notification
type: feature
created: 2026-01-27
status: draft
workflow: task-3-focus-block-notification
---

# Focus Block Start Notification

## Approval

- [ ] Approved for implementation

## Purpose

Push-Notification 5 Minuten vor Start eines Focus Blocks senden, damit der User sich vorbereiten kann. Falls der Block weniger als 5 Minuten in der Zukunft liegt, wird die Notification direkt bei Start gesendet.

## Scope

| File | Change | Description |
|------|--------|-------------|
| Sources/Services/NotificationService.swift | MODIFY | +scheduleFocusBlockStartNotification(), +cancelFocusBlockNotification() |
| Sources/Views/BlockPlanningView.swift | MODIFY | Nach createFocusBlock() Notification schedulen |
| Sources/Views/EditFocusBlockSheet.swift | MODIFY | Bei Zeit-Aenderung Notification aktualisieren, bei Loeschung cancel |

- Estimated: +55/-0 LoC

## Implementation Details

### NotificationService - Neue Methoden

```swift
// Notification-ID Prefix
private static let focusBlockNotificationPrefix = "focus-block-start-"

/// Schedule notification before focus block starts
/// - minutesBefore: default 5 (hardcoded, spaeter konfigurierbar)
static func scheduleFocusBlockStartNotification(
    blockID: String,
    blockTitle: String,
    startDate: Date,
    minutesBefore: Int = 5
) {
    let now = Date()
    let notifyDate = startDate.addingTimeInterval(-Double(minutesBefore * 60))

    // Wenn notifyDate bereits in der Vergangenheit → bei Start notifyen
    let triggerDate = notifyDate > now ? notifyDate : startDate

    // Wenn auch startDate in der Vergangenheit → keine Notification
    guard triggerDate > now else { return }

    let timeInterval = triggerDate.timeIntervalSince(now)

    let content = UNMutableNotificationContent()
    if triggerDate == startDate {
        content.title = "Focus Block startet jetzt"
        content.body = "\(blockTitle) beginnt jetzt"
    } else {
        content.title = "Focus Block startet gleich"
        content.body = "\(blockTitle) beginnt in \(minutesBefore) Minuten"
    }
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: timeInterval,
        repeats: false
    )

    let request = UNNotificationRequest(
        identifier: "\(focusBlockNotificationPrefix)\(blockID)",
        content: content,
        trigger: trigger
    )

    UNUserNotificationCenter.current().add(request)
}

/// Cancel a scheduled focus block notification
static func cancelFocusBlockNotification(blockID: String) {
    UNUserNotificationCenter.current()
        .removePendingNotificationRequests(
            withIdentifiers: ["\(focusBlockNotificationPrefix)\(blockID)"]
        )
}
```

### BlockPlanningView Integration

```swift
private func createFocusBlock(startDate: Date, endDate: Date) {
    Task {
        do {
            let blockID = try eventKitRepo.createFocusBlock(startDate: startDate, endDate: endDate)

            // Schedule notification
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let title = "Focus Block \(formatter.string(from: startDate))"
            NotificationService.scheduleFocusBlockStartNotification(
                blockID: blockID,
                blockTitle: title,
                startDate: startDate
            )

            await loadData()
        } catch {
            errorMessage = "Focus Block konnte nicht erstellt werden."
        }
    }
}
```

### EditFocusBlockSheet Integration

- Bei Zeitaenderung: `cancelFocusBlockNotification()` + `scheduleFocusBlockStartNotification()` mit neuer Zeit
- Bei Loeschung: `cancelFocusBlockNotification()`

## Test Plan

### Unit Tests (TDD RED)

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | testScheduleNotificationContent | blockTitle + startDate | scheduleFocusBlockStartNotification() | Notification mit korrektem Titel/Body wird erstellt |
| 2 | testNotificationNotScheduledForPastBlock | startDate in der Vergangenheit | scheduleFocusBlockStartNotification() | Keine Notification wird erstellt |
| 3 | testNotificationAtStartIfLessThan5Min | startDate 3 Min in Zukunft | scheduleFocusBlockStartNotification() | Notification bei startDate, nicht 5 Min vorher |
| 4 | testCancelNotification | blockID | cancelFocusBlockNotification() | Pending Notification wird entfernt |
| 5 | testNotificationIdentifierFormat | blockID | scheduleFocusBlockStartNotification() | Identifier = "focus-block-start-{blockID}" |

### UI Tests

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 6 | testCreateBlockSchedulesNotification | BlockPlanningView | User erstellt Focus Block | Notification wird gescheduled (indirekt testbar via App-Zustand) |

## Acceptance Criteria

- [ ] Notification wird 5 Min vor Block-Start gesendet
- [ ] Bei < 5 Min Vorlauf wird bei Start gesendet
- [ ] Vergangene Blocks erzeugen keine Notification
- [ ] Bei Block-Loeschung wird Notification storniert
- [ ] Bei Block-Zeitaenderung wird Notification aktualisiert
- [ ] Notification hat korrekten Titel und Body

## Changelog

- 2026-01-27: Initial spec created
