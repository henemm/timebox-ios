# iOS Task-Eingabemethoden - Recherche

**Erstellt:** 2026-01-20
**Zweck:** Uebersicht ueber alle verfuegbaren iOS-Eingabemethoden fuer schnelle Task-Erfassung
**Status:** Recherche (keine Implementierung)

---

## Inhaltsverzeichnis

1. [System-Level Eingaben](#1-system-level-eingaben)
2. [Widget-basierte Eingaben](#2-widget-basierte-eingaben)
3. [Spracheingabe](#3-spracheingabe)
4. [Shortcuts/Automation](#4-shortcutsautomation)
5. [Apple Watch Input](#5-apple-watch-input)
6. [Andere Methoden](#6-andere-methoden)
7. [Bewertungsmatrix](#7-bewertungsmatrix)
8. [Empfehlung](#8-empfehlung)

---

## 1. System-Level Eingaben

### 1.1 Spotlight Search Integration

**Wie funktioniert es:**
- User tippt Suchbegriff in Spotlight
- App erscheint in Suchergebnissen mit Shortcuts/Actions
- Direkter Sprung zu spezifischer App-Funktion moeglich

**Framework/API:**
- `CoreSpotlight` Framework
- `CSSearchableItem` fuer indexierte Inhalte
- `NSUserActivity` fuer Handoff und Spotlight-Integration

**Implementierung:**
```swift
import CoreSpotlight
import MobileCoreServices

let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
attributeSet.title = "Neue Task erstellen"
attributeSet.contentDescription = "Task in TimeBox hinzufuegen"

let item = CSSearchableItem(
    uniqueIdentifier: "com.timebox.newtask",
    domainIdentifier: "tasks",
    attributeSet: attributeSet
)

CSSearchableIndex.default().indexSearchableItems([item])
```

**Aufwand:** Gering (1-2 Tage)

**Vorteile:**
- Systemweiter Zugriff
- Keine zusaetzliche UI noetig
- User kennt Spotlight bereits

**Nachteile:**
- Nur zum Springen in die App, nicht fuer direkte Eingabe
- Kein direktes Textfeld in Spotlight

---

### 1.2 Siri Dictation (System-Diktierfunktion)

**Wie funktioniert es:**
- Mikrofon-Button auf der iOS-Tastatur
- Automatische Speech-to-Text Konvertierung
- Funktioniert in jedem TextField

**Framework/API:**
- Keine spezielle API noetig
- System-Feature, das automatisch in TextFields verfuegbar ist

**Implementierung:**
- Automatisch verfuegbar in allen `TextField` und `TextEditor` Views
- Optional: `.keyboardType(.default)` sicherstellen

**Aufwand:** Keiner (bereits vorhanden)

**Vorteile:**
- Kostenlos, keine Implementierung
- User kennt das Feature
- Hohe Erkennungsqualitaet

**Nachteile:**
- Erfordert, dass App geoeffnet ist
- Kein Hands-free Modus

---

### 1.3 Control Center Integration

**Wie funktioniert es:**
- Custom Control Center Buttons (iOS 18+)
- Direkter Zugriff auf App-Funktionen

**Framework/API:**
- `ControlKit` (iOS 18+, neu)
- Sehr limitiert - nur Apple-eigene Apps haben vollen Zugriff

**Aufwand:** Nicht verfuegbar fuer Third-Party Apps (Stand iOS 18)

**Vorteile:**
- Schnellster Systemzugriff
- Ein-Tap Zugang

**Nachteile:**
- Nicht fuer Third-Party Apps verfuegbar
- Apple-exklusiv

---

## 2. Widget-basierte Eingaben

### 2.1 Home Screen Widgets

**Wie funktioniert es:**
- Widget zeigt App-Inhalte auf Home Screen
- Tap oeffnet App an spezifischer Stelle
- Keine direkte Texteingabe im Widget

**Framework/API:**
- `WidgetKit`
- `SwiftUI` fuer Widget-UI
- `Link` oder `widgetURL` fuer Deep-Links

**Implementierung:**
```swift
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "QuickAdd",
            provider: Provider()
        ) { entry in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Quick Add")
        .description("Schnell neue Task erstellen")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickAddWidgetView: View {
    var body: some View {
        Link(destination: URL(string: "timebox://newtask")!) {
            VStack {
                Image(systemName: "plus.circle.fill")
                Text("Neue Task")
            }
        }
    }
}
```

**Aufwand:** Mittel (3-5 Tage)

**Vorteile:**
- Immer sichtbar auf Home Screen
- Ein-Tap Zugang zur App
- User-Erwartung entsprechend

**Nachteile:**
- Keine Texteingabe direkt im Widget
- Oeffnet immer die App

---

### 2.2 Lock Screen Widgets (iOS 16+)

**Wie funktioniert es:**
- Kleine Widgets auf dem Sperrbildschirm
- Gleiche Technik wie Home Screen Widgets
- Tap oeffnet App (nach Face ID/Touch ID)

**Framework/API:**
- `WidgetKit` mit `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`

**Implementierung:**
```swift
.supportedFamilies([.accessoryCircular, .accessoryRectangular])
```

**Aufwand:** Gering (1-2 Tage, wenn Home Screen Widget existiert)

**Vorteile:**
- Schnellster Zugang ohne Entsperren des Home Screens
- Kompakte Darstellung

**Nachteile:**
- Sehr limitierter Platz
- Keine Interaktion ohne Entsperren
- Nur Link-Funktion

---

### 2.3 Interactive Widgets (iOS 17+)

**Wie funktioniert es:**
- Widgets mit Buttons und Toggles
- Direkte Interaktion OHNE App zu oeffnen
- Aktionen werden ueber App Intents ausgefuehrt

**Framework/API:**
- `WidgetKit` + `AppIntents`
- `Button` mit `AppIntent` Action
- `Toggle` mit `AppIntent` Action

**Implementierung:**
```swift
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"

    @Parameter(title: "Task Name")
    var taskName: String

    func perform() async throws -> some IntentResult {
        // Task erstellen
        return .result()
    }
}

struct InteractiveWidget: View {
    var body: some View {
        Button(intent: AddTaskIntent(taskName: "Quick Task")) {
            Label("Hinzufuegen", systemImage: "plus")
        }
    }
}
```

**Aufwand:** Mittel (3-5 Tage)

**Vorteile:**
- Direkte Aktion ohne App-Oeffnung
- Modernes iOS-Feature
- Gute UX fuer Quick Actions

**Nachteile:**
- Keine Texteingabe im Widget (nur vordefinierte Aktionen)
- Parameter muessen vorher definiert sein

---

## 3. Spracheingabe

### 3.1 Siri Integration (SiriKit)

**Wie funktioniert es:**
- User spricht: "Hey Siri, erstelle Task in TimeBox"
- Siri erkennt Intent und leitet an App weiter
- App verarbeitet den Intent

**Framework/API:**
- `Intents` Framework (Legacy)
- `AppIntents` Framework (iOS 16+, empfohlen)
- `INAddTasksIntent` fuer Task-Erstellung

**Implementierung (App Intents - Modern):**
```swift
import AppIntents

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Erstellt eine neue Task in TimeBox")

    @Parameter(title: "Task Name")
    var taskName: String

    @Parameter(title: "Prioritaet", default: .medium)
    var priority: TaskPriority

    static var parameterSummary: some ParameterSummary {
        Summary("Erstelle Task '\(\.$taskName)' mit Prioritaet \(\.$priority)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Task in der App erstellen
        let task = TaskManager.shared.createTask(name: taskName, priority: priority)
        return .result(dialog: "Task '\(taskName)' wurde erstellt.")
    }
}

// In App registrieren
struct TimeBoxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Erstelle Task in \(.applicationName)",
                "Neue Aufgabe in \(.applicationName)",
                "Task hinzufuegen zu \(.applicationName)"
            ],
            shortTitle: "Task erstellen",
            systemImageName: "plus.circle"
        )
    }
}
```

**Aufwand:** Mittel-Hoch (5-7 Tage)

**Vorteile:**
- Komplett Hands-free
- Funktioniert auch bei gesperrtem Geraet
- Systemweite Integration
- Siri Suggestions

**Nachteile:**
- Siri-Erkennung nicht immer zuverlaessig
- Komplexe Parameter schwierig
- User muessen Phrases lernen

---

### 3.2 Voice Dictation mit SpeechKit (In-App)

**Wie funktioniert es:**
- Eigener Mikrofon-Button in der App
- Echtzeit-Transkription waehrend User spricht
- Volle Kontrolle ueber UI und Verarbeitung

**Framework/API:**
- `Speech` Framework
- `SFSpeechRecognizer`
- `AVAudioEngine` fuer Audio-Capture

**Implementierung:**
```swift
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript = ""
    @Published var isRecording = false

    func startRecording() throws {
        // Vorherige Session beenden
        recognitionTask?.cancel()
        recognitionTask = nil

        // Audio Session konfigurieren
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
}
```

**Permissions (Info.plist):**
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>TimeBox nutzt Spracherkennung fuer schnelle Task-Eingabe</string>
<key>NSMicrophoneUsageDescription</key>
<string>TimeBox benoetigt Mikrofon-Zugriff fuer Spracheingabe</string>
```

**Aufwand:** Mittel (4-5 Tage)

**Vorteile:**
- Volle Kontrolle ueber UI
- Echtzeit-Feedback
- Kann mit eigener Logik kombiniert werden
- On-Device Processing moeglich (iOS 13+)

**Nachteile:**
- Erfordert Permissions
- Batterieverbrauch
- Komplexere Implementierung

---

## 4. Shortcuts/Automation

### 4.1 Shortcuts App Integration

**Wie funktioniert es:**
- User erstellt Shortcuts in der Shortcuts-App
- Shortcut ruft App-Aktion auf
- Kann mit Automationen kombiniert werden (Zeit, Ort, etc.)

**Framework/API:**
- `AppIntents` Framework (iOS 16+)
- Gleiche Implementation wie Siri Integration

**Vorteile ueber Siri:**
- Visuelle Konfiguration
- Kombination mit anderen Apps
- Automationen (Zeit/Ort-basiert)

**Aufwand:** Inklusive bei Siri-Implementation

---

### 4.2 Focus Filters (iOS 16+)

**Wie funktioniert es:**
- App-Verhalten aendert sich basierend auf aktivem Focus Mode
- Z.B. "Arbeit"-Focus zeigt nur Arbeits-Tasks
- Automatische Filterung ohne User-Interaktion

**Framework/API:**
- `AppIntents` mit `SetFocusFilterIntent`

**Implementierung:**
```swift
import AppIntents

struct TimeBoxFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "TimeBox Focus Filter"

    @Parameter(title: "Kategorie anzeigen")
    var category: TaskCategory?

    @Parameter(title: "Nur heute")
    var todayOnly: Bool

    func perform() async throws -> some IntentResult {
        // Filter in App setzen
        await FilterManager.shared.setFilter(category: category, todayOnly: todayOnly)
        return .result()
    }
}
```

**Aufwand:** Gering-Mittel (2-3 Tage)

**Vorteile:**
- Automatische Kontextanpassung
- Keine User-Interaktion noetig
- Modernes iOS-Feature

**Nachteile:**
- Nicht fuer Task-EINGABE, nur Filterung
- User muss Focus Modes verstehen/nutzen

---

## 5. Apple Watch Input

### 5.1 Complication-basierte Eingabe

**Wie funktioniert es:**
- Tap auf Complication oeffnet Watch-App
- Watch-App bietet schnelle Eingabe

**Framework/API:**
- `ClockKit` (watchOS 7+)
- `WidgetKit` (watchOS 9+, empfohlen)

**Implementierung:**
```swift
// Watch Widget mit Link
struct WatchQuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchQuickAdd", provider: Provider()) { entry in
            Link(destination: URL(string: "timebox://watch/newtask")!) {
                Image(systemName: "plus.circle")
            }
        }
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}
```

**Aufwand:** Hoch (erfordert Watch-App, 1-2 Wochen)

**Vorteile:**
- Immer am Handgelenk
- Schnellster physischer Zugang

**Nachteile:**
- Erfordert Watch-App Entwicklung
- Kleine Tastatur fuer Text
- Separates Target

---

### 5.2 Watch Quick Actions

**Wie funktioniert es:**
- Vordefinierte Actions in Watch-App
- Diktierfunktion auf Watch
- Force Touch Menu (aeltere watchOS)

**Framework/API:**
- WatchKit + SwiftUI
- `.presentTextInputController` fuer Diktat

**Aufwand:** Teil der Watch-App Entwicklung

---

## 6. Andere Methoden

### 6.1 Share Sheet Integration

**Wie funktioniert es:**
- User markiert Text in Safari/Notes/etc.
- Waehlt "Teilen" und dann TimeBox
- Text wird als neue Task uebernommen

**Framework/API:**
- Share Extension (App Extension)
- `NSExtensionActivationSupportsText`

**Implementierung:**

**Info.plist der Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

**ShareViewController.swift:**
```swift
import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        return !contentText.isEmpty
    }

    override func didSelectPost() {
        guard let text = contentText else { return }

        // Task erstellen via App Group
        let userDefaults = UserDefaults(suiteName: "group.com.timebox.shared")
        var pendingTasks = userDefaults?.stringArray(forKey: "pendingTasks") ?? []
        pendingTasks.append(text)
        userDefaults?.set(pendingTasks, forKey: "pendingTasks")

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // Optionale Konfiguration (Kategorie, Prioritaet)
        return []
    }
}
```

**Aufwand:** Mittel (3-4 Tage)

**Vorteile:**
- Systemweiter Zugang
- Natuerlicher Workflow (Copy-Paste Alternative)
- Funktioniert ueberall wo Share Sheet verfuegbar

**Nachteile:**
- Erfordert App Extension Target
- App Group fuer Datenaustausch noetig
- Mehrere Taps noetig

---

### 6.2 Action Extension (Custom Action)

**Wie funktioniert es:**
- Aehnlich Share Extension
- Erscheint in Action-Row des Share Sheets
- Fuer schnelle Aktionen ohne UI

**Framework/API:**
- Action Extension
- `NSExtensionPointIdentifier: com.apple.ui-services`

**Aufwand:** Mittel (3-4 Tage)

**Unterschied zu Share Extension:**
- Action Extensions fuer "Aktionen auf Content"
- Share Extensions fuer "Content teilen"
- Action kann inline im Share Sheet bleiben

---

### 6.3 Drag & Drop

**Wie funktioniert es:**
- Text aus anderen Apps auf TimeBox-Icon ziehen
- Oder innerhalb der App zwischen Views

**Framework/API:**
- `onDrop(of:delegate:)` Modifier
- `UTType.plainText` fuer Text-Drop
- Nur sinnvoll auf iPad

**Aufwand:** Gering (1-2 Tage)

**Vorteile:**
- Natuerliche Interaktion auf iPad
- Multitasking-freundlich

**Nachteile:**
- Nur iPad (Split View noetig)
- iPhone-User koennen es nicht nutzen

---

### 6.4 Live Activities (iOS 16.1+)

**Wie funktioniert es:**
- Persistente Notification auf Lock Screen
- Dynamic Island Integration (iPhone 14 Pro+)
- Zeigt laufende Aktivitaet

**Framework/API:**
- `ActivityKit`
- `ActivityAttributes` fuer Daten
- Widget-aehnliche UI

**Implementierung:**
```swift
import ActivityKit

struct TaskActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskName: String
        var remainingTime: Int
    }

    var taskId: String
}

// Activity starten
func startFocusActivity(task: Task) {
    let attributes = TaskActivityAttributes(taskId: task.id)
    let state = TaskActivityAttributes.ContentState(
        taskName: task.name,
        remainingTime: task.duration
    )

    do {
        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    } catch {
        print("Error starting activity: \(error)")
    }
}
```

**Aufwand:** Mittel-Hoch (4-6 Tage)

**Vorteile:**
- Immer sichtbar waehrend Focus-Session
- Dynamic Island ist prominent
- Modernes Feature

**Nachteile:**
- Nicht fuer EINGABE, nur Anzeige
- Begrenzte Interaktionsmoeglichkeiten
- Batterieverbrauch

---

### 6.5 URL Schemes / Deep Links

**Wie funktioniert es:**
- Custom URL oeffnet App an spezifischer Stelle
- Kann von anderen Apps/Shortcuts aufgerufen werden
- `timebox://newtask?name=Einkaufen`

**Framework/API:**
- `onOpenURL` Modifier
- Info.plist URL Types

**Implementierung:**
```swift
// Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>timebox</string>
        </array>
    </dict>
</array>

// App.swift
@main
struct TimeBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "timebox" else { return }

        switch url.host {
        case "newtask":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let name = components?.queryItems?.first(where: { $0.name == "name" })?.value
            // Task erstellen oder Sheet oeffnen
        default:
            break
        }
    }
}
```

**Aufwand:** Gering (1 Tag)

**Vorteile:**
- Basis fuer viele andere Features
- Shortcuts-kompatibel
- Einfach zu implementieren

**Nachteile:**
- Keine direkte User-Interaktion
- Muss von woanders aufgerufen werden

---

## 7. Bewertungsmatrix

| Methode | Aufwand | User-Freundlichkeit | Geschwindigkeit | Hands-free | iPhone | iPad | Watch |
|---------|---------|---------------------|-----------------|------------|--------|------|-------|
| **System Dictation** | Keine | Hoch | Mittel | Nein | Ja | Ja | Ja |
| **Home Screen Widget** | Mittel | Hoch | Hoch | Nein | Ja | Ja | - |
| **Lock Screen Widget** | Gering* | Hoch | Sehr hoch | Nein | Ja | Ja | - |
| **Interactive Widget** | Mittel | Hoch | Sehr hoch | Nein | Ja | Ja | - |
| **Siri Integration** | Mittel-Hoch | Mittel | Hoch | Ja | Ja | Ja | Ja |
| **SpeechKit (In-App)** | Mittel | Hoch | Hoch | Nein | Ja | Ja | Ja |
| **Share Extension** | Mittel | Hoch | Mittel | Nein | Ja | Ja | - |
| **Live Activities** | Mittel-Hoch | Hoch | - | Nein | Ja | - | - |
| **Watch Complication** | Hoch | Hoch | Sehr hoch | Nein | - | - | Ja |
| **URL Schemes** | Gering | Niedrig | Hoch | Nein | Ja | Ja | - |
| **Spotlight** | Gering | Mittel | Mittel | Nein | Ja | Ja | - |
| **Focus Filters** | Gering-Mittel | Mittel | - | Ja | Ja | Ja | - |

*Lock Screen Widget: Gering, wenn Home Screen Widget bereits existiert

---

## 8. Empfehlung

### Sofort umsetzbar (Quick Wins)

1. **URL Scheme / Deep Links** - Basis fuer alles andere
2. **Home Screen Widget** mit Quick-Add Button
3. **Lock Screen Widget** (Erweiterung von 2)

### Mittelfristig (Hoher Impact)

4. **Siri Integration mit App Intents** - Hands-free Eingabe
5. **Interactive Widget** - Quick Actions ohne App-Oeffnung
6. **Share Extension** - Systemweite Integration

### Langfristig (Nice to Have)

7. **Watch App mit Complications**
8. **Live Activities** fuer Focus-Sessions
9. **SpeechKit In-App** fuer Power-User

### Empfohlene Reihenfolge

```
Phase 1: URL Schemes + Widgets
         → Schnelle Gewinne, gute User Experience
         → Aufwand: 1 Woche

Phase 2: Siri + Shortcuts Integration
         → Hands-free und Automation
         → Aufwand: 1 Woche

Phase 3: Share Extension
         → Systemweite Integration
         → Aufwand: 3-4 Tage

Phase 4: Watch App (optional)
         → Erfordert separates Projekt
         → Aufwand: 2+ Wochen
```

---

## Zusammenfassung

Die **effektivste Kombination** fuer schnelle Task-Eingabe:

1. **Widget** auf Home/Lock Screen fuer visuellen Quick-Access
2. **Siri/Shortcuts** fuer Hands-free und Automation
3. **Share Extension** fuer systemweite Text-Uebernahme
4. **System Dictation** in der App (kostenlos, bereits vorhanden)

Diese Kombination deckt alle gaengigen User-Szenarien ab:
- Unterwegs (Siri)
- Am Schreibtisch (Widget, Share)
- Beim Tippen (Dictation)
- Automatisiert (Shortcuts)
