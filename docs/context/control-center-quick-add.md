# Control Center Quick Add Widget - Analyse

**Workflow:** control-center-quick-add
**Phase:** Analyse
**Erstellt:** 2026-01-20
**Typ:** PROTOTYPE / Research

---

## Ziel

Testen ob Gemini's Behauptung stimmt:
> `@Parameter` mit `requestValueDialog` in einem `AppIntent`, der von einem `ControlWidgetButton` ausgelöst wird, öffnet ein Eingabefeld **direkt aus dem Control Center**, ohne die App zu starten.

Falls dies funktioniert, könnte TimeBox einen Quick-Add Button im Control Center haben, der direkt eine Texteingabe ermöglicht.

---

## Gemini's Code-Vorschlag

```swift
@Parameter(
    title: "Task-Titel",
    requestValueDialog: IntentDialog("Was gibt es zu tun?")
)
var taskTitle: String
```

Kombiniert mit:

```swift
struct QuickAddTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "QuickAddTask") {
            ControlWidgetButton(action: QuickAddTaskIntent()) {
                Label("Task", systemImage: "plus.circle.fill")
            }
        }
    }
}
```

---

## Analyse

### Was wir wissen

1. **`requestValueDialog` existiert** - Apple Dokumentation bestätigt dies für Siri/Shortcuts
2. **`ControlWidget` existiert** (iOS 18+) - Für Control Center Buttons
3. **`ControlWidgetButton` kann `AppIntent` triggern** - Dokumentiert

### Was unklar ist

1. **Zeigt iOS einen Dialog aus dem Control Center?** - Nicht dokumentiert
2. **Funktioniert `requestValueDialog` außerhalb von Siri?** - Unklar
3. **Wird die App gestartet um den Dialog zu zeigen?** - Möglich

### Mögliche Szenarien

| Szenario | Verhalten | Bewertung |
|----------|-----------|-----------|
| **Best Case** | Dialog erscheint im Control Center | Perfekt |
| **Akzeptabel** | System-Dialog erscheint (wie Siri) | Gut |
| **Worst Case** | App wird gestartet für Eingabe | Kein Vorteil |

---

## Affected Files (mit Änderungen)

| Datei | Typ | Beschreibung |
|-------|-----|--------------|
| `TimeBoxWidgets/QuickAddTaskIntent.swift` | CREATE | AppIntent mit @Parameter |
| `TimeBoxWidgets/QuickAddTaskControl.swift` | CREATE | ControlWidget mit Button |
| `TimeBoxWidgets/TimeBoxWidgetsBundle.swift` | CREATE | Widget Bundle |
| `project.pbxproj` | MODIFY | Widget Extension Target |
| `Resources/TimeBox.entitlements` | MODIFY | App Groups (optional) |

---

## Scope Assessment

- **Dateien:** 3 neue + 2 modifiziert
- **Geschätzte LoC:** +80 / -0
- **Risk Level:** LOW (Prototype, isoliert vom Haupt-Code)
- **iOS Minimum:** 18.0

---

## Technischer Ansatz

### 1. Minimaler Prototype

Nur das Nötigste implementieren um Gemini's Behauptung zu testen:

```
TimeBoxWidgets/
├── QuickAddTaskIntent.swift    # AppIntent mit requestValueDialog
├── QuickAddTaskControl.swift   # ControlWidget Button
└── TimeBoxWidgetsBundle.swift  # Bundle
```

### 2. Kein App Groups (zunächst)

Für den Prototype-Test brauchen wir keine Daten-Synchronisation mit der Haupt-App. Wir wollen nur sehen, ob der Dialog erscheint.

### 3. Manuelle Verifikation

- Build auf echtem Device
- Widget im Control Center hinzufügen
- Button tippen und beobachten was passiert

---

## Test-Strategie (PROTOTYPE)

### Warum keine automatisierten UI Tests möglich

1. **Control Center ist System-UI** - Nicht per XCTest erreichbar
2. **Simulator unterstützt keine Control Widgets** - Nur echtes Device
3. **Widget-Verhalten ist nicht testbar** - Apple erlaubt keinen programmatischen Zugriff

### Verifikation

| Check | Methode | Erwartung |
|-------|---------|-----------|
| Widget erscheint im Control Center | Manuell | Ja |
| Button ist tippbar | Manuell | Ja |
| Dialog erscheint bei Tap | Manuell | **Unbekannt** (Test-Ziel!) |
| Task wird erstellt | Console Log | Ja (wenn Dialog funktioniert) |

---

## Offene Fragen

- [x] Gibt es eine iOS 26 API für Control Center Input? → Gemini behauptet ja
- [ ] Funktioniert `requestValueDialog` von ControlWidget aus?
- [ ] Wird ein System-Dialog oder In-App-Dialog gezeigt?
- [ ] Ist dies dokumentiertes oder undokumentiertes Verhalten?

---

## Empfehlung

**Prototype erstellen und auf Device testen.**

- Aufwand: ~30 Minuten Code, ~15 Minuten Setup
- Risiko: Gering (isolierter Code)
- Lerneffekt: Hoch (klärt iOS 18+ Control Widget Capabilities)

Falls erfolgreich: Echtes Feature planen mit vollem TDD-Workflow.
Falls nicht erfolgreich: Dokumentieren und alternative Lösungen evaluieren.

---

## Nächster Schritt

`/write-spec` - Spezifikation für den Prototype erstellen
