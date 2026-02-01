# MAC-025: macOS Reminders Sync

## Übersicht

Die macOS App soll mit Apple Reminders synchronisieren, identisch zur iOS App. Dadurch werden Tasks automatisch zwischen iOS und macOS über Apple Reminders geteilt.

## Problem

- macOS App nutzt `RemindersSyncService` nicht
- Tasks existieren nur lokal in der macOS App
- Kein Sync mit iOS (CloudKit funktioniert nicht zuverlässig)

## Lösung

Reminders-Sync in macOS ContentView integrieren, analog zu iOS BacklogView.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `FocusBloxMac/ContentView.swift` | Sync bei Task-Load integrieren |
| `FocusBloxMac/FocusBloxMac.entitlements` | ✅ Bereits erledigt |

## Implementation

### 1. ContentView: Sync bei loadTasks()

```swift
// In ContentView, neue Property:
@Environment(\.eventKitRepository) private var eventKitRepo

// In loadTasks() oder equivalent:
private func syncAndLoadTasks() async {
    let syncEnabled = UserDefaults.standard.bool(forKey: "remindersSyncEnabled")

    if syncEnabled {
        let syncService = RemindersSyncService(
            eventKitRepo: eventKitRepo,
            modelContext: modelContext
        )
        _ = try? await syncService.importFromReminders()
    }
}
```

### 2. Sync bei App-Start triggern

In `FocusBloxMacApp.swift` oder `ContentView.onAppear`:

```swift
.task {
    await syncAndLoadTasks()
}
```

### 3. Environment Setup

EventKitRepository muss im Environment verfügbar sein:

```swift
// In FocusBloxMacApp.body:
ContentView()
    .environment(\.eventKitRepository, EventKitRepository())
```

## Akzeptanzkriterien

1. [ ] macOS App importiert Reminders bei Start
2. [ ] Tasks aus Reminders erscheinen in der Task-Liste
3. [ ] Änderungen an Tasks werden zurück zu Reminders exportiert
4. [ ] Setting `remindersSyncEnabled` wird respektiert

## Test-Plan

### UI Test: Reminders Import
```swift
func testRemindersImportOnLaunch() {
    // App starten
    // Prüfen ob Tasks aus Reminders angezeigt werden
}
```

### Unit Test: Sync Service
```swift
func testSyncServiceImportsReminders() {
    // Mock EventKitRepository
    // Sync ausführen
    // Prüfen ob LocalTasks erstellt werden
}
```

## Scope

- **Dateien:** 1-2
- **LoC:** ~30-50
- **Aufwand:** Klein (Services existieren bereits)
