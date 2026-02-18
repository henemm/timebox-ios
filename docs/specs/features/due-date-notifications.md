---
entity_id: due-date-notifications
type: feature
created: 2026-02-18
updated: 2026-02-18
status: draft
---

# Push Notifications bei ablaufender Frist

## Approval

- [ ] Approved

## Purpose

Tasks mit einem dueDate erhalten zwei unabhängige, optionale Push-Erinnerungen: eine Morgen-Erinnerung am Fälligkeitstag und eine konfigurierbare Vorab-Erinnerung kurz vor dem Fälligkeitszeitpunkt. Das Feature stellt sicher, dass der User rechtzeitig an anstehende Fristen erinnert wird, ohne manuell nachsehen zu müssen.

## Scope

| File | Change Type | Est. LoC |
|------|-------------|----------|
| `Sources/Services/NotificationService.swift` | MODIFY | ~80 |
| `Sources/Models/AppSettings.swift` | MODIFY | ~15 |
| `Sources/Views/SettingsView.swift` | MODIFY | ~30 |
| `FocusBloxMac/MacSettingsView.swift` | MODIFY | ~30 |
| `Sources/FocusBloxApp.swift` | MODIFY | ~15 |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | ~10 |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | MODIFY | ~3 |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | ~3 |
| `Sources/Views/BacklogView.swift` | MODIFY | ~3 |
| `FocusBloxTests/DueDateNotificationTests.swift` | CREATE | ~80 |
| `FocusBloxUITests/DueDateNotificationUITests.swift` | CREATE | ~40 |

- Estimated total: ~310 LoC

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NotificationService` | module | Bestehendes Pattern fuer Notification-Scheduling erweitern |
| `AppSettings` | module | Neue @AppStorage-Keys fuer Reminder-Konfiguration |
| `LocalTask` | model | dueDate (vollstaendiger Date+Time Zeitpunkt) lesen |
| `SettingsView` | view (iOS) | Neue Section "Frist-Erinnerungen" hinzufuegen |
| `MacSettingsView` | view (macOS) | Neue Section im "Mitteilungen"-Tab hinzufuegen |
| `FocusBloxApp` | app (iOS) | Batch-Reschedule beim Wechsel in .active scenePhase |
| `FocusBloxMacApp` | app (macOS) | Permission-Request + Batch-Reschedule beim App-Start |
| `CreateTaskView` | view | Notification schedulen nach Task-Erstellung mit dueDate |
| `TaskFormSheet` | view | Notification cancel + reschedule nach dueDate-Aenderung |
| `BacklogView` | view | Notification canceln bei Task-Loeschung |
| `UNUserNotificationCenter` | system | iOS/macOS Notification-API |

## Implementation Details

### Notification-Typen

**1. Morgen-Erinnerung**
- Trigger: `UNCalendarNotificationTrigger` mit DateComponents (year, month, day, hour, minute)
- Zeitpunkt: Am Fälligkeitstag zur konfigurierten Uhrzeit (default 09:00)
- Nachricht: `"Heute fällig: [Task-Titel] — pack ihn in einen Sprint"`
- ID-Prefix: `"due-date-morning-"`

**2. Vorab-Erinnerung**
- Trigger: `UNTimeIntervalNotificationTrigger` (berechnet aus `dueDate - advanceMinutes`)
- Vorlaufzeit konfigurierbar (default: 60 Minuten = 1 Stunde)
- Optionen: 15 Min, 30 Min, 1 Std, 2 Std, 1 Tag
- Nachricht: `"[Task-Titel] ist in [Zeitraum] fällig"`
- ID-Prefix: `"due-date-advance-"`

### NotificationService — Neue Methoden (Shared Code)

```swift
// MARK: - Due Date Notifications

private static let dueDateMorningPrefix = "due-date-morning-"
private static let dueDateAdvancePrefix = "due-date-advance-"

