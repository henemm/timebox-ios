---
entity_id: cloudkit-sync-race-condition
type: bugfix
created: 2026-02-14
updated: 2026-02-14
status: draft
version: "1.0"
tags: [cloudkit, sync, race-condition, swiftdata]
---

# CloudKit Sync Race Condition Fix

## Approval

- [ ] Approved

## Purpose

iOS BacklogView aktualisiert sich nicht automatisch nach CloudKit-Import von macOS-Aenderungen. Pull-to-Refresh funktioniert, automatischer Refresh nicht. Ursache: SwiftData ModelContext liefert gecachte Daten nach CloudKit-Import, weil `modelContext.save()` (das den Cache invalidiert) im automatischen Refresh-Pfad fehlt.

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `refreshLocalTasks()` (Zeile 348-359), `.onChange(of: cloudKitMonitor.remoteChangeCount)` (Zeile 298-301)

## Root Cause

1. `NSPersistentCloudKitContainer.eventChangedNotification` feuert BEVOR Daten im ModelContext verfuegbar sind
2. `NSPersistentStoreRemoteChange` feuert korrekt, aber `modelContext.fetch()` liefert gecachte Daten
3. Pull-to-Refresh funktioniert weil `loadTasks()` -> `triggerSync()` -> `modelContext.save()` aufruft
4. `save()` erzwingt einen Merge von pending Remote-Changes im Context-Cache
5. `refreshLocalTasks()` fehlt dieser `save()`-Aufruf

### Architektur-Asymmetrie
- macOS nutzt `@Query` (auto-updates bei Store-Aenderungen)
- iOS nutzt manuelles Fetching via `SyncEngine.sync()` (kein Auto-Update)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CloudKitSyncMonitor | Service | Liefert `remoteChangeCount` - bereits korrekt implementiert |
| SyncEngine | Service | Fuehrt Fetch aus - keine Aenderung noetig |
| ModelContext | SwiftData | Context-Cache muss vor Fetch invalidiert werden |

## Implementation Details

### Aenderung 1: Context-Cache invalidieren in `refreshLocalTasks()`

```swift
private func refreshLocalTasks() async {
    print("[CloudKit Debug] refreshLocalTasks() START - current planItems: \(planItems.count)")
    do {
        // Force context merge with persistent store (same mechanism as Pull-to-Refresh)
        try modelContext.save()

        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        planItems = try await syncEngine.sync()
        print("[CloudKit Debug] refreshLocalTasks() DONE - new planItems: \(planItems.count)")
    } catch {
        print("[CloudKit Debug] refreshLocalTasks() ERROR: \(error)")
        errorMessage = error.localizedDescription
    }
}
```

### Aenderung 2: Timing-Sicherheit im onChange Handler

```swift
.onChange(of: cloudKitMonitor.remoteChangeCount) { oldVal, newVal in
    print("[CloudKit Debug] remoteChange onChange FIRED: \(oldVal) -> \(newVal)")
    Task {
        try? await Task.sleep(for: .milliseconds(200))
        await refreshLocalTasks()
    }
}
```

## Expected Behavior

- **Vorher:** iOS zeigt nach CloudKit-Import alte Daten. Nur Pull-to-Refresh aktualisiert.
- **Nachher:** iOS aktualisiert automatisch ~0.2s nach CloudKit-Import.
- **Side effects:** Keine. `save()` ohne pending Changes ist ein No-Op mit Cache-Refresh.

## Scope

- **Files:** 1 (`Sources/Views/BacklogView.swift`)
- **LoC:** +3/-1
- **Risk:** LOW (idempotente Operation, identischer Mechanismus wie Pull-to-Refresh)

## Test Plan

### Unit Test (CloudKitSyncMonitorTests - existiert bereits)
- 6 bestehende Tests pruefen Monitor-Funktionalitaet - muessen weiterhin gruen sein

### Manueller Verifikations-Indikator
Da der Bug eine Cross-Device Race Condition betrifft, die nur mit echtem CloudKit reproduzierbar ist, koennen automatisierte Tests nur die Code-Aenderung verifizieren (Build, bestehende Tests gruen). Die eigentliche Verifikation erfolgt durch CloudKit-Debug-Logs auf dem Device.

## Known Limitations

- Automatisierte Tests koennen die echte CloudKit-Sync Race Condition nicht reproduzieren (benoetig 2 Geraete + iCloud)
- Die 200ms Verzoegerung ist ein konservativer Puffer - koennte auch 0 sein wenn `save()` allein reicht
- Langfristig waere ein Refactor auf `@Query` (wie macOS) die sauberere Loesung

## Changelog

- 2026-02-14: Initial spec created
