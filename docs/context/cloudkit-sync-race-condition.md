# Context: CloudKit Sync Race Condition Fix

## Request Summary
iOS BacklogView aktualisiert sich nicht automatisch, wenn CloudKit-Daten von macOS importiert werden. Pull-to-Refresh funktioniert, automatischer Refresh nicht. Ursache: SwiftData ModelContext liefert gecachte Daten nach CloudKit-Import.

## Root Cause (durch Debug-Logs bewiesen)
1. `eventChangedNotification` feuert BEVOR Daten im ModelContext verfuegbar sind
2. `modelContext.fetch()` liefert gecachte/veraltete Daten
3. Pull-to-Refresh funktioniert, weil `loadTasks()` -> `triggerSync()` -> `modelContext.save()` aufruft
4. `save()` erzwingt einen Merge von pending Remote-Changes im Context

## Architektur-Asymmetrie: Warum macOS funktioniert
- **macOS** (`FocusBloxMac/ContentView.swift:36`): Nutzt `@Query` -> SwiftUI observiert Store automatisch
- **iOS** (`Sources/Views/BacklogView.swift`): Nutzt manuelles Fetching via `SyncEngine.sync()` -> kein Auto-Update

## Aktueller Stand
- `CloudKitSyncMonitor` lauscht BEREITS auf `.NSPersistentStoreRemoteChange` (Zeile 102-110)
- `BacklogView` reagiert BEREITS auf `cloudKitMonitor.remoteChangeCount` (Zeile 298-301)
- **FEHLEND**: `modelContext.save()` vor dem Fetch in `refreshLocalTasks()` (der "Magic Fix")

## Loesung (2 Teile)
### Teil 1: Context-Cache invalidieren (Hypothese E)
In `BacklogView.refreshLocalTasks()`: `try? modelContext.save()` VOR dem Fetch hinzufuegen.
Das erzwingt den Context-Merge mit dem Persistent Store (gleicher Mechanismus wie Pull-to-Refresh).

### Teil 2: Timing-Sicherheit (Hypothese A)
Optional: Kleine Verzoegerung (0.2s) im `.onChange` Handler, damit der Store-Merge abgeschlossen ist.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift` | iOS Hauptansicht mit manuellem Fetch - AENDERN |
| `Sources/Services/CloudKitSyncMonitor.swift` | Sync Monitor - bereits korrekt konfiguriert |
| `Sources/FocusBloxApp.swift` | iOS App Entry, startet Monitor - nur Referenz |
| `Sources/Services/SyncEngine.swift` | Fetch-Logik - keine Aenderung noetig |
| `docs/context/bug-38-handoff.md` | Ausfuehrliche Debug-Dokumentation aller Versuche |

## Existing Patterns
- `triggerSync()` (CloudKitSyncMonitor:251-262) macht `container.mainContext.save()` -> das ist der bewiesene Mechanismus
- `loadTasks()` (BacklogView:307-344) ruft `triggerSync()` auf -> darum funktioniert Pull-to-Refresh

## Dependencies
- Upstream: `CloudKitSyncMonitor` (remoteChangeCount), `SyncEngine`, `LocalTaskSource`
- Downstream: Alle Views die Tasks anzeigen (aber nur BacklogView ist betroffen, da nur sie manuell fetched)

## Risks & Considerations
- `modelContext.save()` ist idempotent - wenn keine lokalen Aenderungen da sind, ist es ein No-Op mit Cache-Refresh
- Die 0.2s Verzoegerung ist konservativ - koennte auch 0 sein wenn `save()` allein reicht
- macOS ist NICHT betroffen (nutzt @Query)
- Scope: Max 1 Datei, ~5 LoC Aenderung
