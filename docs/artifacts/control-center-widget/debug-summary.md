# Control Center Widget - Debug Summary

**Datum:** 2026-01-21
**Ziel:** MVP Test ob `@Parameter` mit `requestValueDialog` ein Texteingabefeld direkt aus dem Control Center öffnet (iOS 26)

---

## Ausgangslage

Geminis Behauptung: Mit `requestValueDialog` in einem AppIntent Parameter kann man direkt aus dem Control Center eine Texteingabe erhalten, ohne die App zu öffnen.

```swift
@Parameter(title: "Task", requestValueDialog: "Was tun?")
public var taskName: String
```

---

## Was wir versucht haben

### 1. Einfacher ControlWidgetButton mit AppIntent
- **Ergebnis:** Button springt zurück, `perform()` wird nicht aufgerufen
- **Fehler:** `viewModel?.action is nil, viewModel is nil`

### 2. ControlWidgetToggle mit SetValueIntent
- **Ergebnis:** Toggle springt zurück
- **Beobachtung:** Alte Toggles behielten plötzlich State, neue nicht

### 3. Version Mismatch Fix
- Widget Extension hatte Version `1.0`, App hatte `1.0.0`
- **Fix:** Beide auf `1.0.0` gesetzt
- **Ergebnis:** Kein Unterschied

### 4. Public Init und Public Modifier
- Alle Intent-Properties auf `public` gesetzt
- Expliziten `public init()` hinzugefügt
- **Ergebnis:** Kein Unterschied

### 5. TimeBoxCore Framework erstellt (Geminis Empfehlung)
- Intent in separates Framework ausgelagert
- Ziel: Eindeutiger Namespace `TimeBoxCore.QuickAddTaskIntent`
- **Konfiguration:**
  - TimeBox (Main App): Embed & Sign
  - TimeBoxWidgetsExtension: Do Not Embed (nur linken)
- **Ergebnis:** `Library not loaded` Fehler, dann Widget erscheint nicht mehr

### 6. AppShortcutsProvider hinzugefügt (Geminis Empfehlung)
- `TimeBoxShortcuts.swift` erstellt
- Registriert Intent-Metadaten beim System
- **Ergebnis:** Widget erscheint immer noch nicht in Control Center

---

## Aktuelle Projektstruktur

```
TimeBox/
├── TimeBoxCore/                    # Framework
│   ├── QuickAddTaskIntent.swift    # Der Intent (public)
│   ├── TimeBoxShortcuts.swift      # AppShortcutsProvider
│   └── TimeBoxCore.swift           # Placeholder
├── TimeBoxWidgets/                 # Widget Extension
│   ├── QuickAddTaskControl.swift   # ControlWidget
│   └── TimeBoxWidgetsBundle.swift  # Widget Bundle
└── Sources/                        # Main App
```

---

## Aktuelle Code-Dateien

### TimeBoxCore/QuickAddTaskIntent.swift
```swift
import AppIntents
import Foundation
import os
import AudioToolbox

public let intentLogger = Logger(subsystem: "com.timebox.core", category: "Intent")

public struct QuickAddTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Quick Task"
    public static var description = IntentDescription("Erstellt einen Task via Control Center.")

    @Parameter(title: "Task", requestValueDialog: "Was tun?")
    public var taskName: String

    public init() {}

    public func perform() async throws -> some IntentResult {
        intentLogger.fault("🔥 QuickAddTaskIntent.perform() called")
        AudioServicesPlaySystemSound(1004)
        return .result()
    }
}
```

### TimeBoxCore/TimeBoxShortcuts.swift
```swift
import AppIntents

public struct TimeBoxShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddTaskIntent(),
            phrases: [
                "Erstelle einen Task in \(.applicationName)",
                "Neuer Task in \(.applicationName)"
            ],
            shortTitle: "Schneller Task",
            systemImageName: "plus.circle"
        )
    }
    public static var shortcutTileColor: ShortcutTileColor = .blue
}
```

### TimeBoxWidgets/QuickAddTaskControl.swift
```swift
import WidgetKit
import SwiftUI
import AppIntents
import TimeBoxCore

struct QuickAddTaskControl: ControlWidget {
    static let kind: String = "com.timebox.quickadd"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddTaskIntent()) {
                Label("Quick Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Task")
        .description("Task direkt aus Control Center erstellen")
    }
}
```

---

## Bestätigte Erkenntnisse

1. **Die Extension läuft:** Logs zeigen `com.henning.timebox.TimeBoxWidgets` wird vom System geladen
2. **Framework-Linking funktioniert:** Build ist erfolgreich
3. **Embedding ist korrekt:** Main App embeddet, Extension linkt nur

---

## Offene Fragen

1. **Warum erscheint das ControlWidget nicht in Control Center?**
   - Extension läuft laut Logs
   - Aber Widget ist nicht in "Control Center hinzufügen" sichtbar

2. **Werden ControlWidgets anders registriert als normale Widgets?**
   - Möglicherweise fehlt eine Info.plist Konfiguration
   - Oder ein spezielles Entitlement

3. **Ist `requestValueDialog` überhaupt für Control Center gedacht?**
   - Geminis Behauptung basiert auf iOS 26 Beta-Dokumentation
   - Möglicherweise funktioniert es nur für Siri Shortcuts, nicht Control Center

---

## Nächste Schritte

1. **Apple Dokumentation prüfen:** Gibt es spezielle Requirements für ControlWidgets?
2. **Einfachstes Widget testen:** Ohne Framework, ohne Intent-Parameter
3. **Info.plist prüfen:** Fehlt `NSExtensionPointIdentifier` oder ähnliches?
4. **Entitlements prüfen:** Braucht Control Center spezielle Berechtigungen?

---

## Gelöschte Dateien (zur Info)

Diese Dateien wurden während des Debuggings gelöscht:
- `TimeBoxWidgets/QuickAddTaskIntent.swift` (alter Intent, jetzt in Framework)
- `TimeBoxWidgets/DebugControl.swift` (Test-Widget)
- `TimeBoxWidgets/PingControl.swift` (Test-Widget)

---

## Tools die geholfen haben

- `idevicesyslog` - Device Logs (funktioniert schlecht mit iOS 26)
- `ideviceinstaller` - App Installation/Deinstallation
- `Console.app` - Logs filtern (Logger.fault durchbricht Filter)
- `xcrun devicectl` - Device Management (instabil)
