---
entity_id: smart_nudges
type: feature
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [notifications, nudges, settings, epic-170]
github_issue: "#174"
---

# Smart Nudges — Budget, Stille bei Erfolg, konfigurierbare Zeiten

## Approval

- [ ] Approved

## Purpose

Nudge-Notifications von 6 festen Uhrzeiten (9,11,13,15,17,19) auf ein konfigurierbares Budget (1-3/Tag) umbauen. Stille bei Erfolg: Wer genug Tasks erledigt hat, wird nicht weiter gestört. Morning- und Evening-Zeiten werden konfigurierbar statt hardcoded.

Psychologische Grundlage: Notification Fatigue (>3/Tag → Ignorieren), Self-Determination Theory (Autonomie durch Konfigurierbarkeit).

## Source

- **Files:**
  - `Sources/Services/SmartNotificationEngine.swift` — `buildNudgeRequests()` (Z.375-415), `buildReviewRequests()` (Z.318-371)
  - `Sources/Models/AppSettings.swift` — Notification-Properties (Z.55-98)
  - `Sources/Views/SettingsView.swift` — Notification-Profile-Picker (Z.37-48)
  - `Sources/Services/EmotionalNudgeService.swift` — `canShowNudge()` (Z.29-40)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SmartNotificationEngine` | Service | Orchestrator für alle Notifications |
| `AppSettings` | Model | Persistenz der Konfiguration via `@AppStorage` |
| `NotificationContentService` | Service | AI-Content + Fallback-Templates |
| `EmotionalNudgeService` | Service | In-App Nudges mit eigenem Budget (hardcoded `< 3`) |
| `UNUserNotificationCenter` | Framework | iOS Push-Delivery |

## Changes

### 1. AppSettings — Neue Properties

```swift
// MARK: - Smart Nudge Settings

/// Maximale Nudges pro Tag (1-3, Default: 2)
@AppStorage("nudgeDailyBudget") var nudgeDailyBudget: Int = 2

// Nudge-Zeitfenster: morningReminderHour+1 bis eveningReflectionHour (abgeleitet, kein eigenes Setting)

/// Morning-Reminder Stunde (0-23, Default: 8)
@AppStorage("morningReminderHour") var morningReminderHour: Int = 8

/// Morning-Reminder Minute (0-59, Default: 0)
@AppStorage("morningReminderMinute") var morningReminderMinute: Int = 0

/// Abend-Reflexion Stunde (0-23, Default: 20)
@AppStorage("eveningReflectionHour") var eveningReflectionHour: Int = 20

/// Abend-Reflexion Minute (0-59, Default: 0)
@AppStorage("eveningReflectionMinute") var eveningReflectionMinute: Int = 0

/// Stille bei Erfolg: Nudges stoppen wenn genug Tasks erledigt
@AppStorage("nudgeSilenceOnSuccess") var nudgeSilenceOnSuccess: Bool = true
```

### 2. SmartNotificationEngine — buildNudgeRequests()

**Vorher:** 6 feste Slots (9,11,13,15,17,19), statische Texte, Budget-Cap 10.

**Nachher:**
```swift
static func buildNudgeRequests(
    now: Date = Date(),
    completedTodayCount: Int = 0
) -> [UNNotificationRequest] {
    let settings = AppSettings.shared
    let budget = settings.nudgeDailyBudget  // 1-3
    let windowStart = settings.morningReminderHour + 1  // Nudges starten 1h nach "Dein Tag"
    let windowEnd = settings.eveningReflectionHour      // Nudges enden bei Abend-Reflexion

    // Stille bei Erfolg: Genug Tasks → keine Nudges
    if settings.nudgeSilenceOnSuccess && completedTodayCount >= budget {
        return []
    }

    // Slots gleichmäßig im Zeitfenster verteilen
    let slots = distributeSlots(count: budget, startHour: windowStart, endHour: windowEnd)

    // Nur zukünftige Slots, mit rotierenden Texten
    // ... (analog zum bestehenden Pattern)
}
```

**Slot-Verteilung:** Bei Budget 2 und Fenster 10-18 → Slots bei 12:00, 16:00. Bei Budget 3 → 11:00, 14:00, 17:00. Gleichmäßig verteilt.

**Stille-Regel:** `completedTodayCount` wird von `buildAllRequests()` übergeben (analog zu `precomputeNotificationContent` das bereits Tasks fetcht).

### 3. SmartNotificationEngine — buildReviewRequests()

**Vorher:** Morning hardcoded 08:00, Evening hardcoded 20:00.

**Nachher:** Liest `morningReminderHour/Minute` und `eveningReflectionHour/Minute` aus AppSettings.

```swift
// Zeile 328: 20 → settings.eveningReflectionHour
// Zeile 348: 8 → settings.morningReminderHour
```

### 4. SmartNotificationEngine — budgetNudges

**Vorher:** `static let budgetNudges: Int = 10`

**Nachher:** `static var budgetNudges: Int { AppSettings.shared.nudgeDailyBudget * 7 }`

(Max 3 Nudges × 7 Tage = 21. Passt ins 64er iOS-Gesamtbudget.)

### 5. EmotionalNudgeService — canShowNudge()

**Vorher:** `guard settings.nudgeDailyCount < 3` (hardcoded)

**Nachher:** `guard settings.nudgeDailyCount < settings.nudgeDailyBudget`

### 6. SettingsView — Neue "Erinnerungszeiten" Section

Neue Section nach dem bestehenden "Profil"-Picker:

```swift
Section {
    // Nur sichtbar wenn Profil == .active
    Stepper("Max. Nudges: \(nudgeDailyBudget)", value: $nudgeDailyBudget, in: 1...3)

    Toggle("Stille bei Erfolg", isOn: $nudgeSilenceOnSuccess)

    // Nudge-Zeitfenster ergibt sich aus "Dein Tag"+1h bis Abend-Reflexion
} header: {
    Text("Tages-Nudges")
}

