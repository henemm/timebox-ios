---
entity_id: feature-005-coach-toolbar
type: feature
created: 2026-03-16
updated: 2026-03-16
status: implemented
version: "1.0"
tags: ["macOS", "coach", "sync", "toolbar"]
---

# Coach-Backlog macOS: Toolbar (Sync + Import)

## Approval

- [x] Approved

## Purpose

Der Coach-Backlog auf macOS zeigt derzeit keine Sync-Status-Anzeige und keinen Import-Button — im Gegensatz zum normalen Backlog. Dieses Feature bringt Sync-Sichtbarkeit und Reminders-Import-Zugang in die Coach-Backlog-Toolbar, indem die bestehenden Toolbar-Elemente um SyncStatus-Indicator, Sync-Button und Import-Button erweitert werden.

## Source

- **File:** `FocusBloxMac/MacCoachBacklogView.swift`
- **Identifier:** `struct MacCoachBacklogView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CloudKitSyncMonitor | service (@Observable) | Liefert Sync-Status fuer den SyncStatus-Indicator; wird via @Environment gelesen (bereits global registriert) |
| EventKitRepository | service (Environment) | Benoetigt fuer den Reminders-Import-Pfad |
| RemindersImportService | service | Fuehrt den tatsaechlichen Apple-Reminders-Import durch |
| ContentView | view (macOS) | Bettet MacCoachBacklogView ein (Zeile 271); reicht importFromReminders()-Closure durch |
| MacCoachBacklogUITests | test | UI Tests fuer die neuen Toolbar-Elemente |

## Implementation Details

### Betroffene Dateien

1. **`FocusBloxMac/MacCoachBacklogView.swift`** (MODIFY)
   - `@Environment(CloudKitSyncMonitor.self)` hinzufuegen
   - `@AppStorage("remindersSyncEnabled") var remindersSyncEnabled: Bool` hinzufuegen
   - `var onImport: (() -> Void)?` als Parameter (Closure von ContentView)
   - Den bestehenden HStack (ViewMode-Switcher + Task-Count) um drei Elemente erweitern:
     - SyncStatus-Indicator Icon (accessibilityIdentifier: `"coachSyncStatusIndicator"`)
     - Sync-Button (accessibilityIdentifier: `"coachSyncButton"`)
     - Import-Button — nur sichtbar wenn `remindersSyncEnabled == true` (accessibilityIdentifier: `"coachImportRemindersButton"`)
   - Wichtig: KEIN `.toolbar{}` verwenden — MacCoachBacklogView ist eine eingebettete Subview ohne eigenen NavigationStack. Erweiterung erfolgt direkt im vorhandenen HStack.

2. **`FocusBloxMac/ContentView.swift`** (MODIFY)
   - MacCoachBacklogView-Aufruf (Zeile 271) um `onImport:` Closure erweitern
   - Closure ruft die bestehende `importFromReminders()`-Funktion auf

3. **`FocusBloxMacUITests/MacCoachBacklogUITests.swift`** (MODIFY)
   - UI Tests fuer alle drei neuen Toolbar-Elemente (siehe Test-Plan)

### Visuelle Konsistenz

Die neuen Elemente muessen optisch identisch zum normalen Backlog sein — gleiche SF Symbols, gleiche Anordnung. Nur die AccessibilityIdentifiers erhalten einen `"coach"`-Prefix.

### AccessibilityIdentifiers

| Element | Identifier | Sichtbarkeit |
|---------|-----------|--------------|
| SyncStatus-Icon | `"coachSyncStatusIndicator"` | immer |
| Sync-Button | `"coachSyncButton"` | immer |
| Import-Button | `"coachImportRemindersButton"` | nur wenn remindersSyncEnabled == true |
| ViewMode-Switcher | `"coachViewModeSwitcher"` | immer (bestehend) |

## Expected Behavior

- **Input:** User oeffnet den Coach-Backlog auf macOS
- **Output:** Toolbar zeigt SyncStatus-Indicator, Sync-Button und (bei aktiviertem Reminders-Sync) Import-Button — visuell identisch zum normalen Backlog
- **Side effects:** Kein neuer globaler Zustand; CloudKitSyncMonitor wird nur gelesen, nicht veraendert; Import loest die bestehende importFromReminders()-Funktion aus

## Test Plan

| # | Beschreibung | Erwartetes Ergebnis |
|---|-------------|---------------------|
| 1 | SyncStatus-Indicator im Coach-Backlog | Element mit ID `"coachSyncStatusIndicator"` existiert und ist sichtbar |
| 2 | Sync-Button im Coach-Backlog | Element mit ID `"coachSyncButton"` existiert und ist klickbar |
| 3 | Import-Button nur bei aktiviertem Reminders-Sync | Element mit ID `"coachImportRemindersButton"` erscheint nur wenn remindersSyncEnabled == true |

## Known Limitations

- MacCoachBacklogView hat keinen eigenen NavigationStack — `.toolbar{}` kann daher nicht verwendet werden. Alle Elemente muessen in den manuell aufgebauten HStack integriert werden.
- Import-Button ist bedingt sichtbar (remindersSyncEnabled) — Test 3 muss AppStorage-Zustand explizit setzen.

## Changelog

- 2026-03-16: Initial spec created
- 2026-03-16: Implementation complete — SyncStatus indicator, Sync button, and Import button added to MacCoachBacklogView toolbar. UI tests (8-10) passing.
