# Analyse: ControlWidget mit requestValueDialog

**Datum:** 2026-01-22
**iOS Version:** 26.2 (Beta)
**Xcode Version:** 17C52
**Device:** iPhone 16 Pro

---

## Geminis Behauptung

> Mit `@Parameter` und `requestValueDialog` in einem `AppIntent`, der von einem `ControlWidgetButton` ausgelöst wird, öffnet iOS ein Eingabefeld **direkt aus dem Control Center**, ohne die App zu starten.

**Behaupteter Code:**
```swift
@Parameter(
    title: "Task-Titel",
    requestValueDialog: IntentDialog("Was gibt es zu tun?")
)
var taskTitle: String
```

---

## Unsere MVP-Testreihe

### Test 1: Intent im Framework (TimeBoxCore)

**Setup:**
- `QuickAddTaskIntent` in separatem Framework `TimeBoxCore`
- Framework eingebettet in App und Widget Extension
- Intent mit `@Parameter` und `requestValueDialog`

**Ergebnis:**
- Button reagiert kurz, springt zurück
- `perform()` wird NICHT aufgerufen
- Kein Sound, kein Log, kein Dialog

**Fazit:** Intent im Framework funktioniert nicht für ControlWidgets.

---

### Test 2: Simpelster Intent direkt in Widget Extension (OHNE Parameter)

**Setup:**
```swift
struct SimpleIntent: AppIntent {
    static var title: LocalizedStringResource = "Test"

    func perform() async throws -> some IntentResult {
        AudioServicesPlaySystemSound(1104)  // Tock
        return .result()
    }
}
```

**Ergebnis:**
- **TOCK-SOUND HÖRBAR**
- `perform()` wird aufgerufen

**Fazit:** Intent direkt in der Extension funktioniert.

---

### Test 3: Intent mit @Parameter (requestValueDialog)

**Setup:**
```swift
struct SimpleIntent: AppIntent {
    static var title: LocalizedStringResource = "Test"

    @Parameter(title: "Task", requestValueDialog: "Was tun?")
    var taskName: String

    func perform() async throws -> some IntentResult {
        AudioServicesPlaySystemSound(1104)
        return .result()
    }
}
```

**Ergebnis:**
- Kein Dialog erscheint
- Kein Sound
- `perform()` wird NICHT aufgerufen

**Fazit:** `@Parameter` mit `requestValueDialog` blockiert den Intent komplett.

---

## Zusammenfassung der Ergebnisse

| Test | Intent-Ort | Parameter | perform() aufgerufen? | Dialog? |
|------|-----------|-----------|----------------------|---------|
| 1 | Framework | mit @Parameter | NEIN | NEIN |
| 2 | Extension direkt | ohne Parameter | **JA** | - |
| 3 | Extension direkt | mit @Parameter | NEIN | NEIN |

---

## Schlussfolgerung

**Geminis Behauptung ist FALSCH.**

`requestValueDialog` funktioniert **NICHT** für ControlWidgets im Control Center. Das Feature ist offenbar nur für:
- Siri Shortcuts
- Spotlight-Aktionen
- Andere Kontexte, in denen iOS einen Dialog anzeigen kann

Das Control Center hat keine UI-Kapazität für Eingabe-Dialoge. Wenn ein `@Parameter` ohne Default-Wert vorhanden ist, kann der Intent nicht ausgeführt werden, weil iOS keinen Weg hat, den Wert abzufragen.

---

## Bewiesene Fakten

1. **ControlWidgets funktionieren** - der Button reagiert und kann Intents ausführen
2. **Intents müssen direkt in der Extension sein** - nicht in einem Framework
3. **Intents ohne Parameter funktionieren** - `perform()` wird aufgerufen
4. **Intents MIT `@Parameter` + `requestValueDialog` funktionieren NICHT** - der Intent wird blockiert

---

## Alternative Lösungen

1. **App öffnen:** Intent mit `openAppWhenRun = true`, App zeigt dann Eingabefeld
2. **Siri Shortcut:** Dort funktioniert `requestValueDialog` erwartungsgemäß
3. **Vordefinierte Aktion:** Button ohne Parameter, der eine feste Aktion ausführt

---

## Testumgebung

- **Device:** iPhone 16 Pro (physisch, kein Simulator)
- **iOS:** 26.2 Beta
- **Xcode:** 17C52
- **Projekt:** TimeBox mit TimeBoxWidgetsExtension
- **Test-Methode:** Sound-Feedback (AudioServicesPlaySystemSound) und Logger.fault()
