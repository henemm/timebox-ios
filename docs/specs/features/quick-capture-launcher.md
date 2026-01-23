---
entity_id: quick-capture-launcher
type: feature
created: 2026-01-22
status: draft
workflow: quick-capture-launcher
---

# Quick Capture Launcher

## Approval

- [ ] Approved for implementation

## Purpose

Control Center Widget öffnet die App via Deep Link (`timebox://create-task`) und präsentiert ein minimalistisches Eingabefeld mit Auto-Focus für schnelle Task-Erfassung. Pivot nach bewiesenem Scheitern von `requestValueDialog` bei ControlWidgets.

## Scope

| Datei | Änderung |
|-------|----------|
| `Resources/Info.plist` | +CFBundleURLTypes mit "timebox" scheme |
| `Sources/TimeBoxApp.swift` | +@State, +onOpenURL, +fullScreenCover |
| `Sources/Views/QuickCaptureView.swift` | NEU: Minimalistisches Eingabefeld |
| `TimeBoxWidgets/QuickAddTaskControl.swift` | OpenIntent statt @Parameter |

**Estimated:** +80 / -15 LoC

## Implementation Details

### 1. Info.plist - URL Scheme

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

### 2. TimeBoxApp.swift - URL Handler

```swift
@State private var showQuickCapture = false

// In body:
.onOpenURL { url in
    if url.host == "create-task" {
        showQuickCapture = true
    }
}
.fullScreenCover(isPresented: $showQuickCapture) {
    QuickCaptureView()
}
```

### 3. QuickCaptureView.swift

Minimalistisch:
- `TextField` mit Placeholder "Was gibt es zu tun?"
- `@FocusState` für Auto-Focus bei Erscheinen
- Cancel/Save Buttons in Toolbar
- `LocalTaskSource.createTask()` für Speicherung
- Nur Titel-Eingabe, keine weiteren Optionen

### 4. QuickAddTaskControl.swift

```swift
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "timebox://create-task")!))
    }
}
```

## Data Flow

```
Control Center Widget tap
    → QuickAddLaunchIntent.perform()
    → OpenURLIntent("timebox://create-task")
    → TimeBoxApp.onOpenURL()
    → showQuickCapture = true
    → QuickCaptureView (fullScreenCover)
    → User types + saves
    → LocalTaskSource.createTask()
    → Task in SwiftData
```

## Test Plan

### UI Tests (TDD RED)

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testQuickCaptureAppears` | App gestartet | Deep Link `timebox://create-task` empfangen | QuickCaptureView erscheint |
| `testQuickCaptureKeyboardFocus` | QuickCaptureView sichtbar | View erscheint | Keyboard ist sichtbar |
| `testQuickCaptureSaveTask` | QuickCaptureView mit Titel | Save getippt | Task im Backlog vorhanden |
| `testQuickCaptureCancel` | QuickCaptureView sichtbar | Cancel getippt | View dismissed |
| `testQuickCaptureSaveDisabledWhenEmpty` | QuickCaptureView ohne Titel | - | Save Button disabled |

### Device Tests (manuell - Widget nicht testbar)

- [ ] Widget in Control Center antippen → App öffnet
- [ ] QuickCaptureView erscheint sofort
- [ ] Keyboard hat Auto-Focus
- [ ] Task eingeben + Save → erscheint im Backlog

## Acceptance Criteria

- [ ] URL Scheme `timebox://create-task` registriert und funktional
- [ ] Widget öffnet App mit QuickCaptureView
- [ ] Keyboard fokussiert automatisch
- [ ] Task wird mit Standardwerten gespeichert (priority=1, duration=15)
- [ ] Cancel schließt ohne Speichern
- [ ] Save schließt und speichert Task

## Known Limitations

- Control Center Widget selbst nicht per XCTest testbar
- Deep Link Simulation möglich, Widget-Tap nicht
- `OpenURLIntent` Alternative falls `openAppWhenRun` nicht funktioniert

## Changelog

- 2026-01-22: Initial spec nach Analyse-Phase