/// Pure/testable: erstellt den Morning-Request oder nil wenn nicht sinnvoll
static func buildDueDateMorningRequest(
    taskID: String,
    title: String,
    dueDate: Date,
    morningHour: Int,
    morningMinute: Int,
    now: Date = Date()
) -> UNNotificationRequest? {
    // dueDate in der Vergangenheit → kein Request
    guard dueDate > now else { return nil }

    // Morgen-Uhrzeit am Faelligkeitstag berechnen
    var cal = Calendar.current
    var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
    comps.hour = morningHour
    comps.minute = morningMinute
    comps.second = 0
    guard let fireDate = cal.date(from: comps) else { return nil }

    // Morgen-Erinnerung liegt nach dem dueDate-Zeitpunkt → zu spaet, kein Request
    guard fireDate < dueDate else { return nil }
    // Morgen-Erinnerung liegt in der Vergangenheit → kein Request
    guard fireDate > now else { return nil }

    let content = UNMutableNotificationContent()
    content.title = "Heute fällig"
    content.body = "\(title) — pack ihn in einen Sprint"
    content.sound = .default

    let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

    return UNNotificationRequest(
        identifier: "\(dueDateMorningPrefix)\(taskID)",
        content: content,
        trigger: trigger
    )
}

/// Pure/testable: erstellt den Advance-Request oder nil wenn nicht sinnvoll
static func buildDueDateAdvanceRequest(
    taskID: String,
    title: String,
    dueDate: Date,
    advanceMinutes: Int,
    now: Date = Date()
) -> UNNotificationRequest? {
    // dueDate in der Vergangenheit → kein Request
    guard dueDate > now else { return nil }

    let fireDate = dueDate.addingTimeInterval(-Double(advanceMinutes * 60))

    // Vorlaufzeit groesser als verbleibende Zeit → kein Request
    guard fireDate > now else { return nil }

    let timeInterval = fireDate.timeIntervalSince(now)

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = "\(title) ist in \(formattedDuration(advanceMinutes)) fällig"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

    return UNNotificationRequest(
        identifier: "\(dueDateAdvancePrefix)\(taskID)",
        content: content,
        trigger: trigger
    )
}

/// Liest Settings, baut Requests, schreibt in UNUserNotificationCenter
static func scheduleDueDateNotifications(taskID: String, title: String, dueDate: Date) {
    let settings = AppSettings.shared
    let center = UNUserNotificationCenter.current()

    if settings.dueDateMorningReminderEnabled {
        if let req = buildDueDateMorningRequest(
            taskID: taskID, title: title, dueDate: dueDate,
            morningHour: settings.dueDateMorningReminderHour,
            morningMinute: settings.dueDateMorningReminderMinute
        ) { center.add(req) }
    }

    if settings.dueDateAdvanceReminderEnabled {
        if let req = buildDueDateAdvanceRequest(
            taskID: taskID, title: title, dueDate: dueDate,
            advanceMinutes: settings.dueDateAdvanceReminderMinutes
        ) { center.add(req) }
    }
}

/// Entfernt beide pending DueDate-Notifications fuer eine Task
static func cancelDueDateNotifications(taskID: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
        "\(dueDateMorningPrefix)\(taskID)",
        "\(dueDateAdvancePrefix)\(taskID)"
    ])
}

