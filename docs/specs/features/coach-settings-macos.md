# Feature Spec: Phase 6a — Coach-Settings in macOS

## Kontext

Monster Coach Settings existieren nur in der iOS `SettingsView`. Die macOS `MacSettingsView` hat 4 Tabs (Allgemein, Kalender, Erinnerungen, Mitteilungen) — kein Coach-Bereich. Ohne diese Settings kann der Coach auf macOS nicht aktiviert werden.

## Ziel

Neuer 5. Tab "Monster Coach" in `MacSettingsView` mit identischen Settings wie iOS.

## Betroffene Datei

- `FocusBloxMac/MacSettingsView.swift` (~70 LoC hinzufuegen)

## UI-Struktur

```
TabView (bestehend: 4 Tabs)
└── NEW Tab 5: "Monster Coach" (systemImage: "figure.mind.and.body")
    └── Form (.formStyle(.grouped))
        └── Section "Monster Coach"
            ├── Toggle: "Monster Coach" → coachModeEnabled
            │   └── [IF coachModeEnabled]
            │       ├── Toggle: "Morgen-Erinnerung" → coachIntentionReminderEnabled
            │       │   └── [IF enabled] DatePicker "Uhrzeit" (hour+minute)
            │       ├── Toggle: "Tages-Erinnerungen" → coachDailyNudgesEnabled
            │       │   └── [IF enabled]
            │       │       ├── Picker "Max. Erinnerungen" [segmented] (1,2,3)
            │       │       ├── DatePicker "Von" (hour only)
            │       │       └── DatePicker "Bis" (hour only)
            │       └── Toggle: "Abend-Erinnerung" → coachEveningReminderEnabled
            │           └── [IF enabled] DatePicker "Uhrzeit" (hour+minute)
            └── Footer (dynamisch):
                ├── coach+nudges: "Erinnert dich tagsueber..."
                ├── coach only: "Erinnert dich morgens..."
                └── coach off: "Aktiviert deinen persoenlichen..."
```

## @AppStorage Properties (hinzuzufuegen)

Alle 11 Keys existieren bereits in `AppSettings.swift` (shared). Muessen als `@AppStorage` in `MacSettingsView` deklariert werden:

| Key | Type | Default |
|-----|------|---------|
| `coachModeEnabled` | Bool | false |
| `coachIntentionReminderEnabled` | Bool | true |
| `coachIntentionReminderHour` | Int | 7 |
| `coachIntentionReminderMinute` | Int | 0 |
| `coachDailyNudgesEnabled` | Bool | true |
| `coachDailyNudgesMaxCount` | Int | 2 |
| `coachNudgeWindowStartHour` | Int | 10 |
| `coachNudgeWindowEndHour` | Int | 18 |
| `coachEveningReminderEnabled` | Bool | true |
| `coachEveningReminderHour` | Int | 20 |
| `coachEveningReminderMinute` | Int | 0 |

## Bindings (4 computed properties)

Identisch zur iOS-Version — mappen Int-Stunden/Minuten auf Date fuer DatePicker:
1. `intentionTimeBinding` (hour + minute)
2. `nudgeWindowStartBinding` (hour only)
3. `nudgeWindowEndBinding` (hour only)
4. `eveningReminderTimeBinding` (hour + minute)

## Accessibility Identifiers

Gleiche IDs wie iOS (konsistentes Testing):
- `coachModeToggle`
- `intentionReminderToggle`, `intentionTimePicker`
- `coachDailyNudgesToggle`, `coachNudgesMaxCountPicker`
- `coachNudgeWindowStartPicker`, `coachNudgeWindowEndPicker`
- `coachEveningReminderToggle`, `coachEveningReminderTimePicker`

## Keine zusaetzlichen Dependencies

- Kein NotificationService-Import noetig (Notifications werden via AppStorage-Keys getriggert, nicht direkt aus Settings)
- Keine neuen Models/Services
- Kein EventKit

## Frame-Anpassung

Bestehend: `.frame(width: 500, height: 400)` — moeglicherweise Hoehe erhoehen auf 450 falls der Coach-Tab mehr Platz braucht. Entscheidung bei Implementation.

## Testplan

- UI Test: Coach-Tab existiert und ist klickbar
- UI Test: Master-Toggle aktivierbar, Unter-Settings erscheinen
- UI Test: Abend-Erinnerung Toggle sichtbar nach Coach-Aktivierung
- Unit Test: nicht noetig (reine UI, keine Business-Logik)
