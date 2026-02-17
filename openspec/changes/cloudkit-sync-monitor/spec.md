# Feature: CloudKit Sync Monitor

## Problem

CloudKit Sync zwischen iOS und macOS funktioniert still im Hintergrund via SwiftData, aber:
1. Die App erkennt nicht wenn Remote-Aenderungen ankommen
2. Der Sync-Button auf macOS synct nur Apple Erinnerungen, nicht CloudKit
3. Pull-to-Refresh auf iOS laedt nur lokale Daten
4. Es gibt kein Feedback ob Sync funktioniert, laeuft oder fehlschlaegt
5. Ohne Monitoring ist es unmoeglich zu debuggen warum Sync nicht klappt

## Loesung

`CloudKitSyncMonitor` - ein `@Observable` Service der `NSPersistentCloudKitContainer.eventChangedNotification` beobachtet und Sync-Status bereitstellt.

## Technischer Ansatz

### API: NSPersistentCloudKitContainer.eventChangedNotification

SwiftData nutzt intern `NSPersistentCloudKitContainer`. Diese Notification feuert bei jedem Sync-Event:
- **Setup**: CloudKit Schema-Initialisierung
- **Import**: Daten von CloudKit empfangen
- **Export**: Lokale Aenderungen zu CloudKit senden

Jedes Event hat: `startDate`, `endDate` (nil = laeuft), `succeeded`, `error`

### Kein manueller Sync-Trigger moeglich

Es gibt KEINE public API fuer "sync now". SwiftData synct automatisch bei:
- App-Start
- Scene-Phase-Wechsel (active/background)
- `modelContext.save()` (triggert Export)
- CloudKit Push Notifications (triggert Import)

## Aenderungen

### Neue Datei: Sources/Services/CloudKitSyncMonitor.swift

```
@Observable @MainActor
final class CloudKitSyncMonitor {
    // State
    var setupState: SyncState = .notStarted
    var importState: SyncState = .notStarted
    var exportState: SyncState = .notStarted

    // Computed
    var isSyncing: Bool
    var hasSyncError: Bool
    var lastSuccessfulSync: Date?
    var errorMessage: String?

    // Debug logging
    func logEvent(event) // Prints [CloudKit Sync] to console
}
```

SyncState Enum: `.notStarted`, `.inProgress(Date)`, `.succeeded(Date, Date)`, `.failed(Date, Date, String)`

### Geaenderte Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/FocusBloxApp.swift` | CloudKitSyncMonitor instanziieren, via .environment() weitergeben |
| `FocusBloxMac/FocusBloxMacApp.swift` | CloudKitSyncMonitor instanziieren, via .environment() weitergeben |
| `FocusBloxMac/ContentView.swift` | Bestehenden Sync-Status-Indikator mit echtem CloudKit-Status ersetzen |

### iOS UI

Kein separater Indikator noetig - BacklogView hat bereits `.refreshable`. Der Monitor wird nur fuer Debug-Logging genutzt. Falls gewuenscht kann spaeter ein Indikator hinzugefuegt werden.

### macOS UI (ContentView.swift Toolbar)

Ersetze den bisherigen Indikator (der nur Reminders-Status zeigt):
- `ProgressView()` wenn `syncMonitor.isSyncing`
- `checkmark.icloud` (gruen) wenn erfolgreich
- `exclamationmark.icloud` (rot) wenn Fehler
- Tooltip mit letzter Sync-Zeit und Fehlermeldung

## Scoping

- **1 neue Datei** (CloudKitSyncMonitor.swift ~80 LoC)
- **3 geaenderte Dateien** (FocusBloxApp, FocusBloxMacApp, ContentView)
- **~120 LoC** total (innerhalb Limit)
- Keine neuen Dependencies
- Keine neuen Permissions

## Nicht im Scope

- Manueller "Sync Now" Button (keine API dafuer)
- Conflict Resolution UI
- Sync-Fortschrittsanzeige (nur an/aus)
- Hintergrund-Sync-Konfiguration