/// Batch: alle bestehenden DueDate-Notifications entfernen und fuer max. 25 Tasks neu schedulen.
/// Tasks werden nach naechstem dueDate sortiert (Prioritaet fuer naehestes Faelligkeitsdatum).
static func rescheduleAllDueDateNotifications(
    tasks: [(id: String, title: String, dueDate: Date)]
) {
    let center = UNUserNotificationCenter.current()
    // Alle bestehenden DueDate-Notifications canceln
    center.getPendingNotificationRequests { requests in
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(dueDateMorningPrefix) || $0.hasPrefix(dueDateAdvancePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        // Max. 25 Tasks nach naehestem dueDate sortiert schedulen (2 Notifications je Task = 50 Slots)
        let now = Date()
        let sorted = tasks
            .filter { $0.dueDate > now }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(25)

        for task in sorted {
            scheduleDueDateNotifications(taskID: task.id, title: task.title, dueDate: task.dueDate)
        }
    }
}
```

### AppSettings — Neue Keys

```swift
// MARK: - Due Date Notifications
@AppStorage("dueDateMorningReminderEnabled") var dueDateMorningReminderEnabled: Bool = true
@AppStorage("dueDateMorningReminderHour") var dueDateMorningReminderHour: Int = 9     // 0-23
@AppStorage("dueDateMorningReminderMinute") var dueDateMorningReminderMinute: Int = 0  // 0-59
@AppStorage("dueDateAdvanceReminderEnabled") var dueDateAdvanceReminderEnabled: Bool = false
@AppStorage("dueDateAdvanceReminderMinutes") var dueDateAdvanceReminderMinutes: Int = 60 // default 1h
```

### Settings UI — iOS (SettingsView)

Neue Section zwischen "Vorwarnung" und "Tasks":

```swift
Section {
    Toggle("Morgen-Erinnerung", isOn: $settings.dueDateMorningReminderEnabled)
    if settings.dueDateMorningReminderEnabled {
        DatePicker(
            "Uhrzeit",
            selection: morningTimeBinding,  // computed aus hour/minute
            displayedComponents: .hourAndMinute
        )
    }
    Toggle("Vorab-Erinnerung", isOn: $settings.dueDateAdvanceReminderEnabled)
    if settings.dueDateAdvanceReminderEnabled {
        Picker("Vorlaufzeit", selection: $settings.dueDateAdvanceReminderMinutes) {
            Text("15 Min").tag(15)
            Text("30 Min").tag(30)
            Text("1 Stunde").tag(60)
            Text("2 Stunden").tag(120)
            Text("1 Tag").tag(1440)
        }
    }
} header: {
    Text("Frist-Erinnerungen")
} footer: {
    Text("Erinnerung wenn Tasks mit Frist fällig werden.")
}
```

### Settings UI — macOS (MacSettingsView)

Gleiche Struktur wie iOS, eingebettet in den bestehenden "Mitteilungen"-Tab.

### Trigger-Points

```swift
// CreateTaskView.swift — nach Task-Erstellung mit dueDate
if let dueDate = task.dueDate {
    NotificationService.scheduleDueDateNotifications(taskID: task.id, title: task.title, dueDate: dueDate)
}

// TaskFormSheet.swift — nach dueDate-Aenderung
NotificationService.cancelDueDateNotifications(taskID: task.id)
if let dueDate = task.dueDate {
    NotificationService.scheduleDueDateNotifications(taskID: task.id, title: task.title, dueDate: dueDate)
}

// BacklogView.swift — bei Task-Loeschung
NotificationService.cancelDueDateNotifications(taskID: task.id)
```

### App-Lifecycle

```swift
// FocusBloxApp.swift (iOS) — bei scenePhase == .active
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        let tasks = /* fetch tasks with dueDate from modelContext */
        NotificationService.rescheduleAllDueDateNotifications(tasks: tasks)
    }
}

