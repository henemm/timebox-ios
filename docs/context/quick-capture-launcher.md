# Context: Quick Capture Launcher

## Request Summary

Control Center Widget soll die App via Deep Link (`timebox://create-task`) öffnen und ein minimalistisches Eingabefeld mit Auto-Focus präsentieren. Dies ist der Pivot nach dem bewiesenen Scheitern von `requestValueDialog` bei ControlWidgets.

## Vorgeschichte

- **Geminis Behauptung:** `@Parameter` mit `requestValueDialog` öffnet Dialog direkt aus Control Center
- **Test-Ergebnis:** FALSCH - Intent mit `@Parameter` wird vom System komplett blockiert
- **Beweis:** Intent OHNE Parameter funktioniert (Tock-Sound hörbar), MIT Parameter nicht

Dokumentiert in: `docs/artifacts/control-center-widget/gemini-claim-analysis.md`

## Related Files

| Datei | Relevanz | Änderung |
|-------|----------|----------|
| `Sources/TimeBoxApp.swift` | App Entry Point, braucht URL-Handling | MODIFY: +onOpenURL +fullScreenCover |
| `Resources/Info.plist` | URL Schemes fehlen | MODIFY: +CFBundleURLTypes |
| `TimeBoxWidgets/QuickAddTaskControl.swift` | Aktueller Widget-Code | REPLACE: OpenIntent statt Parameter |
| `TimeBoxWidgets/TimeBoxWidgetsBundle.swift` | Widget Bundle | KEEP (bereits korrekt) |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | Template für Form | REFERENCE für Task-Erstellung |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Task-Speicherung | USE: createTask() Methode |
| `Sources/Models/LocalTask.swift` | SwiftData Model | USE für Task-Erstellung |

## Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Views/QuickCaptureView.swift` | Minimalistisches Eingabefeld mit Auto-Focus |

## Existing Patterns

### 1. Sheet-Präsentation (BacklogView.swift)
```swift
.sheet(isPresented: $showCreateTask) {
    CreateTaskView {
        Task { await loadTasks() }
    }
}
```

### 2. Task-Erstellung (CreateTaskView.swift)
```swift
let taskSource = LocalTaskSource(modelContext: modelContext)
_ = try await taskSource.createTask(
    title: title.trimmingCharacters(in: .whitespaces),
    // ... weitere Parameter
)
```

### 3. Environment für ModelContext
```swift
@Environment(\.modelContext) private var modelContext
```

## Dependencies

### Upstream (was wir nutzen)
- `SwiftData` - ModelContext für Datenspeicherung
- `LocalTaskSource` - Task-Erstellungs-API
- `AppIntents` - Intent für Widget

### Downstream (was uns nutzt)
- Keine - QuickCaptureView ist isoliert

## Technical Approach (von Gemini)

### 1. QuickCaptureView
- Minimalistisch: nur TextEditor + Cancel/Save Buttons
- `@FocusState` für Auto-Focus der Tastatur
- Kein Form, keine komplexen Optionen (Quick Capture!)

### 2. URL-Handling in TimeBoxApp
```swift
.onOpenURL { url in
    if url.absoluteString == "timebox://create-task" {
        showQuickCapture = true
    }
}
```

### 3. Info.plist URL Scheme
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>timebox</string></array>
        <key>CFBundleURLName</key>
        <string>com.henning.timebox</string>
    </dict>
