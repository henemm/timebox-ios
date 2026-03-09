# Bug 85-B: Notification Snooze-Optionen (wie Apple Reminders)

## Problem

Due-Date-Notifications bieten nur "Morgen" (+1 Tag) als Verschiebe-Option. Apple Reminders bietet mehrere Snooze-Optionen. User braucht Flexibilität.

## Gewünschtes Verhalten

4 Notification-Actions (iOS max 4):
1. **"Next Up"** — Task auf Next Up setzen (bestehend)
2. **"Morgen"** — Frist +1 Tag (bestehend, Identifier umbenennen)
3. **"Nächste Woche"** — Frist +7 Tage (NEU)
4. **"Erledigt"** — Task als erledigt markieren (bestehend)

## Betroffene Dateien (3)

### 1. NotificationService.swift (Registrierung)
- `actionPostpone` → `actionPostponeTomorrow` (umbenennen)
- Neues `actionPostponeNextWeek = "ACTION_POSTPONE_NEXT_WEEK"`
- `registerDueDateActions()`: 4 Actions statt 3

### 2. NotificationActionDelegate.swift (iOS/macOS Handler)
- `case actionPostpone` → `case actionPostponeTomorrow` (+1 Tag)
- Neuer `case actionPostponeNextWeek` (+7 Tage)

### 3. WatchNotificationDelegate.swift (watchOS Handler + Registrierung)
- `actionPostpone` → `actionPostponeTomorrow` (umbenennen)
- Neues `actionPostponeNextWeek`
- `registerActions()`: 4 Actions statt 3
- `handleAction`: Neuer Case für +7 Tage

## Implementation Details

### NotificationService.swift
```swift
// Vorher:
static let actionPostpone = "ACTION_POSTPONE"
// Nachher:
static let actionPostponeTomorrow = "ACTION_POSTPONE_TOMORROW"
static let actionPostponeNextWeek = "ACTION_POSTPONE_NEXT_WEEK"
```

### Postpone-Logik (Shared Pattern)
```swift
case NotificationService.actionPostponeTomorrow:
    postponeTask(task, taskID: taskID, byDays: 1, context: context)
case NotificationService.actionPostponeNextWeek:
    postponeTask(task, taskID: taskID, byDays: 7, context: context)
```

## Acceptance Criteria

- [ ] 4 Notification-Actions sichtbar: Next Up, Morgen, Nächste Woche, Erledigt
- [ ] "Morgen" verschiebt dueDate um +1 Tag
- [ ] "Nächste Woche" verschiebt dueDate um +7 Tage
- [ ] Beide reschedule Notifications nach Verschiebung
- [ ] watchOS zeigt die gleichen 4 Actions
- [ ] Alte ACTION_POSTPONE wird nicht mehr verwendet