// FocusBloxMacApp.swift (macOS) — beim Start
NotificationService.requestPermission()
let tasks = /* fetch tasks with dueDate */
NotificationService.rescheduleAllDueDateNotifications(tasks: tasks)
```

### 64-Notification-Limit Budget

| Kategorie | Slots |
|-----------|-------|
| task-timer | ~5 |
| focus-block-start | ~3 |
| focus-block-end | ~3 |
| due-date (max 25 Tasks × 2) | ~50 |
| **Gesamt** | **~61** (innerhalb des 64-Limits) |

## Expected Behavior

- **Input:** Task mit dueDate (vollstaendiger Date+Time Zeitpunkt)
- **Output:** 0, 1 oder 2 pending Local Notifications pro Task (je nach Settings + Edge Cases)
- **Side effects:**
  - Bei Settings-Aenderung: naechster App-Foreground reschedult alle DueDate-Notifications
  - Bei Task-Loeschung oder -Abschluss: zugehoerige Notifications werden sofort storniert
  - Batch-Reschedule priorisiert Tasks mit naehestem dueDate (max. 25 Tasks = 50 Notification-Slots)

## Edge Cases

- **dueDate in der Vergangenheit:** keine Notification schedulen
- **Morgen-Uhrzeit liegt nach dueDate-Zeitpunkt:** keine Morgen-Notification (zu spaet)
- **Vorlaufzeit groesser als verbleibende Zeit:** keine Vorab-Notification
- **Task completed:** `cancelDueDateNotifications()` aufrufen
- **Task geloescht:** `cancelDueDateNotifications()` aufrufen
- **Settings geaendert:** naechster App-Foreground loest Batch-Reschedule aus
- **Recurring Tasks:** jede Instanz hat eigenes dueDate und wird individuell gescheduled

## Test Plan

### Unit Tests — `FocusBloxTests/DueDateNotificationTests.swift`

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | `buildDueDateMorningRequest_normalCase` | dueDate morgen 18:00, morningHour 9, now jetzt | `buildDueDateMorningRequest()` | Request mit CalendarTrigger fuer 09:00 morgen, korrekter Body |
| 2 | `buildDueDateMorningRequest_pastDueDate` | dueDate gestern | `buildDueDateMorningRequest()` | `nil` |
| 3 | `buildDueDateMorningRequest_morningAfterDueDate` | dueDate heute 08:00, morningHour 9 | `buildDueDateMorningRequest()` | `nil` (Morgen-Uhrzeit waere nach Faelligkeit) |
| 4 | `buildDueDateAdvanceRequest_normalCase` | dueDate in 2h, advanceMinutes 60 | `buildDueDateAdvanceRequest()` | Request mit TimeIntervalTrigger fuer 1h ab jetzt |
| 5 | `buildDueDateAdvanceRequest_pastDueDate` | dueDate gestern | `buildDueDateAdvanceRequest()` | `nil` |
| 6 | `buildDueDateAdvanceRequest_advanceLargerThanRemaining` | dueDate in 30 Min, advanceMinutes 60 | `buildDueDateAdvanceRequest()` | `nil` |
| 7 | `rescheduleAllDueDateNotifications_respectsMaxLimit` | 30 Tasks mit dueDate in Zukunft | `rescheduleAllDueDateNotifications()` | Nur 25 Tasks werden gescheduled |
| 8 | `rescheduleAllDueDateNotifications_sortsByNearestDueDate` | Tasks mit verschiedenen dueDates | `rescheduleAllDueDateNotifications()` | Tasks mit naehestem dueDate erhalten Prioritaet |

### UI Tests — `FocusBloxUITests/DueDateNotificationUITests.swift`

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | `testSettingsSectionVisible` | Settings geoeffnet | Scrollen zu "Frist-Erinnerungen" | Section "Frist-Erinnerungen" ist sichtbar |
| 2 | `testMorningReminderToggleShowsTimePicker` | Toggle "Morgen-Erinnerung" ist OFF | Toggle wird auf ON gestellt | Uhrzeit-DatePicker erscheint |
| 3 | `testAdvanceReminderToggleShowsPicker` | Toggle "Vorab-Erinnerung" ist OFF | Toggle wird auf ON gestellt | Vorlaufzeit-Picker erscheint |

## Acceptance Criteria

- [ ] Morgen-Erinnerung sendet am Faelligkeitstag zur konfigurierten Uhrzeit (default 09:00)
- [ ] Vorab-Erinnerung sendet X Minuten/Stunden vor dem dueDate-Zeitpunkt
- [ ] Beide Erinnerungen sind unabhaengig aktivierbar/deaktivierbar
- [ ] dueDate in der Vergangenheit erzeugt keine Notification
- [ ] Morgen-Uhrzeit nach dueDate erzeugt keine Morgen-Notification
- [ ] Vorlaufzeit > verbleibende Zeit erzeugt keine Vorab-Notification
- [ ] Task-Loeschung storniert beide Notifications
- [ ] Task-Abschluss storniert beide Notifications
- [ ] dueDate-Aenderung aktualisiert beide Notifications (cancel + reschedule)
- [ ] Settings-Aenderung wird beim naechsten App-Foreground wirksam (Batch-Reschedule)
- [ ] Batch-Reschedule respektiert max. 25 Tasks (50 Notification-Slots)
- [ ] Batch-Reschedule priorisiert naechste Faelligkeitsdaten
- [ ] Settings-UI zeigt Section "Frist-Erinnerungen" auf iOS und macOS
- [ ] Notification-IDs folgen dem Schema `"due-date-morning-{taskID}"` und `"due-date-advance-{taskID}"`
- [ ] Alle Unit Tests gruen
- [ ] Alle UI Tests gruen

## Changelog

- 2026-02-18: Initial spec created
