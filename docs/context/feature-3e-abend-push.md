# Context: Feature 3e — Abend Push-Notification

## Request Summary
Optionale, konfigurierbare Abend-Push-Notification (Default 20:00 Uhr), die den User an den Abend-Spiegel erinnert. Nur wenn `coachModeEnabled == true` UND heutige Intention gesetzt ist.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/NotificationService.swift` | Alle Notification-Patterns — neuer MARK-Block fuer Evening Reflection |
| `Sources/Models/AppSettings.swift` | Monster Coach Settings — 3 neue AppStorage-Properties |
| `Sources/Views/SettingsView.swift` | Monster Coach UI-Sektion — Toggle + DatePicker hinzufuegen |
| `Sources/Views/MorningIntentionView.swift` | Post-Save Hook — Evening Notification schedulen nach Intention-Speicherung |
| `Sources/FocusBloxApp.swift` | scenePhase .active — Scheduling/Cancellation bei App-Vordergrund |
| `Sources/Models/DailyIntention.swift` | `isSet`-Check — Guard-Bedingung fuer Scheduling |
| `Sources/Views/EveningReflectionCard.swift` | Ziel der Notification — Review-Tab ab 18 Uhr |
| `Sources/Services/EveningReflectionTextService.swift` | Phase 3d AI-Text — nicht direkt betroffen |

## Existing Patterns

### Notification-Pattern (NotificationService.swift)
- `@MainActor enum NotificationService` — rein statische Funktionen
- ID-Konstante oben im MARK-Block (`private static let ...ID = "coach-..."`)
- **Build-Funktion** (testbar, `now: Date = Date()`) → `UNNotificationRequest?`
- **Schedule-Funktion** liest Settings, ruft Build auf, `center.add(request)`
- **Cancel-Funktion** entfernt per Identifier

### Engste Vorlage: Morning Intention Reminder
- `buildIntentionReminderRequest(hour:minute:)` — `UNCalendarNotificationTrigger` mit DateComponents
- Morning = `repeats: true` (taeglich)
- **3e-Unterschied:** `repeats: false` + spezifisches Datum (nur heute), weil Intention taeglich neu gesetzt werden muss

### AppSettings-Pattern (Monster Coach Section)
```swift
@AppStorage("coachIntentionReminderEnabled") var coachIntentionReminderEnabled: Bool = true
@AppStorage("coachIntentionReminderHour") var coachIntentionReminderHour: Int = 7
@AppStorage("coachIntentionReminderMinute") var coachIntentionReminderMinute: Int = 0
```
→ Gleiche Struktur fuer Evening: Enabled + Hour + Minute

### SettingsView-Pattern (Monster Coach Section)
- Toggle mit `.accessibilityIdentifier("...Toggle")`
- Bedingt: DatePicker mit Binding (`intentionTimeBinding`-Muster)
- Bestehende Accessibility-IDs: `coachIntentionReminderToggle`, `coachDailyNudgesToggle`

### Scheduling-Trigger-Points
1. **MorningIntentionView** Save-Action (Zeile 84-116): Speichert Intention, scheduled Nudges → hier auch Evening schedulen
2. **FocusBloxApp** `scenePhase == .active` (Zeile 315-336): Prueft & scheduled/cancelled bestehende Coach-Notifications

## Dependencies

### Upstream (was unser Code nutzt)
- `UNUserNotificationCenter` (UserNotifications Framework)
- `AppSettings.shared` fuer coachModeEnabled + neue Evening-Settings
- `DailyIntention.load().isSet` als Guard
- `IntentionOption` Enum fuer optionalen Notification-Text

### Downstream (was unseren Code nutzt)
- `FocusBloxApp` ruft Schedule/Cancel auf
- `MorningIntentionView` ruft Schedule auf
- `SettingsView` zeigt/aendert Settings

## Bestehende Notification-IDs (keine Kollision!)
- `"task-timer-"`, `"focus-block-start-"`, `"focus-block-end-"`
- `"due-date-morning-"`, `"due-date-advance-"`
- `"coach-intention-reminder"`, `"coach-nudge-"`
- **Neu:** `"coach-evening-reflection"`

## Existing Specs
- `docs/project/stories/monster-coach.md` — User Story mit Phase 3e Beschreibung

## Geschaetzte Aenderungen
- **5 bestehende Dateien** modifizieren + **1 neue Test-Datei**
- **~130 LoC** geschaetzt
- Innerhalb der Scoping-Limits (max 5 Dateien, ±250 LoC)

## Risks & Considerations
- **Non-repeating Trigger:** Evening Notification muss taeglich NEU geplant werden (beim Intention-Setzen + bei App-Vordergrund). Sonst feuert sie auf Tagen ohne Intention.
- **Zeitfenster-Logik:** Wenn die Intention NACH 20:00 gesetzt wird, soll keine Notification mehr kommen (schon vorbei).
- **macOS:** SettingsView existiert nur einmal (Shared) — kein Divergenz-Problem.
- **Notification-Permission:** Wird bereits durch bestehende Coach-Features angefragt — kein neuer Permission-Request noetig.

---

## Analysis

### Type
Feature (Monster Coach Phase 3e)

### Design-Entscheidung: repeats:true + Guard vs. repeats:false

**Empfehlung: `repeats: true` + Cancel-Guard** (wie Morning Reminder)
- Konsistent mit bestehendem Pattern (Morning Reminder nutzt `repeats: true`)
- Einfacher: Schedule einmal, Guard in `scenePhase .active` cancelled wenn keine Intention
- Kein Datum-spezifischer Trigger noetig
- Sicherer: Bei App-Vordergrund wird immer geprueft ob Intention gesetzt ist

**Scheduling-Logik:**
1. `MorningIntentionView` Save → `scheduleEveningReminder(hour, minute)` (Intention wurde gerade gesetzt)
2. `FocusBloxApp` `.active` → Guard: `coachModeEnabled && eveningReminderEnabled && DailyIntention.load().isSet` → schedule, sonst cancel
3. Zeitfenster-Guard in Build-Funktion: Wenn aktuelle Uhrzeit >= eingestellte Zeit → nil zurueckgeben (heute schon vorbei)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/NotificationService.swift` | MODIFY | Neuer `// MARK: - Coach Evening Reminder` Block: build/schedule/cancel (~35 LoC) |
| `Sources/Models/AppSettings.swift` | MODIFY | 3 neue `@AppStorage` Properties im Monster Coach Block (~3 LoC) |
| `Sources/Views/SettingsView.swift` | MODIFY | Toggle + DatePicker + Binding im Monster Coach Bereich (~25 LoC) |
| `Sources/Views/MorningIntentionView.swift` | MODIFY | Evening Reminder schedulen nach Intention-Save (~5 LoC) |
| `Sources/FocusBloxApp.swift` | MODIFY | Evening Reminder schedule/cancel in scenePhase .active (~8 LoC) |
| `FocusBloxTests/NotificationEveningReminderTests.swift` | CREATE | Unit Tests fuer buildEveningReminderRequest (~60 LoC) |
| `FocusBloxUITests/CoachNotificationSettingsUITests.swift` | MODIFY | UI Tests fuer Evening Toggle + Picker (~20 LoC) |

### Scope Assessment
- **Files:** 5 MODIFY + 1 CREATE + 1 MODIFY (Tests) = 7
- **Estimated LoC:** +156 / -0
- **Risk Level:** LOW — folgt exakt bestehendem Pattern, keine Architektur-Aenderung

### Technical Approach
1. `AppSettings`: 3 Properties hinzufuegen (Enabled, Hour, Minute)
2. `NotificationService`: MARK-Block mit build/schedule/cancel (Kopie von Morning Reminder, angepasst)
3. `SettingsView`: Toggle + DatePicker im Monster Coach Bereich (Kopie von Morning-Pattern)
4. `MorningIntentionView`: Schedule-Call nach Intention-Save
5. `FocusBloxApp`: Schedule/Cancel in scenePhase .active mit DailyIntention.isSet Guard

### Notification Content
```
Title: "Dein Abend-Spiegel wartet"
Body:  "Wie war dein Tag? Schau kurz rein."
Sound: .default
```

### Dependencies
- **Upstream:** UNUserNotificationCenter, AppSettings, DailyIntention
- **Downstream:** FocusBloxApp, MorningIntentionView, SettingsView
- **Keine neuen Frameworks/Libraries noetig**

### Open Questions
- Keine — alle Anforderungen sind klar definiert
