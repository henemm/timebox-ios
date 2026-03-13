---
entity_id: phase-3f-siri-integration
type: feature
created: 2026-03-13
updated: 2026-03-13
status: draft
version: "1.0"
tags: [monster-coach, siri, app-intents, phase-3f]
---

# Phase 3f: Siri Integration / App Intents

## Approval

- [ ] Approved

## Purpose

Zwei neue Siri-Intents fuer den Monster Coach: (1) "Wie war mein Tag?" liest die Abend-Auswertung per Siri vor, (2) "Setz meine Intention auf Fokus" setzt die Tages-Intention per Sprache. Damit wird der Coach-Flow (Morgen → Tag → Abend) komplett per Siri steuerbar.

## Source

- **Files (CREATE):**
  - `Sources/Intents/GetEveningSummaryIntent.swift` — Intent "Wie war mein Tag?"
  - `Sources/Intents/SetDailyIntentionIntent.swift` — Intent "Setz Intention"
  - `Sources/Intents/IntentionOptionEnum.swift` — AppEnum fuer Siri-Parameter
- **Files (MODIFY):**
  - `Sources/Models/DailyIntention.swift` — App Group UserDefaults Migration
  - `Sources/Intents/FocusBloxShortcuts.swift` — 2 neue Siri-Phrasen

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DailyIntention` | Model | Intention-Daten lesen/schreiben |
| `IntentionEvaluationService` | Service | `evaluateFulfillment()` + `fallbackTemplate()` |
| `SharedModelContainer` | Utility | SwiftData App Group Zugriff fuer Tasks |
| `EventKitRepository` | Service | FocusBlock-Fetch (mit Fallback) |
| `LocalTask` | Model | Erledigte Tasks fuer Evaluation |
| `FocusBlock` | Model | Focus Blocks fuer fokus-Evaluation |
| `FocusBloxShortcuts` | Provider | Siri-Phrasen-Registrierung |

## Implementation Details

### 1. DailyIntention App Group Migration

```swift
// DailyIntention.swift — save()/load() aendern:
// VON: UserDefaults.standard
// ZU:  UserDefaults(suiteName: "group.com.henning.focusblox")

private static let appGroupID = "group.com.henning.focusblox"

func save(key: String? = nil) {
    let storageKey = key ?? "dailyIntention_\(date)"
    guard let data = try? JSONEncoder().encode(self) else { return }
    let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
    defaults.set(data, forKey: storageKey)
}

static func load(key: String? = nil) -> DailyIntention {
    let storageKey = key ?? todayKey()
    let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    guard let data = defaults.data(forKey: storageKey),
          let intention = try? JSONDecoder().decode(DailyIntention.self, from: data) else {
        return DailyIntention(date: todayDateString(), selections: [])
    }
    return intention
}
```

Einmalige Migration: Beim ersten `load()` pruefen ob Daten in `.standard` existieren aber nicht in App Group → kopieren.

### 2. IntentionOptionEnum (AppEnum)

```swift
// IntentionOptionEnum.swift
import AppIntents

enum IntentionOptionEnum: String, AppEnum {
    case survival, fokus, bhag, balance, growth, connection

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intention")

    static let caseDisplayRepresentations: [IntentionOptionEnum: DisplayRepresentation] = [
        .survival:   "Tag ueberleben",
        .fokus:      "Fokus",
        .bhag:       "Das grosse Ding",
        .balance:    "Balance",
        .growth:     "Lernen",
        .connection: "Fuer andere"
    ]

    var asIntentionOption: IntentionOption {
        IntentionOption(rawValue: rawValue)!
    }
}
```

### 3. GetEveningSummaryIntent

```swift
// GetEveningSummaryIntent.swift
struct GetEveningSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Tagesrueckblick"
    static let description = IntentDescription("Liest die Abend-Auswertung deiner Intention vor.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intention = DailyIntention.load()
        guard intention.isSet else {
            return .result(dialog: "Du hast heute keine Intention gesetzt.")
        }

        // Tasks via SharedModelContainer (App Group SwiftData)
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let tasks = try context.fetch(FetchDescriptor<LocalTask>())

        // FocusBlocks via EventKit (Fallback: leeres Array)
        let blocks: [FocusBlock]
        do {
            blocks = try EventKitRepository().fetchFocusBlocks(for: Date())
        } catch {
            blocks = []
        }

        // Evaluation fuer jede gewaehlte Intention
        var summaryParts: [String] = []
        for option in intention.selections {
            let level = IntentionEvaluationService.evaluateFulfillment(
                intention: option, tasks: tasks, focusBlocks: blocks
            )
            let text = IntentionEvaluationService.fallbackTemplate(
                intention: option, level: level
            )
            summaryParts.append(text)
        }

        let summary = summaryParts.joined(separator: " ")
        return .result(dialog: "\(summary)")
    }
}
```

### 4. SetDailyIntentionIntent

```swift
// SetDailyIntentionIntent.swift
struct SetDailyIntentionIntent: AppIntent {
    static let title: LocalizedStringResource = "Intention setzen"
    static let description = IntentDescription("Setzt deine Tages-Intention.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Intention")
    var intention: IntentionOptionEnum

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let option = intention.asIntentionOption
        var daily = DailyIntention.load()
        daily.selections = [option]
        daily.save()

