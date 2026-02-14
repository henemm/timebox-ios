# Bug 38: CloudKit Cross-Platform Sync - Handoff-Dokument

## Das Problem

Erweiterte Task-Attribute (Wichtigkeit, Dringlichkeit, Dauer, Kategorie etc.) synchronisieren nicht zuverlässig zwischen iOS und macOS über CloudKit/SwiftData. Änderungen auf einer Plattform erscheinen nicht auf der anderen.

## Architektur

- **Shared Code**: `Sources/` (Models, Services) - wird von beiden Plattformen genutzt
- **macOS-spezifisch**: `FocusBloxMac/`
- **Datenmodell**: `Sources/Models/LocalTask.swift` - SwiftData `@Model` mit optionalen Feldern (importance: Int?, urgency: String?, estimatedDuration: Int?, etc.)
- **CloudKit-Container**: `iCloud.com.henning.focusblox` (Private Database)
- **Schema**: `Schema([LocalTask.self, TaskMetadata.self])` - identisch auf beiden Plattformen
- **App Group**: `group.com.henning.focusblox`

### ModelContainer-Konfiguration (identisch auf beiden Plattformen)

```swift
ModelConfiguration(
    schema: schema,
    groupContainer: .identifier("group.com.henning.focusblox"),
    cloudKitDatabase: .private("iCloud.com.henning.focusblox")
)
```

### iOS App Entry: `Sources/FocusBloxApp.swift`
### macOS App Entry: `FocusBloxMac/FocusBloxMacApp.swift`

## Was funktioniert

1. **CloudKit Sync Events feuern** auf beiden Plattformen (Import OK, Export OK)
2. **iOS → macOS**: Änderungen auf iOS erscheinen auf macOS (meistens)
3. **Debug-Logging** zeigt dass die Daten irgendwann identisch sind auf beiden Plattformen
4. **Pull-to-Refresh auf iOS** zeigt Änderungen von macOS korrekt an
5. **Builds kompilieren** fehlerfrei auf beiden Plattformen
6. **Unit Tests** (6 Tests in CloudKitSyncMonitorTests) bestehen

## Was NICHT funktioniert

1. **macOS → iOS automatisch**: Änderungen auf macOS erscheinen NICHT automatisch auf iOS
2. **iOS UI refreshed nicht** wenn CloudKit-Daten importiert werden
3. Nur Pull-to-Refresh auf iOS zeigt die Änderungen

## Kernproblem (durch systematisches Debugging ermittelt)

### Bewiesene Fakten aus Console-Logs:

**macOS-Seite** (funktioniert korrekt):
```
[CloudKit Sync] Export OK
[CloudKit Sync] Export - 1 change(s):
[CloudKit Sync] CHANGED "Kompost umsetzen": urg=not_urgent -> urg=urgent
```

**iOS-Seite** (das Problem):
```
[CloudKit Sync] Import OK                              ← Import-Event feuert
[CloudKit Debug] importSuccessCount incremented to 1    ← Counter steigt
[CloudKit Sync] Import OK - no changes detected         ← ABER: Daten sind NICHT da!
[CloudKit Debug] onChange FIRED: importSuccessCount 0 -> 1  ← SwiftUI reagiert
[CloudKit Debug] refreshLocalTasks() START - current planItems: 35
[CloudKit Debug] refreshLocalTasks() DONE - new planItems: 35  ← Fetch liefert ALTE Daten

... (2 Sekunden Delay getestet) ...

[CloudKit Sync] Import (delayed) OK - no changes detected  ← AUCH nach 2s nicht da!

... (später, nach Export-Zyklus) ...

[CloudKit Sync] Export - 1 change(s):
[CloudKit Sync] CHANGED "Kompost umsetzen": urg=not_urgent -> urg=urgent  ← JETZT ist es da!
```

### Interpretation:
1. `NSPersistentCloudKitContainer.eventChangedNotification` (Import OK) feuert BEVOR die Daten im ModelContext verfügbar sind
2. Selbst 2 Sekunden nach dem Import-Event sind die Daten noch nicht im Context
3. Die Daten kommen irgendwann später an (erkennbar am Export-Check)
4. `modelContext.fetch()` liefert gecachte/veraltete Daten
5. Pull-to-Refresh funktioniert weil `loadTasks()` → `triggerSync()` → `modelContext.save()` aufruft, was möglicherweise den Context-Cache invalidiert

### Die zentrale Frage (UNGELÖST):
**Wie erkennt man auf iOS zuverlässig, wann CloudKit-importierte Daten tatsächlich im SwiftData ModelContext verfügbar sind, und wie erzwingt man einen frischen Fetch?**

