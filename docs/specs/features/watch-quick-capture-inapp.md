---
entity_id: watch-quick-capture-inapp
type: feature
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [watchos, quick-capture, ux-simplification]
---

# Watch Quick Capture — In-App Flow vereinfachen

## Approval

- [ ] Approved

## Purpose

Den Watch-Task-Erfassungsflow von 5 Schritten (Button, Sheet, Diktat, OK, Bestaetigung) auf 2 reduzieren: App oeffnen → sofort Diktat → Auto-Save mit Haptik. Basiert auf User Story `docs/project/stories/watch-quick-capture.md`.

## User Story

**When** ich unterwegs bin und mir ein Gedanke einfaellt,
**I want to** ihn blitzschnell per Sprache festhalten (App oeffnen → sprechen → fertig),
**So that** der Gedanke nicht verloren geht, ohne dass ich mehrfach tippen muss.

## Anforderungen

### Funktional

1. **Auto-Open:** VoiceInputSheet oeffnet sich automatisch beim App-Start (kein Button-Tap noetig)
2. **Auto-Diktat:** TextField ist sofort fokussiert → watchOS Diktat-Keyboard startet automatisch
3. **Text-Preview:** Nach Spracheingabe wird der erkannte Text ~1.5s angezeigt
4. **Abbruch-Option:** Waehrend der Preview kann der User "Abbrechen" tippen (bei Quatsch-Erkennung)
5. **Auto-Save:** Nach 1.5s ohne Abbruch wird der Task automatisch gespeichert
6. **Haptik-Feedback:** `WKInterfaceDevice.current().play(.success)` nach dem Speichern
7. **Auto-Dismiss:** VoiceInputSheet schliesst sich nach Save + Haptik automatisch
8. **Kein Bestaetigungs-Screen:** ConfirmationView entfaellt komplett
9. **Manueller Button bleibt:** "Task hinzufuegen"-Button in der Liste bleibt fuer weiteres Erfassen nach dem ersten Auto-Open

### Nicht-Funktional

- Max 1 Tap (App oeffnen) + Spracheingabe bis Task gespeichert
- Gesamte aktive Interaktionszeit: unter 3 Sekunden
- Offline-faehig (CloudKit synct spaeter)

## Source

### Zu aendernde Dateien

| Datei | Aenderung | Beschreibung |
|-------|-----------|-------------|
| `FocusBloxWatch Watch App/ContentView.swift` | MODIFY | Auto-Open Sheet bei onAppear, ConfirmationView-References entfernen |
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | MODIFY | Auto-Save Timer nach Texteingabe, Haptik, OK-Button entfernen |
| `FocusBloxWatch Watch App/ConfirmationView.swift` | DELETE | Wird nicht mehr benoetigt |
| `FocusBloxWatch Watch AppUITests/FocusBloxWatch_Watch_AppUITests.swift` | MODIFY | Tests fuer neuen Flow |

### Nicht zu aendern

| Datei | Grund |
|-------|-------|
| `WatchLocalTask.swift` | Schema unveraendert |
| `WatchTaskMetadata.swift` | Schema unveraendert |
| `FocusBloxWatchApp.swift` | ModelContainer bereits korrekt |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `WatchLocalTask` | Model | Task-Objekt das gespeichert wird |
| `WKInterfaceDevice` | Framework | Haptik-Feedback (.success) |
| `ConfirmationView.swift` | DELETE | Wird entfernt |

## Implementation Details

### 1. ContentView.swift — Auto-Open + Cleanup

**Entfernen:**
- `showingConfirmation` State
- `pendingConfirmation` State
- `.sheet(isPresented: $showingConfirmation)` (ConfirmationView)
- `onDismiss`-Handler der VoiceInputSheet

**Hinzufuegen:**
- `@State private var hasAutoOpened = false` — verhindert wiederholtes Auto-Open
- `.onAppear { if !hasAutoOpened { showingInput = true; hasAutoOpened = true } }` — oeffnet Sheet einmalig beim App-Start

**Ergebnis:** ContentView zeigt weiterhin die Task-Liste mit "Task hinzufuegen"-Button. Beim ersten Oeffnen der App startet automatisch das VoiceInputSheet.

### 2. VoiceInputSheet.swift — Auto-Save Flow

**Entfernen:**
- OK-Button (ToolbarItem confirmationAction)
- `onSave` Callback-Parameter

**Hinzufuegen:**
- `@Environment(\.modelContext) private var modelContext` — direkter Zugriff fuer Save
- `@State private var showingPreview = false` — wechselt von Eingabe- zu Preview-Modus
- `@State private var autoSaveTimer: Timer?` — 1.5s Countdown
- Auto-Save-Logik: Wenn TextField sich aendert und nicht leer ist → Preview starten → Timer 1.5s → Save + Haptik + Dismiss

**Flow:**
```
onAppear → isFocused = true (Diktat startet)
    ↓
User spricht → taskTitle wird gefuellt
    ↓
onChange(taskTitle) → wenn nicht leer nach Trimming:
    showingPreview = true
    autoSaveTimer starten (1.5s)
    ↓
Timer feuert → saveTask() + Haptik + dismiss()
    ODER
User tippt "Abbrechen" → Timer cancel + dismiss()
```

