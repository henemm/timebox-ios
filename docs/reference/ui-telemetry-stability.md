# UI Telemetry & Stability

Dieses Modul loest die haeufigsten Probleme bei UI Tests:
- Blindheit (keine Screenshots verfuegbar)
- Instabilitaet (Exit Code 64, Zombies)
- Spekulative Fixes ohne Analyse

---

## Accessibility First (STRIKTE REGELN)

### Beim Schreiben von SwiftUI Views

**1. JEDES interaktive Element MUSS einen `.accessibilityIdentifier()` haben:**

```swift
// RICHTIG
Button("Speichern") { ... }
    .accessibilityIdentifier("saveButton")

Toggle("Sync", isOn: $syncEnabled)
    .accessibilityIdentifier("syncToggle")

TextField("Name", text: $name)
    .accessibilityIdentifier("nameField")

// FALSCH - Fehlt Identifier!
Button("Speichern") { ... }
```

**2. Identifier auf LEAF-Elemente, NICHT auf Container:**

```swift
// FALSCH - Propagiert an alle Kinder!
VStack { ... }.accessibilityIdentifier("container")

// RICHTIG
VStack {
    Text("Title").accessibilityIdentifier("title")
    Text("Subtitle").accessibilityIdentifier("subtitle")
}
```

**3. Naming Convention:** `camelCase` mit Suffix fuer Typ:
- Buttons: `saveButton`, `addTaskButton`
- Toggles: `syncToggle`, `notificationsToggle`
- Fields: `nameField`, `emailField`
- Cells: `taskCell_\(id)`, `eventCell_\(id)`

### Beim Schreiben von UI Tests

**1. NIEMALS nach statischen Texten suchen:**

```swift
// FALSCH - Bricht bei Lokalisierung!
app.buttons["Save"]
app.staticTexts["Welcome"]

// RICHTIG - Identifier sind sprachunabhaengig
app.buttons["saveButton"]
app.staticTexts["welcomeLabel"]
```

**2. Immer `waitForExistence` verwenden:**

```swift
let button = app.buttons["saveButton"]
XCTAssertTrue(button.waitForExistence(timeout: 5))
button.tap()
```

---

## `/inspect-ui` Command

Da wir keine Screenshots sehen koennen, ist der Accessibility Tree unsere Telemetrie.

**Verwendung:**
```bash
/inspect-ui
```

**Was passiert:**
1. `DebugHierarchyTest.swift` wird ausgefuehrt
2. Gibt `app.debugDescription` aus
3. Strukturierte Zusammenfassung zeigt:
   - Alle sichtbaren Buttons mit Identifiern
   - Alle StaticTexts
   - Alle Toggles/Switches
   - Warnungen bei fehlenden Identifiern

**Spezifische Screens inspizieren:**
- `testPrintSettingsScreen` - Settings oeffnen
- `testPrintAddTaskSheet` - Add Task Sheet oeffnen
- `testPrintBacklogTab` - Backlog Tab

---

## ON_UI_TEST_FAILURE Hook

Dieser Hook erzwingt das Analysis-First Prinzip bei UI Test-Fehlern.

### Verhalten bei Exit Code 64

Exit Code 64 = Simulator/Syntax-Problem, **NICHT Code-Problem!**

Der Hook:
1. Warnt, dass dies kein Code-Problem ist
2. **BLOCKT** alle Code-Aenderungen in `/Sources/`
3. Fordert Simulator-Status-Pruefung

**Loesung:**
```bash
# Simulator pruefen
xcrun simctl list devices available | grep FocusBlox

# Falls Simulator haengt
killall "Simulator"
xcrun simctl shutdown all

# Falls UUID nicht mehr stimmt
xcrun simctl create "FocusBlox" "iPhone 16 Pro" "iOS26.2"
# → CLAUDE.md aktualisieren!
```

### Verhalten bei "Element not found"

Der Hook:
1. Erkennt "Element not found" Fehler
2. **BLOCKT** Code-Aenderungen bis Analyse erfolgt
3. Fordert `/inspect-ui` Ausfuehrung

**Warum:** "Element not found" hat viele moegliche Ursachen:
- Element existiert mit anderem Identifier
- Element ist verdeckt (nicht hittable)
- Falscher Screen aktiv
- Timing-Problem (Element noch nicht da)
- Mock nicht aktiv

Ohne den Accessibility Tree zu sehen, sind Fixes spekulativ!

### Analyse markieren

Sobald `/inspect-ui` oder `DebugHierarchyTest` ausgefuehrt wird, markiert der Hook die Analyse als erledigt und erlaubt Code-Aenderungen.

---

## Resilient Test Runner

Das Skript `scripts/run_resilient_tests.sh` loest haeufige Instabilitaets-Probleme.

### Features

1. **Simulator-Vorbereitung:**
   - Beendet Zombie-Prozesse
   - Bootet Simulator und wartet auf Bereitschaft
   - Erstellt Simulator neu falls UUID ungueltig

2. **Stabile Test-Ausfuehrung:**
   - `-parallel-testing-enabled NO` - Keine Race Conditions
   - `-retry-tests-on-failure` - Flaky Tests wiederholen
   - `-disable-concurrent-destination-testing` - Stabil

3. **Retry-Logik:**
   - Bei Exit 65 (Test-Failure): Retry bis zu 2x
   - Bei Exit 64 (Simulator): Kein Retry (sinnlos)

### Verwendung

```bash
# Alle UI Tests
./scripts/run_resilient_tests.sh

# Spezifische Test-Klasse
./scripts/run_resilient_tests.sh TaskDetailUITests

# Spezifischer Test
./scripts/run_resilient_tests.sh TaskDetailUITests/testEditTask
```

### Output

```
============================================
  FocusBlox Resilient Test Runner
============================================

[INFO] Phase 1: Simulator vorbereiten...
[INFO] Beende haengende Simulator-Prozesse...
[INFO] Boote Simulator...
[SUCCESS] Simulator bereit.

[INFO] Phase 2: Tests ausfuehren (Versuch 1/2)...
[SUCCESS] Alle Tests bestanden!

============================================
[SUCCESS] ALLE TESTS BESTANDEN
============================================
```

---

## Diagnose-Algorithmus

Bei fehlschlagendem UI Test in dieser Reihenfolge pruefen:

```
1. Exit Code pruefen
   ├─ Exit 64 → Simulator-Problem, NICHT Code
   ├─ Exit 65 → Echter Test-Failure
   └─ Exit 70 → Build-Fehler

2. Bei Exit 65: Fehler-Art identifizieren
   ├─ "Element not found" → /inspect-ui
   ├─ "Assertion failed" → Logik-Problem
   └─ "Crash/SIGABRT" → Logs pruefen

3. Bei "Element not found":
   a) /inspect-ui ausfuehren
   b) Pruefen ob Element existiert (mit anderem ID?)
   c) Pruefen ob Element hittable ist
   d) Pruefen ob richtiger Screen aktiv

4. Root Cause identifizieren
   └─ Erst dann gezielt fixen!
```

---

## Bestehende AccessibilityIdentifier

| Identifier | Element | Screen |
|------------|---------|--------|
| `addTaskButton` | Plus-Button | Heute/Backlog |
| `settingsButton` | Gear-Button | Toolbar |
| `viewModeSwitcher` | Menu-Button | Heute |
| `remindersSyncToggle` | Toggle | Settings |
| `loadingIndicator` | Spinner | Diverses |

**WICHTIG:** Bei neuen Views immer Identifier hinzufuegen!

---

Erstellt: 2026-01-25
