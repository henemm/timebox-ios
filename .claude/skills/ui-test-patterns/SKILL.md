---
name: ui-test-patterns
description: XCUITest Best Practices fuer Xcode 26.2. Claude laedt diesen Skill automatisch beim Schreiben oder Debuggen von UI Tests.
user-invocable: false
disable-model-invocation: false
---

# XCUITest Best Practices (Xcode 26.2 / Swift 26)

## Neue APIs in Xcode 26.2

### waitForNonExistence (NEU)
```swift
// Warten bis Element VERSCHWINDET (z.B. Loading-Spinner)
let spinner = app.activityIndicators["loadingSpinner"]
XCTAssertTrue(spinner.waitForNonExistence(withTimeout: 10))
```

### wait(for:toEqual:timeout:) (NEU)
```swift
// Warten auf Property-Aenderung
let toggle = app.switches["myToggle"]
XCTAssertTrue(toggle.wait(for: \.value as? String, toEqual: "1", timeout: 5))
```

### ACHTUNG: Naming-Inkonsistenz
- Alte API: `waitForExistence(timeout:)`
- Neue API: `waitForNonExistence(withTimeout:)` - MIT "with"!

---

## Element-Lokalisierung

### 1. AccessibilityIdentifier (BESTE METHODE)

```swift
// Im SwiftUI View:
Button("Speichern") { ... }
    .accessibilityIdentifier("saveButton")

// Im Test:
let saveButton = app.buttons["saveButton"]
XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
```

**WARNUNG: Container-Propagation Bug**
```swift
// FALSCH - Identifier wird an ALLE Kinder propagiert:
VStack {
    Text("Title")
    Text("Subtitle")
}
.accessibilityIdentifier("container") // ALLE Texte haben jetzt "container"!

// RICHTIG - Identifier nur auf Leaf-Elemente:
VStack {
    Text("Title").accessibilityIdentifier("title")
    Text("Subtitle").accessibilityIdentifier("subtitle")
}
```

### 2. Label-basierte Suche (FALLBACK)

```swift
// Wenn kein Identifier vorhanden:
let button = app.buttons["Speichern"]
let text = app.staticTexts["Willkommen"]
```

**PROBLEM:** Bricht bei Lokalisierung!

### 3. Predicate-Suche (KOMPLEX)

```swift
// Fuer dynamische Labels:
let durationBadge = app.staticTexts.matching(
    NSPredicate(format: "label MATCHES %@", "\\d+m")
).firstMatch
```

---

## Haeufige Fehler und Fixes

### 1. Picker-Labels sind NICHT als StaticText zugaenglich

**SYMPTOM:** `app.staticTexts["OptionName"]` findet nichts

**LOESUNG:**
```swift
// Picker als Button antappen:
let picker = app.buttons["priorityPicker"]
picker.tap()

// Optionen erscheinen als Buttons im Popup:
let option = app.buttons["Hoch"]
option.tap()
```

### 2. Sheet-Animation nicht abgewartet

**SYMPTOM:** Element existiert nicht direkt nach `.tap()`

**LOESUNG:**
```swift
addButton.tap()

// NIEMALS sleep() verwenden! Stattdessen:
let sheet = app.navigationBars["Neuer Task"]
XCTAssertTrue(sheet.waitForExistence(timeout: 3))
```

### 3. Scrolling bevor Element sichtbar

**SYMPTOM:** Element existiert, ist aber nicht hittable

**LOESUNG:**
```swift
let element = app.buttons["hiddenButton"]

// Scroll bis sichtbar:
while !element.isHittable {
    app.swipeUp()
}
element.tap()
```

### 4. Mock-Daten erscheinen nicht

**SYMPTOM:** Test sieht echte Daten statt Mocks

**URSACHEN & FIXES:**

```swift
// 1. Launch-Argument vergessen:
app.launchArguments = ["-UITesting"]
app.launch()

// 2. EnvironmentKey hat echten Default:
// FALSCH:
private struct ServiceKey: EnvironmentKey {
    static let defaultValue: Service = RealService() // PROBLEM!
}

// RICHTIG:
private struct ServiceKey: EnvironmentKey {
    static let defaultValue: Service = {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            return MockService()
        }
        return RealService()
    }()
}

// 3. Environment nicht propagiert:
// FALSCH - nur auf Parent:
NavigationStack {
    ChildView()
}
.environment(\.service, mockService)

// Funktioniert meist, aber bei Sheets/Alerts pruefen!
```

### 5. Async Loading Race Condition

**SYMPTOM:** Daten manchmal da, manchmal nicht

**LOESUNG:**
```swift
// View muss Loading-State zeigen:
if isLoading {
    ProgressView().accessibilityIdentifier("loadingIndicator")
} else {
    content
}

// Test wartet auf Loading-Ende:
let loading = app.activityIndicators["loadingIndicator"]
if loading.exists {
    XCTAssertTrue(loading.waitForNonExistence(withTimeout: 10))
}

// Dann auf Content warten:
let content = app.staticTexts["expectedContent"]
XCTAssertTrue(content.waitForExistence(timeout: 5))
```

### 6. Toggle-Wert pruefen

**SYMPTOM:** Toggle-Value ist "0" oder "1", nicht Bool

