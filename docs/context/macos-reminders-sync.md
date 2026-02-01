# Context: macOS Reminders Sync

## Request Summary
Die macOS App soll mit Apple Reminders synchronisieren, genau wie die iOS App. Dadurch werden Tasks automatisch zwischen iOS und macOS geteilt.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Services/RemindersSyncService.swift` | Bidirektionaler Sync mit Apple Reminders |
| `Sources/Services/EventKitRepository.swift` | EventKit API Wrapper (Reminders + Kalender) |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | Protocol für EventKitRepository |
| `Sources/Models/ReminderData.swift` | DTO für Reminder-Daten |
| `Sources/Models/ReminderListInfo.swift` | DTO für Reminder-Listen |
| `FocusBloxMac/FocusBloxMacApp.swift` | macOS App Entry Point - hier Sync integrieren |
| `FocusBloxMac/FocusBloxMac.entitlements` | Entitlements - Reminders-Zugriff bereits hinzugefügt |

## Existing Patterns

### iOS Sync-Architektur
```
FocusBloxApp
  └── EventKitRepository (EventKit API)
  └── RemindersSyncService (Bidirektional: Reminders ↔ LocalTask)
  └── ModelContext (SwiftData)
```

### Sync-Flow
1. `RemindersSyncService.importFromReminders()` - Holt Reminders → erstellt LocalTask
2. `RemindersSyncService.exportToReminders()` - Schreibt LocalTask → Reminders
3. `RemindersSyncService.syncAll()` - Bidirektionaler Full-Sync

### Schlüssel-Logik
- `sourceSystem: "reminders"` - Task kommt aus Apple Reminders
- `sourceSystem: "local"` - Lokaler Task
- `externalID` - Apple Reminder ID für Mapping

## Scope für macOS

### Muss gemacht werden:
1. **Entitlements** ✅ bereits erledigt (`com.apple.security.personal-information.reminders`)
2. **Shared Files** - EventKitRepository, RemindersSyncService zum macOS Target hinzufügen
3. **Init in App** - RemindersSyncService in FocusBloxMacApp initialisieren
4. **Sync Trigger** - Sync bei App-Start und periodisch

### Nicht nötig:
- Neue Services schreiben (existieren bereits)
- Neue Models (LocalTask, ReminderData existieren)

## Dependencies
- EventKit Framework (verfügbar auf macOS)
- SwiftData (bereits genutzt)

## Risks & Considerations
- EventKit API ist identisch auf iOS/macOS
- Sandbox erfordert User-Permission für Reminders
- Erster Sync kann langsam sein bei vielen Reminders
