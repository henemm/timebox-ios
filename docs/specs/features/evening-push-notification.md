---
entity_id: evening-push-notification
type: feature
created: 2026-03-13
updated: 2026-03-13
status: draft
version: "1.0"
tags: [monster-coach, notifications, phase-3e]
workflow: feature-3e-abend-push
---

# Evening Push Notification (Monster Coach Phase 3e)

## Approval

- [x] Approved for implementation (2026-03-13)

## Purpose

Optionale Abend-Push-Notification, die den User an den Abend-Spiegel erinnert. Konfigurierbare Uhrzeit (Default 20:00). Feuert nur wenn Coach Mode aktiv UND heutige Intention gesetzt ist. Kein Notification-Spam an Tagen ohne Intention.

## Scope

| File | Change | Description |
|------|--------|-------------|
| `Sources/Models/AppSettings.swift` | MODIFY | 3 neue @AppStorage Properties (Enabled, Hour, Minute) |
| `Sources/Services/NotificationService.swift` | MODIFY | Neuer MARK-Block: build/schedule/cancel Evening Reminder |
| `Sources/Views/SettingsView.swift` | MODIFY | Toggle + DatePicker im Monster Coach Bereich |
| `Sources/Views/MorningIntentionView.swift` | MODIFY | Evening Reminder schedulen nach Intention-Save |
| `Sources/FocusBloxApp.swift` | MODIFY | Schedule/Cancel in scenePhase .active mit isSet-Guard |

- Estimated: +80/-0 LoC (ohne Tests)

## Implementation Details

### AppSettings.swift — Neue Properties

Im bestehenden `// MARK: - Monster Coach` Block, nach den Daily Nudges Properties:

```swift
@AppStorage("coachEveningReminderEnabled") var coachEveningReminderEnabled: Bool = true
@AppStorage("coachEveningReminderHour") var coachEveningReminderHour: Int = 20
@AppStorage("coachEveningReminderMinute") var coachEveningReminderMinute: Int = 0
```

**Default `true`** — analog zu `coachIntentionReminderEnabled`. Feuert erst wenn `coachModeEnabled` ebenfalls aktiv (aeusserer Guard).

### NotificationService.swift — Neuer MARK-Block

Folgt exakt dem Morning Intention Reminder Pattern (Zeilen 414-451):

```swift
// MARK: - Coach Evening Reminder

private static let eveningReminderID = "coach-evening-reminder"

/// Build request for evening reminder. Returns nil if scheduled time already passed today.
static func buildEveningReminderRequest(
    hour: Int,
    minute: Int,
    now: Date = Date()
) -> UNNotificationRequest? {
    // Guard: Wenn die eingestellte Uhrzeit heute schon vorbei ist → nil
    let calendar = Calendar.current
    let currentHour = calendar.component(.hour, from: now)
    let currentMinute = calendar.component(.minute, from: now)
    if currentHour > hour || (currentHour == hour && currentMinute >= minute) {
        return nil
    }

    let content = UNMutableNotificationContent()
    content.title = "Dein Abend-Spiegel wartet"
    content.body = "Wie war dein Tag? Schau kurz rein."
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.hour = hour
    dateComponents.minute = minute

    let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents,
        repeats: true
    )

    return UNNotificationRequest(
        identifier: eveningReminderID,
        content: content,
        trigger: trigger
    )
}

/// Schedule the daily evening reminder. Cancels existing before re-scheduling.
static func scheduleEveningReminder(hour: Int, minute: Int) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [eveningReminderID])

    guard let request = buildEveningReminderRequest(hour: hour, minute: minute) else {
        return
    }
    center.add(request)
}

/// Cancel the evening reminder.
static func cancelEveningReminder() {
    UNUserNotificationCenter.current()
        .removePendingNotificationRequests(withIdentifiers: [eveningReminderID])
}
```