## Alle durchgeführten Änderungen (aktueller Code-Stand)

### 1. CloudKit Container explizit gesetzt (5 Stellen)
- `.automatic` → `.private("iCloud.com.henning.focusblox")` in:
  - `Sources/FocusBloxApp.swift` (2x: mit/ohne App Group)
  - `FocusBloxMac/FocusBloxMacApp.swift` (2x: mit/ohne App Group)
  - `Sources/Intents/TaskEntity.swift` (1x)
- **Ergebnis**: Kein Effekt auf das Sync-Problem

### 2. CloudKit.framework zum macOS Target gelinkt
- In `FocusBlox.xcodeproj/project.pbxproj`
- **Ergebnis**: Kein Effekt (war möglicherweise schon implizit gelinkt)

### 3. CloudKitSyncMonitor erstellt (`Sources/Services/CloudKitSyncMonitor.swift`)
- `@Observable @MainActor` Klasse
- Lauscht auf `NSPersistentCloudKitContainer.eventChangedNotification`
- Lauscht auf `NSPersistentStoreRemoteChange` (zuletzt hinzugefügt, noch nicht getestet)
- Trackt `setupState`, `importState`, `exportState` als `SyncState` enum
- `importSuccessCount: Int` - Counter für erfolgreiche Imports
- `remoteChangeCount: Int` - Counter für NSPersistentStoreRemoteChange (NEU, ungetestet)
- `triggerSync()` - ruft `container.mainContext.save()` auf
- `checkForChanges()` - Diff-basiertes Logging (vergleicht Snapshots)
- **Ergebnis**: Monitoring funktioniert, aber eventChangedNotification ist zu früh für Daten-Refresh

### 4. iOS BacklogView: Auto-Refresh nach Import
- `.onChange(of: cloudKitMonitor.remoteChangeCount)` → `refreshLocalTasks()`
- Vorher: `.onChange(of: cloudKitMonitor.importSuccessCount)` (funktionierte nicht)
- **Ergebnis**: onChange feuert korrekt, aber `refreshLocalTasks()` liest veraltete Daten aus dem ModelContext

### 5. iOS App: Sync bei Foreground
- `scenePhase == .active` → `syncMonitor.triggerSync()`
- In `Sources/FocusBloxApp.swift` Zeile ~247
- **Ergebnis**: triggerSync wird aufgerufen, Import-Events feuern, aber Daten kommen nicht an

### 6. macOS TaskInspector: Fehlende save() Aufrufe
- `categoryChip()` hatte kein `modelContext.save()` → hinzugefügt
- `statusChip()` (Erledigt/Next Up) hatten kein `modelContext.save()` → hinzugefügt
- Datei: `FocusBloxMac/TaskInspector.swift` Zeilen 290, 170-175
- **Ergebnis**: Korrekt, diese Saves fehlten tatsächlich. Aber das Hauptproblem ist iOS-seitig.

### 7. V2 Migration (nur non-nil Felder touchen)
- V1 Migration touchte ALLE Felder inkl. nil → gab nil-Werten frische Timestamps
- V2 toucht nur non-nil Felder → echte Werte bekommen neuere Timestamps
- In `Sources/FocusBloxApp.swift` und `FocusBloxMac/FocusBloxMacApp.swift`
- Key: `cloudKitFieldSyncV2` (V1 war `cloudKitFieldSyncV1`)
- **Ergebnis**: Ungetestet ob es Konflikt-Resolution verbessert

### 8. Debug-Logging (verschiedene Iterationen)
- Iteration 1: Full dump aller Tasks mit Attributen → Unübersichtlich
- Iteration 2: Nur Tasks mit non-nil extended attributes → Besser
- Iteration 3: Diff-basiert (Snapshot-Vergleich) → Zeigt spezifische Änderungen
- Iteration 4: Debug-Prints in onChange, refreshLocalTasks, importSuccessCount → Bewies das Timing-Problem

## Fehlgeschlagene Hypothesen

| # | Hypothese | Test | Ergebnis |
|---|-----------|------|----------|
| 1 | `.automatic` statt expliziter Container-ID | Auf `.private(...)` umgestellt | Kein Effekt |
| 2 | CloudKit.framework fehlt auf macOS | Framework gelinkt | Kein Effekt |
| 3 | Fehlende save() in macOS TaskInspector | save() hinzugefügt | Behebt lokales Problem, nicht den Sync |
| 4 | iOS refreshed nicht nach Import | onChange + refreshLocalTasks | onChange feuert, aber Daten nicht im Context |
| 5 | Timing-Problem (Daten kommen verzögert) | 2-Sekunden Delay vor Fetch | Auch nach 2s keine Daten |
| 6 | V1 Migration verursacht Konflikte | V2 Migration nur non-nil | Ungetestet |
| 7 | eventChangedNotification zu früh | NSPersistentStoreRemoteChange hinzugefügt | Ungetestet |

