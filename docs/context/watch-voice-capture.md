# Context: Watch Voice Capture

## Request Summary
Vollständige watchOS App mit Voice Capture: Button-Tap → Spracheingabe → Task landet im Backlog als TBD.

## Aktueller Stand

### Vorhandene Infrastruktur
- **iOS App:** SwiftUI + SwiftData
- **Datenmodell:** `LocalTask` in SwiftData
- **App Groups:** `group.com.henning.focusblox` (für Widgets)
- **Keine watchOS-Unterstützung**

### Relevante Dateien
| Datei | Relevanz |
|-------|----------|
| `Sources/Models/LocalTask.swift` | Task-Modell, muss für Watch zugänglich sein |
| `Sources/FocusBloxApp.swift` | App-Initialisierung, SharedModelContainer |
| `FocusBloxCore/` | Shared Framework (bereits vorhanden) |
| `Sources/Views/QuickCaptureView.swift` | Referenz für minimale Task-Erstellung |

## Technische Anforderungen

### 1. watchOS Target
- Neues Target: `FocusBloxWatch`
- Minimum Deployment: watchOS 11.0 (passend zu iOS 26)
- Standalone Watch App (nicht WatchKit Extension)

### 2. Daten-Synchronisation
**Option A: WatchConnectivity**
- Direkte Message-Übertragung iPhone ↔ Watch
- Komplexer, aber zuverlässig
- Benötigt: `WCSession` auf beiden Seiten

**Option B: App Groups + SwiftData** (Empfohlen)
- Shared Container für SwiftData
- Watch schreibt direkt in geteilte DB
- iPhone sieht Tasks automatisch
- Einfacher, weniger Code

### 3. Voice Input
- SwiftUI: `TextField` mit `.textInputAutocapitalization(.sentences)`
- Dictation: Automatisch verfügbar auf Watch
- Kein manuelles Speech Recognition nötig

### 4. UI (Minimal)
- Ein Button "Task hinzufügen"
- TextField für Spracheingabe (Watch-Dictation)
- Bestätigung: "Task gespeichert"
- Optional: Liste der letzten 3 Tasks

## Abhängigkeiten

### Upstream (was wir nutzen)
- SwiftData
- App Groups
- watchOS SDK

### Downstream (was uns nutzt)
- Keine (Watch ist Consumer)

## Risiken & Überlegungen

1. **SwiftData auf watchOS:** Unterstützt seit watchOS 10, sollte funktionieren
2. **App Group Sync:** Beide Apps müssen gleiche App Group nutzen
3. **Dictation-Qualität:** Von Apple kontrolliert, nicht beeinflussbar
4. **Speicher:** Watch hat limitierten Speicher, nur IDs speichern?

## Bestehende Patterns

### Task-Erstellung (QuickCaptureView)
```swift
let task = LocalTask(
    title: title,
    importance: nil,  // TBD
    estimatedDuration: nil,  // TBD
    urgency: nil  // TBD
)
task.isNextUp = false
context.insert(task)
```

### Shared Container (FocusBloxApp)
```swift
let container = try SharedModelContainer.create()
// Nutzt App Group: group.com.henning.focusblox
```

## Empfohlene Architektur

```
FocusBloxWatch/
├── FocusBloxWatchApp.swift     # @main App
├── ContentView.swift            # Hauptansicht
├── VoiceCaptureView.swift       # Spracheingabe
└── WatchTaskService.swift       # SwiftData Zugriff
```

Geteilter Code über `FocusBloxCore`:
- `LocalTask` Model
- `SharedModelContainer`

## Nächste Schritte

1. `/analyse` - Detaillierte technische Analyse
2. `/write-spec` - Spec schreiben
3. watchOS Target in Xcode erstellen
4. TDD RED → Implementation

---
*Context erstellt: 2026-01-31*