**Design-Entscheidungen:**
- `repeats: true` — konsistent mit Morning Reminder. Guard in scenePhase .active cancelled an Tagen ohne Intention.
- `now:` Parameter — macht Build-Funktion testbar (Zeitfenster-Guard pruefbar)
- Return `nil` wenn Uhrzeit heute vorbei — verhindert sinnlose Notification nach 20:00

### SettingsView.swift — Toggle + DatePicker

Im Monster Coach Bereich, nach den Daily Nudges Controls:

```swift
// MARK: Abend-Erinnerung
Toggle(isOn: $settings.coachEveningReminderEnabled) {
    Label("Abend-Erinnerung", systemImage: "moon.stars")
}
.accessibilityIdentifier("coachEveningReminderToggle")

if settings.coachEveningReminderEnabled {
    DatePicker(
        "Uhrzeit",
        selection: eveningReminderTimeBinding,
        displayedComponents: .hourAndMinute
    )
    .accessibilityIdentifier("coachEveningReminderTimePicker")
}
```

**Neues Binding** (gleiche Struktur wie `intentionTimeBinding`):

```swift
private var eveningReminderTimeBinding: Binding<Date> {
    Binding(
        get: {
            Calendar.current.date(
                from: DateComponents(
                    hour: settings.coachEveningReminderHour,
                    minute: settings.coachEveningReminderMinute
                )
            ) ?? Date()
        },
        set: { newValue in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            settings.coachEveningReminderHour = comps.hour ?? 20
            settings.coachEveningReminderMinute = comps.minute ?? 0
        }
    )
}
```

### MorningIntentionView.swift — Post-Save Scheduling

Im Save-Button Action-Block, nach dem bestehenden Nudge-Scheduling:

```swift
// Schedule evening reminder if enabled
if settings.coachModeEnabled,
   settings.coachEveningReminderEnabled {
    NotificationService.scheduleEveningReminder(
        hour: settings.coachEveningReminderHour,
        minute: settings.coachEveningReminderMinute
    )
}
```

### FocusBloxApp.swift — scenePhase .active Guard

Im `.onChange(of: scenePhase)` Block, nach dem bestehenden Intention Reminder:

```swift
// Coach evening reminder
if settings.coachModeEnabled,
   settings.coachEveningReminderEnabled,
   DailyIntention.load().isSet {
    NotificationService.scheduleEveningReminder(
        hour: settings.coachEveningReminderHour,
        minute: settings.coachEveningReminderMinute
    )
} else {
    NotificationService.cancelEveningReminder()
}
```

**Dreifach-Guard:** coachModeEnabled + eveningReminderEnabled + Intention gesetzt. Alle drei muessen `true` sein, sonst wird gecancelled.

## Expected Behavior

### Normale Nutzung

1. User setzt morgens seine Intention (MorningIntentionView)
2. Evening Reminder wird fuer heute 20:00 Uhr geplant
3. Um 20:00: Push-Notification "Dein Abend-Spiegel wartet"
4. User oeffnet App → sieht EveningReflectionCard im Review-Tab

### Intention NICHT gesetzt

1. User oeffnet App, setzt keine Intention
2. scenePhase .active → Guard `DailyIntention.load().isSet` = false → Cancel
3. Keine abendliche Notification

### Uhrzeit schon vorbei

1. User setzt Intention um 21:00
2. `buildEveningReminderRequest` → `nil` (20:00 < 21:00)
3. Keine Notification — aber `repeats: true` sorgt dafuer, dass ab morgen wieder 20:00 feuert
4. Beim naechsten scenePhase .active wird der Guard erneut geprueft

### Coach Mode deaktiviert

1. `coachModeEnabled = false`
2. Alle Coach-Notifications werden gecancelled (bestehende Logik + neuer Evening Cancel)
3. Settings-Section ist ausgeblendet

### Settings-Aenderung der Uhrzeit

1. User aendert Zeit von 20:00 auf 21:30 in Settings
2. Naechster scenePhase .active → `scheduleEveningReminder(hour: 21, minute: 30)`
3. Alter Reminder wird entfernt, neuer geplant

