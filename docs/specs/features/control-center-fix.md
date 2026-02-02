# Spec: Control Center Quick Add Fix

> Status: Draft
> Created: 2026-01-25
> Workflow: control-center-fix

## Problem

Das Control Center Widget "Quick Task" öffnet die App nicht. User tippt auf das Widget, aber nichts passiert.

## Root Cause

`QuickAddTaskControl.swift:9-15` verwendet `OpenURLIntent(url)` mit custom URL scheme `timebox://create-task`. iOS blockiert custom URL schemes aus Control Center Widget-Intents.

## Lösung

`openAppWhenRun = true` verwenden statt `OpenURLIntent`. NotificationCenter für Kommunikation zwischen Intent und App.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `FocusBloxWidgets/QuickAddTaskControl.swift` | Intent komplett umschreiben |
| `Sources/FocusBloxApp.swift` | NotificationCenter Observer hinzufügen |

## Implementation

### 1. QuickAddTaskControl.swift

**Vorher:**
```swift
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "timebox://create-task") else {
            return .result()
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
```

**Nachher:**
```swift
struct QuickAddLaunchIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Task"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .quickCaptureRequested,
            object: nil
        )
        return .result()
    }
}

extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("QuickCaptureRequested")
}
```

### 2. FocusBloxApp.swift

**Hinzufügen nach `.onOpenURL`:**
```swift
.onReceive(NotificationCenter.default.publisher(for: .quickCaptureRequested)) { _ in
    showQuickCapture = true
}
```

## Scope

- **Dateien:** 2
- **LoC:** ~+15 / -5
- **Risiko:** Niedrig

## Test-Plan

### Unit Test (möglich)
- NotificationCenter post → `showQuickCapture` wird `true`

### Manueller Test (erforderlich)
Control Center Widgets sind nicht per XCUITest testbar.

1. App auf Device installieren
2. Control Center öffnen
3. Quick Task Widget tippen
4. **Expected:** App öffnet, QuickCaptureView erscheint

## Acceptance Criteria

- [ ] Control Center Widget öffnet App
- [ ] QuickCaptureView erscheint automatisch
- [ ] Tastatur hat Focus
