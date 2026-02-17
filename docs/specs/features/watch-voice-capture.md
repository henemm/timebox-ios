---
entity_id: watch-voice-capture
type: feature
created: 2026-01-31
updated: 2026-02-17
status: draft
version: "2.0"
tags: [watchos, voice-capture, quick-capture, tbd]
---

# Watch Voice Capture

## Approval

- [ ] Approved

## Purpose

watchOS App mit Voice Capture: Button-Tap auf der Apple Watch oeffnet Spracheingabe, Task landet im Backlog als TBD. Sync zu iPhone/Mac via CloudKit.

## User Story

**When** ich unterwegs bin und mir ein Gedanke einfaellt,
**I want to** ihn per Sprache auf meiner Watch festhalten (1 Tap + Sprache),
**So that** ich ihn nicht vergesse und spaeter am iPhone Details ergaenzen kann.

## Anforderungen

### Funktional

1. Watch App starten → Hauptbildschirm mit "Task hinzufuegen" Button
2. Button tippen → TextField erscheint mit aktiver Dictation
3. Sprache eingeben → Text wird transkribiert
4. Bestaetigen → Task wird gespeichert, Bestaetigung angezeigt
5. Task erscheint im iPhone/Mac Backlog als TBD (ohne Wichtigkeit/Dringlichkeit/Dauer)

### Nicht-Funktional

- Max 2 Taps bis zur Eingabe
- Offline-faehig (speichert lokal, synct wenn verbunden via CloudKit)
- Haptic Feedback bei Speicherung (bereits in ConfirmationView)

## Source

### Zu aendernde Dateien

| Datei | Aenderung | Beschreibung |
|-------|-----------|-------------|
| `FocusBloxWatch Watch App/WatchLocalTask.swift` | MODIFY | 5 fehlende Felder + 2 Typ-Korrekturen |
| `FocusBloxWatch Watch App/FocusBloxWatchApp.swift` | MODIFY | ModelContainer mit App Group + CloudKit |
| `FocusBloxWatch Watch App/ContentView.swift` | MODIFY | Placeholder → Task-Capture UI |
| `FocusBloxWatch Watch App/FocusBloxWatch Watch App.entitlements` | MODIFY | App Group eintragen |

### Nicht zu aendern (bereits fertig)

| Datei | Status |
|-------|--------|
| `VoiceInputSheet.swift` | Fertig — TextField + Auto-Focus + OK/Abbrechen |
| `ConfirmationView.swift` | Fertig — Checkmark + Haptic + Auto-Dismiss 2s |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Models/LocalTask.swift` | Reference | Schema-Vorlage fuer WatchLocalTask |
| `Sources/Models/TaskMetadata.swift` | Reference | Muss im Watch-Schema enthalten sein |
| `Sources/FocusBloxApp.swift` | Reference | ModelContainer-Pattern (App Group + CloudKit) |
| App Group `group.com.henning.focusblox` | Entitlement | Geteilter Container fuer Sync |
| CloudKit `iCloud.com.henning.focusblox` | Entitlement | Private DB fuer Cross-Device Sync |

## Implementation Details

### 1. WatchLocalTask.swift — Schema synchronisieren

Fehlende Felder hinzufuegen (identisch mit iOS `LocalTask`):

```swift
// Fehlende Felder (mit CloudKit-kompatiblen Defaults):
var assignedFocusBlockID: String?    // nil = nicht zugewiesen
var rescheduleCount: Int = 0         // Default 0
var completedAt: Date?               // nil = nicht erledigt
var aiScore: Int?                    // nil = nicht gescored
var aiEnergyLevel: String?           // nil = nicht gescored
```

Typ-Korrekturen:
```swift
// VORHER (Watch):
var recurrencePattern: String?       // Optional
var recurrenceWeekdays: [Int]        // Non-optional

// NACHHER (identisch mit iOS):
var recurrencePattern: String = "none"  // Required mit Default
var recurrenceWeekdays: [Int]?          // Optional
```

Default-Korrektur:
```swift
// VORHER:
var taskType: String = "maintenance"

// NACHHER (identisch mit iOS):
var taskType: String = ""
```

### 2. FocusBloxWatchApp.swift — ModelContainer Setup

```swift
import SwiftUI
import SwiftData