        return .result(dialog: "Intention auf \(option.label) gesetzt. Viel Erfolg heute!")
    }
}
```

### 5. FocusBloxShortcuts Erweiterung

```swift
// 2 neue AppShortcut-Eintraege in appShortcuts Array:

AppShortcut(
    intent: GetEveningSummaryIntent(),
    phrases: [
        "Wie war mein Tag in \(.applicationName)",
        "Tagesrueckblick in \(.applicationName)",
        "Abend-Auswertung in \(.applicationName)"
    ],
    shortTitle: "Tagesrueckblick",
    systemImageName: "moon.stars"
)

AppShortcut(
    intent: SetDailyIntentionIntent(),
    phrases: [
        "Setz meine Intention auf \(\.$intention) in \(.applicationName)",
        "Intention \(\.$intention) in \(.applicationName)"
    ],
    shortTitle: "Intention setzen",
    systemImageName: "sunrise"
)
```

## Expected Behavior

### Intent 1: GetEveningSummaryIntent
- **Input:** Keine Parameter
- **Output:** Siri spricht die Abend-Auswertung aller gewaehlten Intentionen
- **Fallback:** "Du hast heute keine Intention gesetzt." wenn keine Intention vorhanden
- **EventKit-Fallback:** Wenn Kalender-Zugriff fehlschlaegt, wird mit leerem FocusBlock-Array evaluiert (5/6 Intentionen funktionieren, nur "fokus" degradiert zu notFulfilled)

### Intent 2: SetDailyIntentionIntent
- **Input:** `IntentionOptionEnum` Parameter (Siri fragt: "Welche Intention?")
- **Output:** Bestaetigung: "Intention auf [Label] gesetzt. Viel Erfolg heute!"
- **Side effects:** Speichert DailyIntention in App Group UserDefaults

### UserDefaults Migration
- **Input:** Bestehende Daten in `UserDefaults.standard`
- **Output:** Daten in `UserDefaults(suiteName: "group.com.henning.focusblox")`
- **Side effects:** Einmalige Migration beim ersten Load, danach nur noch App Group

## Test Plan

### Unit Tests (6 Tests)

| Test | Beschreibung |
|------|-------------|
| `test_dailyIntention_savesAndLoadsFromAppGroup` | Save/Load ueber App Group UserDefaults |
| `test_dailyIntention_migrationFromStandard` | Einmalige Migration von .standard → App Group |
| `test_intentionOptionEnum_allCasesMapped` | Alle 6 Enum-Werte haben DisplayRepresentation |
| `test_intentionOptionEnum_convertsToIntentionOption` | `asIntentionOption` liefert korrektes Mapping |
| `test_getEveningSummary_noIntention_returnsNoIntentionDialog` | Keine Intention → Fallback-Text |
| `test_setDailyIntention_savesCorrectly` | Intent speichert korrekte Intention |

### UI Tests (2 Tests)

| Test | Beschreibung |
|------|-------------|
| `test_siriShortcuts_eveningSummaryRegistered` | Shortcut "Tagesrueckblick" ist in der App registriert |
| `test_siriShortcuts_setIntentionRegistered` | Shortcut "Intention setzen" ist in der App registriert |

## Known Limitations

- **Kein AI-Text im Intent:** Siri nutzt `fallbackTemplate()` statt Foundation Models (AI laeuft nur in-App)
- **EventKit-Fallback:** Bei fehlendem Kalender-Zugriff wird fokus-Intention immer als notFulfilled bewertet
- **Einzelne Intention per Siri:** SetDailyIntentionIntent setzt genau 1 Intention (UI erlaubt Mehrfachauswahl)
- **Keine Notification-Scheduling:** SetDailyIntentionIntent plant keine Nudge-Notifications (erst bei naechstem App-Vordergrund)

## Scope Assessment

- **Files:** 5 (3 CREATE + 2 MODIFY)
- **Estimated LoC:** +~180 / -~5
- **Risk:** MEDIUM (UserDefaults-Migration betrifft bestehende Coach-Funktionalitaet)

## Changelog

- 2026-03-13: Initial spec created