Section {
    DatePicker("Morgengruß", ...)  // morningReminderHour/Minute
    DatePicker("Abend-Reflexion", ...)  // eveningReflectionHour/Minute
} header: {
    Text("Erinnerungszeiten")
}
```

**Profil-Footer aktualisieren:** "Aktiv" Beschreibung von "alle 2 Stunden (9–19 Uhr)" auf "bis zu N Nudges pro Tag" ändern.

### 7. SettingsView Footer-Text

**Vorher:** `"Aktiv — Alles + Motivations-Nachrichten alle 2 Stunden (9–19 Uhr)."`

**Nachher:** `"Aktiv — Alles + konfigurierbare Tages-Nudges."`

## Expected Behavior

- **Profil "Leise":** Nur Timer. Keine Nudges, kein Morning/Evening.
- **Profil "Ausgeglichen":** Timer + Task-Erinnerungen + Morning/Evening zu konfigurierbaren Zeiten. Keine Nudges.
- **Profil "Aktiv":** Alles + 1-3 Nudges/Tag, gleichmäßig im konfigurierten Zeitfenster verteilt.
- **Stille bei Erfolg (Default: An):** Wenn `completedTodayCount >= nudgeDailyBudget` → 0 Nudges.
- **Ohne genug erledigte Tasks:** Nudges feuern normal im Zeitfenster.

## Edge Cases

| Fall | Verhalten |
|------|-----------|
| Zeitfenster Start >= Ende | Keine Nudges (ungültige Config) |
| Budget = 1 | Ein Nudge in der Mitte des Zeitfensters |
| Morning-Zeit > Evening-Zeit | Beide unabhängig, kein Konflikt |
| Profil wechselt mid-day | `reconcile(.profileChanged)` baut Queue neu |

## Acceptance Criteria

- [ ] Nudge-Budget konfigurierbar (1-3 pro Tag) in Settings
- [ ] Stille bei Erfolg: Nach genug erledigten Tasks keine weiteren Nudges
- [ ] Morning-Reminder-Zeit konfigurierbar (Default: 08:00)
- [ ] Abend-Reflexion-Zeit konfigurierbar (Default: 20:00)
- [ ] Nudge-Zeitfenster = "Dein Tag"-Zeit+1h bis Abend-Reflexion-Zeit (abgeleitet, kein eigenes Setting)
- [ ] EmotionalNudgeService respektiert konfiguriertes Budget
- [ ] Profil-Footer in Settings aktualisiert
- [ ] Alte 6-Slot-Logik vollständig ersetzt
- [ ] Settings synchron auf iOS + macOS (AppStorage)

## Test Plan

### Unit Tests (SmartNotificationEnginePhaseDTests)

1. `test_buildNudgeRequests_respectsBudget_1` — Budget=1 → max 1 Request
2. `test_buildNudgeRequests_respectsBudget_3` — Budget=3 → max 3 Requests
3. `test_buildNudgeRequests_silenceOnSuccess` — completedToday >= budget → 0 Requests
4. `test_buildNudgeRequests_silenceOnSuccess_disabled` — Flag aus → Nudges trotz Tasks
5. `test_buildNudgeRequests_customWindow` — Fenster 12-16 → Slots nur in diesem Bereich
6. `test_buildNudgeRequests_invalidWindow` — Start >= Ende → 0 Requests
7. `test_buildReviewRequests_customMorningTime` — Morning um 07:30 statt 08:00
8. `test_buildReviewRequests_customEveningTime` — Evening um 21:00 statt 20:00

### UI Tests

9. `test_settings_nudgeBudgetStepper` — Stepper zwischen 1-3 verstellbar
10. `test_settings_morningTimePicker` — Morning-Zeit änderbar
11. `test_settings_eveningTimePicker` — Evening-Zeit änderbar
12. `test_settings_silenceToggle` — Toggle sichtbar und schaltbar

## Scope

- **Files:** 5 (AppSettings, SmartNotificationEngine, EmotionalNudgeService, SettingsView, Tests)
- **Estimated LoC:** +110 / -15
- **Risk:** Niedrig

## Known Limitations

- BehavioralProfile-basiertes Timing ist NICHT Teil dieses Tickets (→ #174b)
- Nudge-Slot-Verteilung ist gleichmäßig, nicht intelligent
- Nudge-Texte bleiben statisch (AI-generierte Nudge-Texte kommen später)

## Changelog

- 2026-03-31: Initial spec created (EPIC_170c, #174)