**LOESUNG:**
```swift
let toggle = app.switches["myToggle"]

// Wert pruefen:
let isOn = (toggle.value as? String) == "1"
XCTAssertTrue(isOn)

// Oder mit neuer API:
XCTAssertTrue(toggle.wait(for: \.value as? String, toEqual: "1", timeout: 3))
```

---

## Test-Setup Pattern

```swift
final class MyFeatureUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",           // Aktiviert Mock-Mode
            "-ResetUserDefaults"    // Frischer State pro Test
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
}
```

---

## Helper-Methoden Pattern

```swift
extension XCTestCase {

    /// Wartet auf Element und tappt es
    func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        element.tap()
    }

    /// Navigiert zu einem Tab
    func navigateToTab(_ tabName: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[tabName]
        tapWhenReady(tab)
    }

    /// Wartet bis Loading abgeschlossen
    func waitForLoadingToComplete(in app: XCUIApplication, timeout: TimeInterval = 10) {
        let loading = app.activityIndicators["loadingIndicator"]
        if loading.exists {
            XCTAssertTrue(loading.waitForNonExistence(withTimeout: timeout))
        }
    }

    /// Debug: Alle sichtbaren Elemente ausgeben
    func debugVisibleElements(in app: XCUIApplication) {
        print("=== DEBUG: Visible Elements ===")
        print("StaticTexts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        print("Buttons: \(app.buttons.allElementsBoundByIndex.map { $0.identifier.isEmpty ? $0.label : $0.identifier })")
        print("Cells: \(app.cells.allElementsBoundByIndex.map { $0.identifier })")
        print("================================")
    }
}
```

---

## xcodebuild Exit Codes (ZUERST PRUEFEN!)

| Code | Name | Bedeutung | Aktion |
|------|------|-----------|--------|
| **0** | OK | Erfolg | Tests bestanden |
| **64** | EX_USAGE | Falsche Kommando-Syntax | Destination/Scheme validieren |
| **65** | EX_DATAERR | Daten-Fehler | Kompilierung/Assertions pruefen |
| **66** | EX_NOINPUT | Datei fehlt | Projekt-Pfad pruefen |
| **70** | EX_SOFTWARE | Software-Fehler | Build-Fehler im Code |

### Exit Code 64 Quick-Fix

```bash
# 1. Simulator-UUID pruefen:
xcrun simctl list devices available | grep -E "iPhone|FocusBlox"

# 2. Scheme pruefen:
xcodebuild -list -project FocusBlox.xcodeproj

# 3. Falls Simulator fehlt - neu erstellen:
xcrun simctl create "FocusBlox" "iPhone 16 Pro" "iOS26.2"
```

---

## Diagnose-Algorithmus: UI Test schlaegt fehl

Bei fehlschlagendem UI Test in dieser Reihenfolge pruefen:

**0. Exit Code pruefen** → Exit 64 = Syntax-Problem, nicht Test-Problem!

1. **Launch-Argument pruefen** → `app.launchArguments` muss `-UITesting` enthalten
2. **Wait statt direkter Zugriff** → `waitForExistence(timeout:)` verwenden
3. **Element-Typ pruefen** → Button? StaticText? Cell? (Picker sind Buttons!)
4. **Container-Propagation** → Identifier auf Leaf-Element, nicht Container
5. **Animation abwarten** → Nach Sheet/Navigation auf NavBar warten
6. **EnvironmentKey pruefen** → Default darf nicht RealService sein
7. **Sichtbarkeit** → `isHittable` pruefen, ggf. scrollen

**Debug-Output einfuegen:**
```swift
print("DEBUG: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
print("DEBUG: \(app.buttons.allElementsBoundByIndex.map { $0.identifier.isEmpty ? $0.label : $0.identifier })")
```

---

## Projekt-spezifisch: FocusBlox

**Simulator vorbereiten (verhindert Exit 64!):**
```bash
killall "Simulator" 2>/dev/null
xcrun simctl shutdown all 2>/dev/null
xcrun simctl boot 877731AF-6250-4E23-A07E-80270C69D827 2>/dev/null
xcrun simctl bootstatus 877731AF-6250-4E23-A07E-80270C69D827 -b
```

**Stabile Test-Ausfuehrung:**
```bash
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
  -destination 'id=877731AF-6250-4E23-A07E-80270C69D827' \
  -only-testing:FocusBloxUITests/[TestClass]/[testMethod] \
  -parallel-testing-enabled NO \
  -disable-concurrent-destination-testing \
  -retry-tests-on-failure \
  -quiet
```

**Flags erklaert:**
| Flag | Zweck |
|------|-------|
| `-parallel-testing-enabled NO` | Tests nacheinander, stabiler |
| `-disable-concurrent-destination-testing` | Keine Race Conditions |
| `-retry-tests-on-failure` | Flaky Tests automatisch wiederholen |
| `-quiet` | Weniger Build-Noise |

**Bestehende AccessibilityIdentifier:**
- `addTaskButton` - Plus-Button fuer neuen Task
- `settingsButton` - Settings-Button in Toolbar
- `viewModeSwitcher` - ViewMode Menu-Button
- `remindersSyncToggle` - Toggle in Settings
- `loadingIndicator` - Loading-Spinner

---

Aktualisiert: 2026-01-25
