# Spec: Watch Voice Capture

> Status: Draft
> Erstellt: 2026-01-31
> Story: `docs/project/stories/quick-capture.md`

## Zusammenfassung

watchOS App mit Voice Capture: Button-Tap → Spracheingabe → Task landet im Backlog als TBD.

## User Story

**When** ich unterwegs bin und mir ein Gedanke einfällt,
**I want to** ihn per Sprache auf meiner Watch festhalten (1 Tap + Sprache),
**So that** ich ihn nicht vergesse und später am iPhone Details ergänzen kann.

## Anforderungen

### Funktional

1. **Watch App starten** → Hauptbildschirm mit "Task hinzufügen" Button
2. **Button tippen** → TextField erscheint mit aktiver Dictation
3. **Sprache eingeben** → Text wird transkribiert
4. **Bestätigen** → Task wird gespeichert, Bestätigung angezeigt
5. **Task erscheint im iPhone Backlog** als TBD (ohne Wichtigkeit/Dringlichkeit/Dauer)

### Nicht-Funktional

- Max 2 Taps bis zur Eingabe
- Dictation-Latenz < 2 Sekunden
- Offline-fähig (speichert lokal, synct wenn verbunden)

## Technische Architektur

### Projektstruktur

```
FocusBlox.xcodeproj
├── FocusBlox (iOS App)
├── FocusBloxWatch (watchOS App)    ← NEU
│   ├── FocusBloxWatchApp.swift
│   ├── ContentView.swift
│   └── Info.plist
├── FocusBloxCore (Shared Framework)
│   ├── LocalTask.swift             ← bereits vorhanden
│   ├── TaskMetadata.swift          ← bereits vorhanden
│   └── SharedModelContainer.swift  ← NEU (extrahieren)
└── FocusBloxWidgets (Widget Extension)
```

### Daten-Synchronisation

**Methode:** Shared App Group mit SwiftData

```swift
// Beide Apps nutzen denselben Container:
let container = try SharedModelContainer.create()
// → group.com.henning.focusblox
```

Die Watch schreibt direkt in die geteilte SwiftData-Datenbank. Das iPhone sieht die Tasks automatisch beim nächsten Öffnen.

### Watch App Entitlement

```xml
<!-- FocusBloxWatch.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.henning.focusblox</string>
</array>
```

## UI Design

### Hauptbildschirm (ContentView)

```
┌─────────────────────┐
│                     │
│    FocusBlox        │
│    ──────────       │
│                     │
│  ┌───────────────┐  │
│  │  + Task       │  │
│  │  hinzufügen   │  │
│  └───────────────┘  │
│                     │
│  Letzte Tasks:      │
│  • Meeting vorbe... │
│  • Einkaufen        │
│                     │
└─────────────────────┘
```

### Eingabe-Sheet

```
┌─────────────────────┐
│                     │
│  Neuer Task         │
│  ──────────────     │
│                     │
│  ┌───────────────┐  │
│  │ 🎤 Dictation  │  │
│  │               │  │
│  └───────────────┘  │
│                     │
│  [Abbrechen] [OK]   │
│                     │
└─────────────────────┘
```

### Bestätigung

```
┌─────────────────────┐
│                     │
│        ✓            │
│                     │
│   Task gespeichert  │
│                     │
│  (auto-dismiss 2s)  │
│                     │
└─────────────────────┘
```

## Implementation

### 1. Xcode Target erstellen

```bash
# In Xcode:
File → New → Target → watchOS → App
Name: FocusBloxWatch
Bundle ID: com.henning.focusblox.watchkitapp
Deployment: watchOS 11.0
```

### 2. FocusBloxWatchApp.swift

```swift
import SwiftUI
import SwiftData

@main
struct FocusBloxWatchApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
```