**Wichtig:** Der Timer muss bei jeder Texteingabe-Aenderung zurueckgesetzt werden (falls User weiter diktiert). Erst wenn sich der Text 1.5s nicht mehr aendert, wird gespeichert.

### 3. ConfirmationView.swift — Loeschen

Datei komplett entfernen. Haptik-Feedback wird direkt in VoiceInputSheet ausgefuehrt.

## Expected Behavior

### Happy Path
1. User oeffnet Watch-App
2. VoiceInputSheet erscheint sofort
3. Diktat-Keyboard startet automatisch
4. User spricht "Milch kaufen"
5. Text "Milch kaufen" wird 1.5s angezeigt (Preview)
6. Auto-Save: Task wird gespeichert, Haptik vibriert
7. Sheet schliesst sich, User sieht ContentView mit "Milch kaufen" in der Liste

### Abbruch-Path
1. User oeffnet Watch-App
2. VoiceInputSheet erscheint sofort
3. User spricht, Erkennung ist Quatsch
4. User tippt "Abbrechen" waehrend Preview
5. Timer wird abgebrochen, kein Task gespeichert
6. Sheet schliesst sich, User kann erneut "Task hinzufuegen" tippen

### Weitere Tasks nach Auto-Open
1. Nach dem ersten Auto-Open + Save sieht User die Task-Liste
2. "Task hinzufuegen" Button kann fuer weitere Tasks getippt werden
3. Gleicher Flow: Diktat → Preview → Auto-Save → Haptik

## Scope

- **Dateien:** 3 MODIFY + 1 DELETE = 4
- **LoC netto:** ~+60/-80 (Netto-Reduktion)
- **Komplexitaet:** S (1 Session)
- **Risiko:** LOW — isolierte Watch-App, keine Shared-Code-Aenderungen

## Tests

### UI Tests (TDD RED — vor Implementation)

```swift
// Test 1: VoiceInputSheet oeffnet sich automatisch beim App-Start
func test_appLaunch_autoDiktatOpens() {
    let app = XCUIApplication()
    app.launch()
    // VoiceInputSheet sollte automatisch erscheinen (TextField sichtbar)
    XCTAssertTrue(app.textFields["taskTitleField"].waitForExistence(timeout: 5))
}

// Test 2: Kein OK-Button mehr vorhanden
func test_voiceInputSheet_noOKButton() {
    let app = XCUIApplication()
    app.launch()
    _ = app.textFields["taskTitleField"].waitForExistence(timeout: 5)
    XCTAssertFalse(app.buttons["saveButton"].exists)
}

// Test 3: Abbrechen-Button existiert noch
func test_voiceInputSheet_cancelButtonExists() {
    let app = XCUIApplication()
    app.launch()
    _ = app.textFields["taskTitleField"].waitForExistence(timeout: 5)
    XCTAssertTrue(app.buttons["cancelButton"].exists)
}

// Test 4: Abbrechen schliesst das Sheet
func test_voiceInputSheet_cancelDismissesSheet() {
    let app = XCUIApplication()
    app.launch()
    _ = app.textFields["taskTitleField"].waitForExistence(timeout: 5)
    app.buttons["cancelButton"].tap()
    // Zurueck auf ContentView — addTaskButton sichtbar
    XCTAssertTrue(app.buttons["addTaskButton"].waitForExistence(timeout: 5))
}

// Test 5: Manueller Button oeffnet Sheet erneut
func test_addTaskButton_reopensInputSheet() {
    let app = XCUIApplication()
    app.launch()
    _ = app.textFields["taskTitleField"].waitForExistence(timeout: 5)
    app.buttons["cancelButton"].tap()
    _ = app.buttons["addTaskButton"].waitForExistence(timeout: 5)
    app.buttons["addTaskButton"].tap()
    XCTAssertTrue(app.textFields["taskTitleField"].waitForExistence(timeout: 5))
}

// Test 6: Kein Bestaetigungs-Screen nach Texteingabe + Warten
func test_afterSave_noConfirmationScreen() {
    let app = XCUIApplication()
    app.launch()
    let textField = app.textFields["taskTitleField"]
    _ = textField.waitForExistence(timeout: 5)
    textField.tap()
    textField.typeText("Test Task")
    // Warten auf Auto-Save (1.5s + Puffer)
    sleep(3)
    // Kein Bestaetigungs-Screen
    XCTAssertFalse(app.staticTexts["Task gespeichert"].exists)
}
```

## Known Limitations

- watchOS Simulator unterstuetzt keine Dictation — nur manuelles Tippen testbar
- Auto-Save Timer basiert auf Textaenderungs-Pause (1.5s) — bei langsamem Diktieren koennte der Timer zu frueh feuern
- `hasAutoOpened` State geht verloren wenn App aus dem Speicher entfernt wird (gewuenscht: naechster Start = wieder Auto-Open)

## Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Timer feuert waehrend User noch diktiert | Mittel | Mittel | Timer-Reset bei jeder Textaenderung |
| Leerer Text wird gespeichert | Niedrig | Niedrig | Trim + isEmpty-Check vor Save |
| Auto-Open nervt bei App-Wechsel | Niedrig | Niedrig | `hasAutoOpened` Flag verhindert Wiederholung |

## Changelog

- 2026-03-04: Initial spec created (v1.0)