## Test Plan

### Unit Tests (FocusBloxTests/NotificationEveningReminderTests.swift) — CREATE

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 1 | `test_buildRequest_returnsValidRequest` | hour=20, minute=0, now=15:00 | buildEveningReminderRequest | Request mit ID "coach-evening-reminder", Title "Dein Abend-Spiegel wartet", repeats=true |
| 2 | `test_buildRequest_returnsNil_whenTimeAlreadyPassed` | hour=20, minute=0, now=20:30 | buildEveningReminderRequest | nil |
| 3 | `test_buildRequest_returnsNil_whenExactTime` | hour=20, minute=0, now=20:00 | buildEveningReminderRequest | nil (exakt = schon vorbei) |
| 4 | `test_buildRequest_returnsRequest_oneMinuteBefore` | hour=20, minute=0, now=19:59 | buildEveningReminderRequest | non-nil (noch vor der Zeit) |
| 5 | `test_buildRequest_correctIdentifier` | any valid time | buildEveningReminderRequest | identifier == "coach-evening-reminder" |
| 6 | `test_buildRequest_correctContent` | any valid time | buildEveningReminderRequest | title + body + sound korrekt |
| 7 | `test_buildRequest_triggerIsCalendar` | hour=21, minute=30 | buildEveningReminderRequest | Trigger ist UNCalendarNotificationTrigger mit hour=21, minute=30 |
| 8 | `test_buildRequest_triggerRepeats` | any valid time | buildEveningReminderRequest | trigger.repeats == true |

### UI Tests (FocusBloxUITests/CoachNotificationSettingsUITests.swift) — MODIFY

| # | Test | GIVEN | WHEN | THEN |
|---|------|-------|------|------|
| 9 | `test_eveningReminderToggle_visible` | Coach Mode enabled, Settings open | Scroll to Monster Coach section | "coachEveningReminderToggle" exists |
| 10 | `test_eveningReminderTimePicker_visibleWhenEnabled` | Evening Reminder enabled | Toggle is on | "coachEveningReminderTimePicker" exists |
| 11 | `test_eveningReminderTimePicker_hiddenWhenDisabled` | Evening Reminder disabled | Toggle is off | "coachEveningReminderTimePicker" does not exist |

### Vorbestehende Tests

Alle bestehenden Coach-Notification-Tests bleiben unveraendert. Keine Regression.

## Acceptance Criteria

- [ ] Evening Reminder wird nach Intention-Save geplant
- [ ] Evening Reminder wird gecancelled wenn keine Intention gesetzt
- [ ] Evening Reminder wird gecancelled wenn Coach Mode deaktiviert
- [ ] Notification hat korrekten Titel und Body (deutsch)
- [ ] Uhrzeit ist konfigurierbar in Settings (Default 20:00)
- [ ] Toggle "Abend-Erinnerung" in Settings sichtbar wenn Coach Mode aktiv
- [ ] TimePicker nur sichtbar wenn Toggle aktiv
- [ ] Keine Notification wenn eingestellte Uhrzeit heute schon vorbei
- [ ] 8 Unit Tests gruen
- [ ] 3 UI Tests gruen

## Known Limitations

1. **Kein Deep-Link:** Notification oeffnet die App, aber navigiert NICHT automatisch zum Review-Tab. Deep-Linking ist ein separates Feature (koennte in Phase 3f kommen).
2. **Repeating trotz Intention-Check:** Die Notification nutzt `repeats: true`. An Tagen ohne Intention wird sie in scenePhase .active gecancelled — aber nur wenn der User die App oeffnet. Oeffnet er die App am naechsten Tag nicht, feuert die Notification trotzdem. Akzeptables Verhalten: Eine Erinnerung ist im schlimmsten Fall ein sanfter Nudge.
3. **Keine Lokalisierung:** Titel/Body sind hardcoded deutsch. Lokalisierung ist ein separater Schritt.

## Changelog

- 2026-03-13: Initial spec created