@main
struct FocusBloxWatch_Watch_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LocalTask.self, TaskMetadata.self])
        let appGroupID = "group.com.henning.focusblox"

        let config: ModelConfiguration
        if FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil {
            config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.henning.focusblox")
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### 3. ContentView.swift — Task-Capture UI

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<LocalTask> { !$0.isCompleted },
        sort: \LocalTask.createdAt,
        order: .reverse
    ) private var recentTasks: [LocalTask]

    @State private var showingInput = false
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showingInput = true
                } label: {
                    Label("Task hinzufuegen", systemImage: "plus.circle.fill")
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("addTaskButton")

                if !recentTasks.isEmpty {
                    Section("Letzte Tasks") {
                        ForEach(recentTasks.prefix(5)) { task in
                            Text(task.title)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("FocusBlox")
            .sheet(isPresented: $showingInput) {
                VoiceInputSheet { title in
                    saveTask(title: title)
                    showingConfirmation = true
                }
            }
            .sheet(isPresented: $showingConfirmation) {
                ConfirmationView()
            }
        }
    }

    private func saveTask(title: String) {
        let task = LocalTask(title: title)
        // Alle optionalen Felder bleiben nil = TBD
        modelContext.insert(task)
        try? modelContext.save()
    }
}
```

### 4. Entitlements — App Group

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.henning.focusblox</string>
    </array>
</dict>
</plist>
```

### 5. TaskMetadata fuer Watch

Watch braucht `TaskMetadata` im Schema (sonst CloudKit-Sync-Fehler). Die Watch App benutzt TaskMetadata nicht aktiv, aber das Schema muss identisch sein.

Eine Kopie von `Sources/Models/TaskMetadata.swift` muss ins Watch-Target:

```swift
import Foundation
import SwiftData

@Model
final class TaskMetadata {
    var reminderID: String = ""
    var sortOrder: Int = 0
    var manualDuration: Int?
}
```

## Expected Behavior

- **Input:** User tippt "Task hinzufuegen" Button → spricht Task-Titel ein
- **Output:** Task in SwiftData gespeichert mit nur `title` (alles andere nil/default = TBD)
- **Side effects:**
  - CloudKit synct Task zu iPhone/Mac innerhalb weniger Sekunden
  - Task erscheint im iOS/macOS Backlog als TBD (italic, tbd-Badge)
  - Haptic Feedback auf Watch bei Speicherung

## Scope

- **Dateien:** 4 MODIFY + 1 CREATE (TaskMetadata-Kopie)
- **LoC netto:** ~60-80
- **Komplexitaet:** S (1 Session)

## Tests

### Unit Tests (Watch Target)

```swift
// WatchTaskCreationTests.swift
func test_createTask_savesWithTBDDefaults() {
    let task = LocalTask(title: "Test Task")
    XCTAssertEqual(task.title, "Test Task")
    XCTAssertNil(task.importance)      // TBD
    XCTAssertNil(task.urgency)         // TBD
    XCTAssertNil(task.estimatedDuration) // TBD
    XCTAssertFalse(task.isNextUp)
    XCTAssertFalse(task.isCompleted)
    XCTAssertEqual(task.sourceSystem, "local")
}

func test_watchLocalTask_hasAllIOSFields() {
    let task = LocalTask(title: "Schema Test")
    // Neue Felder muessen existieren
    XCTAssertNil(task.assignedFocusBlockID)
    XCTAssertEqual(task.rescheduleCount, 0)
    XCTAssertNil(task.completedAt)
    XCTAssertNil(task.aiScore)
    XCTAssertNil(task.aiEnergyLevel)
    // Typ-Korrekturen
    XCTAssertNil(task.recurrenceWeekdays)  // Optional, nicht []
    XCTAssertEqual(task.recurrencePattern, "none")  // Required, nicht nil
    XCTAssertEqual(task.taskType, "")  // Leer, nicht "maintenance"
}
```

### UI Tests (Watch Target)

```swift
// WatchVoiceCaptureUITests.swift
func test_addTaskButton_exists() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["addTaskButton"].waitForExistence(timeout: 5))
}

func test_addTaskButton_opensInputSheet() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["addTaskButton"].tap()
    XCTAssertTrue(app.textFields["taskTitleField"].waitForExistence(timeout: 3))
}

func test_saveTask_showsConfirmation() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["addTaskButton"].tap()
    let textField = app.textFields["taskTitleField"]
    textField.tap()
    textField.typeText("Test Task von Watch")
    app.buttons["saveButton"].tap()
    XCTAssertTrue(app.staticTexts["Task gespeichert"].waitForExistence(timeout: 3))
}

func test_savedTask_appearsInList() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["addTaskButton"].tap()
    let textField = app.textFields["taskTitleField"]
    textField.tap()
    textField.typeText("Mein Watch Task")
    app.buttons["saveButton"].tap()
    // Warten bis Confirmation verschwindet
    sleep(3)
    // Task sollte in der Liste erscheinen
    XCTAssertTrue(app.staticTexts["Mein Watch Task"].waitForExistence(timeout: 5))
}
```

## Known Limitations

- watchOS Simulator unterstuetzt keine Dictation — nur manuelles Tippen testbar
- CloudKit-Sync zwischen Watch und iPhone benoetigt echtes Device-Paar zum Verifizieren
- WatchLocalTask ist eine Kopie von iOS LocalTask (technische Schuld) — langfristig Shared Package
- Watch zeigt nur Titel der letzten Tasks, keine Details (bewusste UX-Entscheidung fuer kleines Display)

## Offene Fragen (geklaert)

1. **Haptic Feedback** → Bereits in ConfirmationView implementiert (WKInterfaceDevice.current().play(.success))
2. **Watch Complications** → Out of Scope, spaeter
3. **Offline-Indikator** → Out of Scope, CloudKit handhabt das transparent

## Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Schema-Mismatch Watch/iOS | Hoch (aktuell!) | Hoch | WatchLocalTask synchronisieren (dieses Ticket) |
| Dictation nicht im Simulator | Sicher | Niedrig | TextField-Input fuer Tests, Dictation auf echtem Device |
| App Group nicht konfiguriert | Hoch (aktuell!) | Hoch | Entitlements korrigieren (dieses Ticket) |
| CloudKit-Sync Latenz | Niedrig | Niedrig | Akzeptabel fuer Capture-Usecase |

## Changelog

- 2026-01-31: Initial spec created (v1.0)
- 2026-02-17: Aktualisiert nach Analyse — WatchLocalTask Schema-Sync, fehlende Felder dokumentiert, TaskMetadata-Kopie ergaenzt, Tests konkretisiert (v2.0)