</array>
```

### 4. Widget Intent (OpenIntent)
```swift
struct QuickAddLaunchIntent: OpenIntent {
    static var title: LocalizedStringResource = "New Task"
    func perform() async throws -> some IntentResult {
        return .result(opensApp: true)
    }
}
```

## Risks & Considerations

| Risiko | Impact | Mitigation |
|--------|--------|------------|
| URL Scheme nicht registriert | Widget öffnet nichts | Info.plist prüfen |
| OpenIntent funktioniert nicht | Kein Deep Link | Alternativer URL-Approach |
| Keyboard-Focus verzögert | Schlechte UX | DispatchQueue.main.asyncAfter |
| ModelContext nicht verfügbar | Task nicht speicherbar | Environment korrekt durchreichen |

## Open Questions

- [x] Funktioniert `requestValueDialog` bei ControlWidgets? → **NEIN**
- [ ] Funktioniert `OpenIntent` bei ControlWidgets?
- [ ] Wird die URL korrekt an die App übergeben?
- [ ] Ist `fullScreenCover` besser als `sheet` für Quick Capture?

## Test Strategy

### Manuelle Tests (Device)
1. Widget antippen → App öffnet
2. QuickCaptureView erscheint
3. Keyboard hat Auto-Focus
4. Task eingeben + Save
5. Task erscheint im Backlog

### Unit Tests (möglich)
- `LocalTaskSource.createTask()` - bereits getestet
- QuickCaptureView State-Management

### UI Tests (eingeschränkt)
- Control Center nicht per XCTest erreichbar
- App-interne QuickCaptureView testbar via Deep Link Simulation

## Estimation

- **Dateien:** 3 modifiziert, 1 neu
- **LoC:** ~60 neu, ~20 modifiziert
- **Komplexität:** Niedrig

---

## Analysis (Phase 2)

### Affected Files with Specific Changes

| Datei | Änderungstyp | Konkrete Änderung |
|-------|-------------|-------------------|
| `TimeBoxApp.swift` | MODIFY | +@State showQuickCapture, +onOpenURL handler, +fullScreenCover |
| `Resources/Info.plist` | MODIFY | +CFBundleURLTypes mit "timebox" scheme |
| `TimeBoxWidgets/QuickAddTaskControl.swift` | REPLACE | Neuer OpenIntent statt @Parameter Intent |
| `Sources/Views/QuickCaptureView.swift` | CREATE | Neue View mit TextField, @FocusState, Save/Cancel |

### Scope Assessment

- **Files:** 4 (3 modify, 1 create)
- **Estimated LoC:** +80 / -15
- **Risk Level:** LOW
- **Widget Extension:** Ja, TimeBoxWidgetsExtension betroffen

### Technical Approach

#### 1. Info.plist - URL Scheme registrieren
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>timebox</string></array>
        <key>CFBundleURLName</key>
        <string>com.henning.timebox</string>
    </dict>
</array>
```

#### 2. TimeBoxApp.swift - URL Handler + QuickCapture Sheet
```swift
@State private var showQuickCapture = false

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(\.eventKitRepository, eventKitRepository)
            .onAppear { seedUITestDataIfNeeded() }
            .onOpenURL { url in
                if url.host == "create-task" {
                    showQuickCapture = true
                }
            }
            .fullScreenCover(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
    }
    .modelContainer(sharedModelContainer)
}
```

#### 3. QuickCaptureView.swift - Minimalistisch
```swift
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Was gibt es zu tun?", text: $title)
                    .focused($isFocused)
                    .font(.title2)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveTask() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
```

#### 4. QuickAddTaskControl.swift - OpenIntent
```swift
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "timebox://create-task")!))
    }
}
```

### Data Flow

```
Control Center Widget
    ↓ tap
QuickAddLaunchIntent.perform()
    ↓ returns OpenURLIntent
System opens URL: timebox://create-task
    ↓
TimeBoxApp.onOpenURL()
    ↓ sets showQuickCapture = true
QuickCaptureView appears (fullScreenCover)
    ↓ @FocusState triggers keyboard
User types + saves
    ↓
LocalTaskSource.createTask()
    ↓
Task in SwiftData
```

### Open Questions (Resolved)

- [x] Funktioniert `requestValueDialog` bei ControlWidgets? → **NEIN**
- [x] Pattern für OpenIntent? → `OpenURLIntent` oder `openAppWhenRun`
- [x] Sheet vs fullScreenCover? → **fullScreenCover** für Quick Capture UX
- [ ] Funktioniert OpenURLIntent bei ControlWidgets? → TDD wird es zeigen