## Offene Lösungsansätze (nicht implementiert/getestet)

### A. NSPersistentStoreRemoteChange statt eventChangedNotification
- Code ist implementiert aber noch nicht getestet
- `remoteChangeCount` in CloudKitSyncMonitor, `onChange` in BacklogView
- Theorie: Feuert NACH dem Store-Update, nicht nur nach dem CloudKit-Event
- **ABER**: Unklar ob ModelContext dann schon frische Daten hat

### B. ModelContext Cache invalidieren
- `modelContext` könnte gecachte Objekte zurückgeben
- In Core Data: `context.refreshAllObjects()` oder `context.stalenessInterval = 0`
- In SwiftData: Unklar wie man das macht
- Möglich: Neuen `ModelContext(container)` erstellen für jeden Fetch
- Möglich: `modelContext.save()` vor dem Fetch erzwingt Cache-Refresh (erklärt warum Pull-to-Refresh funktioniert)

### C. @Query statt manuellem Fetch
- BacklogView nutzt manuelles Fetching (`SyncEngine.sync()`)
- `@Query` in SwiftUI beobachtet automatisch Store-Änderungen
- Umstellung wäre ein großer Refactor (BacklogView ist ~1000 Zeilen)
- Aber `@Query` ist der von Apple vorgesehene Weg für reaktive Daten

### D. Hybrider Ansatz: @Query als Change-Trigger
- `@Query var taskChangeDetector: [LocalTask]` nur für Change-Detection
- `.onChange(of: taskChangeDetector)` → `refreshLocalTasks()`
- Vermeidet den großen Refactor, nutzt aber @Query's automatische Observation

### E. Pull-to-Refresh Mechanismus analysieren
- Pull-to-Refresh FUNKTIONIERT. Der Code-Pfad ist:
  1. `loadTasks()` aufgerufen
  2. `cloudKitMonitor.triggerSync()` → `container.mainContext.save()`
  3. SyncEngine.sync() → LocalTaskSource.fetchAll() → modelContext.fetch()
- Schritt 2 scheint den Unterschied zu machen: `save()` vor dem Fetch
- **Hypothese**: `modelContext.save()` erzwingt einen Merge von pending Remote-Changes
- **Test**: In `refreshLocalTasks()` auch `modelContext.save()` VOR dem Fetch aufrufen

## Relevante Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Services/CloudKitSyncMonitor.swift` | Sync-Monitoring, Change-Detection, Debug-Logging |
| `Sources/Views/BacklogView.swift` | iOS Hauptansicht, manuelle Fetch-Logik |
| `Sources/FocusBloxApp.swift` | iOS App Entry, ModelContainer, V2 Migration |
| `FocusBloxMac/FocusBloxMacApp.swift` | macOS App Entry, ModelContainer, V2 Migration |
| `FocusBloxMac/TaskInspector.swift` | macOS Task-Editor (save()-Fixes) |
| `Sources/Models/LocalTask.swift` | SwiftData Model |
| `Sources/Services/SyncEngine.swift` | Fetch/Update-Logik |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Direkter SwiftData-Zugriff |
| `FocusBloxTests/CloudKitSyncMonitorTests.swift` | 6 Unit Tests (alle grün) |

## Aktueller Debug-Code der noch drin ist

- Diverse `print("[CloudKit Debug]")` Statements in CloudKitSyncMonitor und BacklogView
- Diff-basiertes Snapshot-Logging in CloudKitSyncMonitor.checkForChanges()
- Sollte nach Fix entfernt werden

## Empfehlung für nächsten Versuch

**Ansatz E** (Pull-to-Refresh analysieren) ist am vielversprechendsten, weil:
1. Pull-to-Refresh **funktioniert nachweislich**
2. Der einzige Unterschied zum automatischen Refresh ist der `modelContext.save()`-Aufruf VOR dem Fetch
3. Einfach zu testen: In `refreshLocalTasks()` ein `try? modelContext.save()` vor den Fetch setzen
4. Wenn das funktioniert, ist das Problem gelöst (save() erzwingt Context-Merge)
5. Wenn nicht, muss man tiefer in den SwiftData/Core Data Context-Cache graben
