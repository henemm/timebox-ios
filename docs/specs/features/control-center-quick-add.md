---
entity_id: control-center-quick-add
type: prototype
created: 2026-01-20
updated: 2026-01-20
status: draft
version: "1.0"
workflow: control-center-quick-add
tags: [widget, control-center, ios18, prototype]
---

# Control Center Quick Add Widget Prototype

## Approval

- [ ] Approved for implementation

## Purpose

Prototype um zu testen, ob Gemini's Behauptung stimmt: Ein `@Parameter` mit `requestValueDialog` in einem `AppIntent`, ausgelöst durch einen `ControlWidgetButton`, öffnet ein Eingabefeld direkt aus dem Control Center - ohne die App zu starten.

**Ziel:** Validierung der iOS 18+ Control Center Text-Input Capability.

## Scope

### Affected Files

| Datei | Typ | Beschreibung |
|-------|-----|--------------|
| `TimeBoxWidgets/QuickAddTaskIntent.swift` | CREATE | AppIntent mit @Parameter und requestValueDialog |
| `TimeBoxWidgets/QuickAddTaskControl.swift` | CREATE | ControlWidget mit Button |
| `TimeBoxWidgets/TimeBoxWidgetsBundle.swift` | CREATE | Widget Bundle Entry Point |
| `TimeBox.xcodeproj/project.pbxproj` | MODIFY | Widget Extension Target hinzufügen |

### Estimation

- **Dateien:** 4 (3 neue, 1 modifiziert)
- **LoC:** +80 / -0
- **Komplexität:** Niedrig (isolierter Prototype)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| AppIntents | Framework | Intent Definition |
| WidgetKit | Framework | Control Widget |
| SwiftUI | Framework | UI Components |

## Implementation Details

### 1. QuickAddTaskIntent.swift

```swift
import AppIntents

@available(iOS 18.0, *)
struct QuickAddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Schneller Task"
    static var description = IntentDescription("Task erstellen aus Control Center")

    // KRITISCH: requestValueDialog soll Dialog triggern
    @Parameter(
        title: "Task-Titel",
        requestValueDialog: IntentDialog("Was gibt es zu tun?")
    )
    var taskTitle: String

    func perform() async throws -> some IntentResult {
        // Log für Verifikation
        print("[QuickAdd] Task erstellt: \(taskTitle)")
        return .result(dialog: "Task '\(taskTitle)' erstellt!")
    }
}
```

### 2. QuickAddTaskControl.swift

```swift
import WidgetKit
import SwiftUI

@available(iOS 18.0, *)
struct QuickAddTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.timebox.quickadd") {
            ControlWidgetButton(action: QuickAddTaskIntent()) {
                Label("Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Task")
        .description("Task schnell erfassen")
    }
}
```

### 3. TimeBoxWidgetsBundle.swift

```swift
import WidgetKit
import SwiftUI

@available(iOS 18.0, *)
@main
struct TimeBoxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickAddTaskControl()
    }
}
```

## Expected Behavior

### Best Case (Gemini's Behauptung)

1. User tippt Control Center Button
2. System zeigt Eingabe-Dialog (ohne App zu öffnen)
3. User gibt Task-Titel ein
4. Dialog schließt, Bestätigung erscheint

### Worst Case

1. User tippt Control Center Button
2. App wird geöffnet
3. Kein Vorteil gegenüber normalem Widget

## Test Plan

### Automatisierte Tests

**NICHT MÖGLICH** für Control Center Widgets:
- Control Center ist System-UI (kein XCTest Zugriff)
- Simulator unterstützt keine Control Widgets
- Nur echtes Device kann testen

### Manuelle Verifikation auf Device

| # | Test | Schritte | Erwartung |
|---|------|----------|-----------|
| 1 | Widget erscheint | Settings → Control Center → TimeBox hinzufügen | Widget sichtbar |
| 2 | Button tippbar | Control Center öffnen, Button tippen | Reaktion |
| 3 | Dialog-Verhalten | Button tippen, beobachten | **UNBEKANNT** (Test-Ziel!) |
| 4 | Task-Erstellung | Text eingeben, bestätigen | Console Log zeigt Task |

### Verifikations-Kriterien

```
[ ] Build erfolgreich (iOS 18.0+)
[ ] Widget Extension läuft auf Device
[ ] Control Widget erscheint in Settings
[ ] Button reagiert auf Tap
[ ] → Dialog erscheint? (Hauptfrage!)
```

## Acceptance Criteria

- [ ] Widget Extension Target erstellt und buildet
- [ ] Control Widget erscheint im Control Center (Device)
- [ ] Button-Tap führt zu einer Aktion
- [ ] Dokumentation des tatsächlichen Verhaltens (Dialog oder App-Start)

## Known Limitations

1. **Kein Simulator-Test** - Control Widgets nur auf echtem Device
2. **iOS 18+ only** - Ältere iOS Versionen nicht unterstützt
3. **Prototype** - Keine Daten-Persistenz zur Haupt-App (App Groups später)
4. **Unbekanntes Verhalten** - requestValueDialog von ControlWidget ist undokumentiert

## Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Gemini's Behauptung ist falsch | Mittel | Niedrig | Dokumentieren, Alternative planen |
| Widget buildet nicht | Niedrig | Mittel | Apple Docs folgen |
| Device-Test nicht möglich | Niedrig | Hoch | Henning muss testen |

## Changelog

- 2026-01-20: Initial spec created (PROTOTYPE)
