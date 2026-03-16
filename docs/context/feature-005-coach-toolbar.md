# Context: FEATURE_005 — Coach-Backlog macOS: Toolbar (Sync + Import)

## Request Summary
Der normale macOS-Backlog zeigt Sync-Status-Indicator + Sync-Button + Apple-Reminders-Import-Button in der Toolbar. Der Coach-Backlog hat nur den ViewMode-Switcher + Task-Count. Fehlende Sync-Sichtbarkeit.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/ContentView.swift:533-582` | Toolbar-Implementierung im normalen Backlog: SyncStatus, SyncButton, RemindersImport — das VORBILD |
| `FocusBloxMac/ContentView.swift:40-72` | State/Environment: cloudKitMonitor, isSyncing, remindersSyncEnabled, eventKitRepo |
| `FocusBloxMac/ContentView.swift:725-756` | `importFromReminders()` Funktion — Reminders-Import-Logik |
| `FocusBloxMac/MacCoachBacklogView.swift:73-88` | Aktuelle Coach-Toolbar: nur ViewMode-Switcher + Task-Count |
| `FocusBloxMac/MacCoachBacklogView.swift:301-320` | ViewMode-Switcher Implementierung |
| `Sources/Services/CloudKitSyncMonitor.swift` | Observable CloudKit-State: isSyncing, hasSyncError, lastSuccessfulSync, triggerSync() |
| `Sources/Services/RemindersImportService.swift` | Import-Service: importAll() async, ImportResult |
| `Sources/Models/SyncedSettings.swift` | AppStorage-Keys: remindersSyncEnabled, remindersMarkCompleteOnImport |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | Bestehende macOS Coach-Backlog UI Tests |

## Existing Patterns

### Toolbar-Pattern im normalen Backlog (ContentView.swift:533-582)
```
.toolbar {
    ToolbarItem { SyncStatus (ProgressView/Fehler/OK) }
    ToolbarItem { Sync-Button (arrow.triangle.2.circlepath) }
    if remindersSyncEnabled { ToolbarItem { Import-Button } }
    ToolbarItem { TaskCount }
}
```

### Problem: MacCoachBacklogView ist kein NavigationStack
- Coach-Backlog wird als `VStack` gerendert, NICHT als NavigationView/Stack
- Die `.toolbar {}` API funktioniert nur innerhalb einer Navigation-Hierarchie
- Coach-Backlog baut seine "Toolbar" manuell als `HStack` (Zeile 76-84)
- **Loesung:** Sync-Elemente in denselben HStack integrieren

### Zugriff auf Dependencies
- `CloudKitSyncMonitor` ist im Environment (`@Environment(CloudKitSyncMonitor.self)`)
- `EventKitRepository` ist im Environment (`@Environment(\.eventKitRepository)`)
- `remindersSyncEnabled` ist AppStorage — direkt lesbar
- `importFromReminders()` liegt aktuell in ContentView — muss entweder:
  1. In MacCoachBacklogView dupliziert werden (einfach, ~30 LoC)
  2. Oder als Shared-Funktion extrahiert werden (sauberer)

## Dependencies
- **Upstream:** CloudKitSyncMonitor (Observable), EventKitRepository, RemindersImportService
- **Downstream:** MacCoachBacklogView wird von ContentView eingebettet (Zeile 271)

## Existing Specs
- Keine existierende Spec fuer FEATURE_005

## Accessibility Identifiers (Vorbild)
- `"syncStatusIndicator"` — Sync-Status-Icon
- `"syncButton"` — Manueller Sync-Trigger
- `"importRemindersButton"` — Reminders-Import-Button
- `"coachViewModeSwitcher"` — ViewMode-Dropdown (bestehend)

## Risks & Considerations
1. **Kein NavigationStack:** Coach-Backlog nutzt VStack, nicht `.toolbar {}` — Sync-Elemente muessen als HStack-Items integriert werden
2. **importFromReminders() Duplikation:** Funktion existiert nur in ContentView — Loesung: per Closure durchreichen (keine Duplikation, kein Refactoring)
3. **isSyncing State:** ContentView hat eigenen `@State private var isSyncing` — per Binding an MacCoachBacklogView
4. **Environment-Zugriff:** CloudKitSyncMonitor + EventKitRepository sind im Environment vorhanden — MacCoachBacklogView kann direkt darauf zugreifen
5. **Scope:** 2 Dateien, ~30-40 LoC — weit innerhalb der Limits

---

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY | HStack um SyncStatus + SyncButton + ImportButton erweitern; @Environment(CloudKitSyncMonitor.self) + @AppStorage hinzufuegen; onImport-Closure-Parameter |
| `FocusBloxMac/ContentView.swift` | MODIFY | MacCoachBacklogView-Aufruf (Zeile 271) um onImport-Closure erweitern |
| `FocusBloxMacUITests/MacCoachBacklogUITests.swift` | MODIFY | UI Tests fuer neue Toolbar-Elemente (TDD RED) |

### Scope Assessment
- Files: 3 (2 Production + 1 Test)
- Estimated LoC: +50-70 (Production ~35, Tests ~30)
- Risk Level: LOW

### Technical Approach (Empfehlung)
1. **HStack erweitern** (NICHT .toolbar{}) — MacCoachBacklogView ist eingebettete Subview, kein eigener NavigationStack. `.toolbar{}` wuerde auf ContentView's Navigation wirken und Konflikte erzeugen.
2. **CloudKitSyncMonitor via @Environment** lesen — bereits global registriert in FocusBloxMacApp
3. **importFromReminders() per Closure** von ContentView durchreichen — keine Duplikation, kein Refactoring ausserhalb Ticket-Scope
4. **remindersSyncEnabled via @AppStorage** direkt in MacCoachBacklogView lesen
5. **Sync-Elemente identisch** zum normalen Backlog (gleiche Icons, gleiche AccessibilityIdentifiers)

### Dependencies
- **Upstream:** CloudKitSyncMonitor (@Observable, global), EventKitRepository (Environment), RemindersImportService
- **Downstream:** ContentView embedding (Zeile 271)

### Existing Related Specs
- `docs/specs/features/coach-views-backlog.md` — Coach-Backlog Spec (Draft)
- `docs/specs/features/reminders-sync.md` — Reminders-Sync Spec (Approved)
- `docs/specs/macos/MAC-024-sync-ui-alignment.md` — macOS Sync UI Alignment

### Open Questions
- Keine — alle Architektur-Entscheidungen sind klar