### 3. ContentView.swift

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalTask.createdAt, order: .reverse)
    private var recentTasks: [LocalTask]

    @State private var showingInput = false
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showingInput = true
                } label: {
                    Label("Task hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)

                if !recentTasks.isEmpty {
                    Section("Letzte Tasks") {
                        ForEach(recentTasks.prefix(3)) { task in
                            Text(task.title)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("FocusBlox")
            .sheet(isPresented: $showingInput) {
                VoiceInputSheet(
                    onSave: { title in
                        saveTask(title: title)
                        showingConfirmation = true
                    }
                )
            }
            .sheet(isPresented: $showingConfirmation) {
                ConfirmationView()
            }
        }
    }

    private func saveTask(title: String) {
        let task = LocalTask(
            title: title,
            importance: nil,
            estimatedDuration: nil,
            urgency: nil
        )
        task.isNextUp = false
        modelContext.insert(task)
        try? modelContext.save()
    }
}
```

### 4. VoiceInputSheet.swift

```swift
import SwiftUI

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @FocusState private var isFocused: Bool

    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Was möchtest du tun?", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding()
            }
            .navigationTitle("Neuer Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if !taskTitle.isEmpty {
                            onSave(taskTitle)
                            dismiss()
                        }
                    }
                    .disabled(taskTitle.isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
```

### 5. ConfirmationView.swift

```swift
import SwiftUI

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            Text("Task gespeichert")
                .font(.headline)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
}
```

## Shared Code Extraktion

`SharedModelContainer` muss in `FocusBloxCore` verschoben werden:

```swift
// FocusBloxCore/SharedModelContainer.swift
import SwiftData

public enum SharedModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    public static func create() throws -> ModelContainer {
        // ... (bestehende Implementation)
    }
}
```

## Tests

### Unit Tests (FocusBloxTests)

```swift
// SharedModelContainerTests.swift
func testWatchCanAccessSharedContainer() throws {
    let container = try SharedModelContainer.create()
    let context = ModelContext(container)

    // Simulate Watch creating a task
    let task = LocalTask(title: "Watch Task", importance: nil, estimatedDuration: nil, urgency: nil)
    context.insert(task)
    try context.save()

    // Verify task exists
    let descriptor = FetchDescriptor<LocalTask>()
    let tasks = try context.fetch(descriptor)
    XCTAssertTrue(tasks.contains { $0.title == "Watch Task" })
}
```

### UI Tests (FocusBloxWatchUITests)

```swift
// WatchVoiceCaptureUITests.swift
func testAddTaskButtonExists() throws {
    let app = XCUIApplication()
    app.launch()

    let addButton = app.buttons["Task hinzufügen"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
}

func testTaskInputSheetAppears() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Task hinzufügen"].tap()

    let textField = app.textFields.firstMatch
    XCTAssertTrue(textField.waitForExistence(timeout: 3))
}
```

## Akzeptanzkriterien

- [ ] watchOS Target erstellt und baut
- [ ] Watch App startet auf Simulator
- [ ] "Task hinzufügen" Button sichtbar
- [ ] Tippen öffnet Eingabe-Sheet
- [ ] TextField akzeptiert Text (Dictation funktioniert auf echtem Device)
- [ ] Task wird in SharedModelContainer gespeichert
- [ ] Task erscheint im iPhone Backlog nach App-Öffnung
- [ ] Bestätigungs-Animation nach Speichern

## Offene Fragen

1. **Watch Complications:** Später hinzufügen?
2. **Haptic Feedback:** Bei erfolgreicher Speicherung?
3. **Offline-Indikator:** Anzeigen wenn nicht verbunden?

## Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| SwiftData-Konflikt zwischen Geräten | Niedrig | Mittel | Keine gleichzeitigen Writes |
| Dictation funktioniert nicht im Simulator | Sicher | Niedrig | Echtes Device für Tests |
| App Group nicht korrekt konfiguriert | Mittel | Hoch | Entitlements prüfen |

---

*Spec Version 1.0 - 2026-01-31*
