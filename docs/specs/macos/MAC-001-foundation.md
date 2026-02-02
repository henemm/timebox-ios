# MAC-001: macOS App Foundation

> Status: Draft
> Erstellt: 2026-01-31
> Priorität: P0 (Fundament)

## Zusammenfassung

Grundgerüst der macOS App mit Shared Code Integration. Ermöglicht das Bauen und Starten einer minimalen macOS App, die auf dieselben Daten zugreift wie die iOS App.

## Kontext

Die iOS App nutzt:
- **SwiftData** mit CloudKit Sync (LocalTask, TaskMetadata)
- **App Group** `group.com.henning.focusblox` für Widget-Zugriff
- **FocusBloxCore** Framework (aktuell nur LiveActivity Attributes)

Die Watch App zeigt, wie ein zusätzliches Target die Models wiederverwenden kann.

## Scope

### In Scope
- Neues macOS Target `FocusBloxMac`
- Shared Models wiederverwenden (LocalTask, PlanItem, FocusBlock, etc.)
- Shared Services wiederverwenden (SyncEngine, LocalTaskSource)
- SwiftData Container mit App Group
- Minimale UI: Fenster mit Task-Liste (Proof of Concept)
- Build & Run auf macOS funktioniert

### Out of Scope
- Menu Bar Widget (MAC-010)
- Keyboard Shortcuts (MAC-012)
- Komplette Views (MAC-013, MAC-014)
- iCloud Sync Verifizierung (MAC-002)

## Technische Umsetzung

### 1. Xcode Target Konfiguration

```
Target: FocusBloxMac
Platform: macOS 26.2
Bundle ID: com.henning.focusblox.mac
App Group: group.com.henning.focusblox
```

### 2. Shared Code Struktur

Dateien die zum macOS Target hinzugefügt werden:

**Models (Sources/Models/):**
- `LocalTask.swift`
- `PlanItem.swift`
- `FocusBlock.swift`
- `CalendarEvent.swift`
- `TaskMetadata.swift`
- `AppSettings.swift`
- `WarningTiming.swift`
- `ReminderData.swift`
- `ReminderListInfo.swift`

**Protocols (Sources/Protocols/):**
- `TaskSource.swift`
- `EventKitRepositoryProtocol.swift`

**Services (Sources/Services/):**
- `SyncEngine.swift`
- `LocalTaskSource.swift`
- `EventKitRepository.swift`
- `RemindersSyncService.swift`

### 3. macOS App Entry Point

Neue Datei: `FocusBloxMac/FocusBloxMacApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct FocusBloxMacApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try MacModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacContentView()
        }
        .modelContainer(container)
    }
}
```

### 4. Mac Model Container

Neue Datei: `FocusBloxMac/MacModelContainer.swift`

```swift
enum MacModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])

        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .automatic
        )

        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### 5. Minimal Proof-of-Concept View

Neue Datei: `FocusBloxMac/Views/MacContentView.swift`

```swift
struct MacContentView: View {
    @Query private var tasks: [LocalTask]

    var body: some View {
        NavigationSplitView {
            List(tasks, id: \.uuid) { task in
                Text(task.title)
            }
            .navigationTitle("Tasks")
        } detail: {
            Text("Select a task")
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
```

## Entitlements

Neue Datei: `FocusBloxMac/FocusBloxMac.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.henning.focusblox</string>
    </array>
</dict>
</plist>
```

## Akzeptanzkriterien

- [ ] `xcodebuild -scheme FocusBloxMac -destination 'platform=macOS'` kompiliert ohne Fehler
- [ ] App startet auf macOS und zeigt Fenster
- [ ] Tasks aus iOS App erscheinen in der Liste (nach Sync)
- [ ] Neue Task in macOS erstellt → erscheint in iOS (nach Sync)

## Verifikation

```bash
# Build macOS App
xcodebuild build -project FocusBlox.xcodeproj \
  -scheme FocusBloxMac \
  -destination 'platform=macOS'

# Run auf macOS (manuell in Xcode)
```

## Risiken

| Risiko | Mitigation |
|--------|------------|
| App Group auf macOS anders als iOS | Dokumentation prüfen, ggf. Sandbox-Entitlement anpassen |
| SwiftData Schema-Migration nötig | Gleiche Models verwenden, keine neuen Properties |
| Code-Signing Probleme | Development Team korrekt setzen |

## Abhängigkeiten

- Keine (Fundament)

## Nächste Schritte nach Completion

1. MAC-002: Cross-Platform Sync verifizieren
2. MAC-010: Menu Bar Widget

---
*Spec erstellt: 2026-01-31*
