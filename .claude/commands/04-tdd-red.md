# Phase 5: TDD RED - Write Failing Tests

You are in **Phase 5 - TDD RED Phase**.

## Purpose

Write tests BEFORE implementation. Tests MUST FAIL because the functionality doesn't exist yet.

**If tests pass → you're not doing TDD, you're testing existing code.**

## ⛔ STOP — Verstehst du das Problem?

**Bevor du einen einzigen Test schreibst, beantworte diese Fragen:**

1. **Was genau ist das gewuenschte Verhalten?** (Nicht die Implementierung — das VERHALTEN.)
2. **Welche Eingaben fuehren zu welchen Ausgaben?** (Konkret, nicht abstrakt.)
3. **Fuer jeden geplanten Test: Welche EINE Zeile in der Implementierung muesste ich aendern, damit dieser Test fehlschlaegt?**

Wenn du Frage 3 nicht beantworten kannst → der Test ist wertlos. Schreib ihn nicht.

**Verbotene Tests:**
- `XCTAssertEqual(x, x)` — Tautologie
- `task.prop = 5; XCTAssertEqual(task.prop, 5)` — testet Swift-Assignment
- Tests die nur Swift-Defaults pruefen (nil, 0, false)
- Tests die keine echte Funktion aufrufen

## Prerequisites

- Spec approved (`phase4_approved`)
- Test plan defined in spec

Check status:
```bash
python3 .claude/hooks/workflow_state_multi.py status
```

## Your Tasks

### 1. Enter TDD RED Phase

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase5_tdd_red
```

### 2. Unit Tests schreiben — PFLICHT fuer Business-Logik

**Unit Tests sind PFLICHT wenn Business-Logik betroffen ist.**
Pure Functions MUESSEN Unit Tests haben.
Nur reine UI-Aenderungen (Farbe, Layout, Text) duerfen ohne Unit Tests auskommen.

Fuer jeden Test: Schreib als Kommentar dazu welche Zeile den Test brechen wuerde.

```swift
// FocusBloxTests/[FeatureName]Tests.swift

import XCTest
@testable import FocusBlox

final class [FeatureName]Tests: XCTestCase {

    /// Verhalten: [konkrete Beschreibung]
    /// Bricht wenn: [Datei:Zeile — was aendern]
    func test_[verhalten]() {
        // Arrange: konkreter Input
        // Act: ECHTE Funktion aufrufen
        // Assert: konkreter erwarteter Output
    }
}
```

Ausfuehren:
```bash
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
  -destination 'id=6364A54B-5048-4346-899E-FFB67E630D53' \
  -only-testing:FocusBloxTests/[FeatureName]Tests \
  2>&1 | tee docs/artifacts/[workflow]/unit-test-red-output.txt
```

### 3. UI Tests schreiben

**EVERY feature and EVERY bug MUST have UI tests.**

```swift
// FocusBloxUITests/[FeatureName]UITests.swift

import XCTest

final class [FeatureName]UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-data"]
        app.launch()
    }

    /// EXPECTED TO FAIL: Element doesn't exist yet
    func test[Element]Exists() throws {
        let element = app.buttons["expectedButtonName"]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Element should exist")
    }
}
```

Ausfuehren:
```bash
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
  -destination 'id=6364A54B-5048-4346-899E-FFB67E630D53' \
  -only-testing:FocusBloxUITests/[FeatureName]UITests \
  2>&1 | tee docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 4. Alle Tests ausfuehren — MUESSEN FEHLSCHLAGEN (RED)

**EXPECTED:** Alle Tests FAIL mit klaren Fehlermeldungen.

```bash
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/unit-test-red-output.txt
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 5. RED-Artefakte registrieren

```bash
python3 -c "
import sys; sys.path.insert(0, '.claude/hooks')
from workflow_state_multi import add_test_artifact, load_state, save_state

state = load_state()
active = state['active_workflow']

# Unit test artifact
add_test_artifact(active, {
    'type': 'test_output',
    'path': 'docs/artifacts/[workflow]/unit-test-red-output.txt',
    'description': 'Unit Test FAILED: [describe what failed]',
    'phase': 'phase5_tdd_red'
})

# UI test artifact
add_test_artifact(active, {
    'type': 'ui_test_output',
    'path': 'docs/artifacts/[workflow]/ui-test-red-output.txt',
    'description': 'UI Test FAILED: [describe what failed]',
    'phase': 'phase5_tdd_red'
})

# SET THE MANDATORY FLAGS
state['workflows'][active]['red_test_done'] = True
state['workflows'][active]['red_test_result'] = 'failed: [describe what failed]'
state['workflows'][active]['ui_test_red_done'] = True
state['workflows'][active]['ui_test_red_result'] = 'failed: [describe what failed]'
save_state(state)
print('RED artifacts registered with verified failure')
"
```

## RED Phase Checklist

- [ ] Ich kann fuer JEDEN Test sagen welche Zeile ihn brechen wuerde
- [ ] Unit Tests geschrieben — PFLICHT bei Business-Logik
- [ ] Unit Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] UI Tests geschrieben in `FocusBloxUITests/`
- [ ] UI Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] `ui_test_red_done: true` gesetzt
- [ ] Alle Artefakte registriert

## Next Step

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase6_implement
```

## Common Mistakes

❌ **Test schreiben ohne das Problem verstanden zu haben** → STOP, zurueck zu Frage 1-3
❌ **Tautologie-Tests** (`x == x`, Property-Assignment) → Test ist wertlos
❌ **Tests that pass** → You're not doing TDD
❌ **No UI tests** → Hook will block implementation
❌ **Unit Tests "optional"** → PFLICHT bei Business-Logik
