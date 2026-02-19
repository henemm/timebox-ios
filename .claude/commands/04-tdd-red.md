# Phase 5: TDD RED - Write Failing Tests

You are in **Phase 5 - TDD RED Phase**.

## Purpose

Write tests BEFORE implementation. Tests MUST FAIL because the functionality doesn't exist yet.

**If tests pass → you're not doing TDD, you're testing existing code.**

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

### 2. Behavior Inventory erstellen

**VOR dem Schreiben eines einzigen Tests:** Verstehe WAS du testest.

Erstelle `docs/artifacts/[workflow]/behavior-inventory.md`.

**Fuer Features** — 2 Agenten PARALLEL:

| Agent | Aufgabe |
|-------|---------|
| **Behavior-Agent** (Explore) | Lies `affected_files` aus der Spec. Fuer jede Datei: Finde alle public/internal Funktionen. Liste pro Funktion die konkreten Verhaltensweisen (Input → Output). Mindestens 2 Behaviors pro Pure Function (Normalfall + Grenzfall). |
| **Mutations-Agent** (Explore) | Fuer jedes Behavior aus Agent 1: Beschreibe eine konkrete Code-Aenderung (Datei + Zeile + alter Wert → neuer Wert) die den Test brechen wuerde. Wenn keine Mutation benennbar → Behavior STREICHEN. |

**Fuer Bugs** — 1 Agent (Inventory aus Analyse ableiten):

| Agent | Aufgabe |
|-------|---------|
| **Regression-Agent** (Explore) | Lies `docs/artifacts/[workflow]/analysis.md`. Extrahiere Root Cause als primaeres Behavior. Designe Regressions-Test: Input der den Bug ausloest → korrektes erwartetes Ergebnis. Mutation = die Buggy-Zeile selbst. |

**Format des Inventory:**

```markdown
# Behavior Inventory: [workflow-name]

## Unit: [Funktionsname]
**Datei:** `Sources/Services/ExampleService.swift:38`
**Typ:** Pure Function | Stateful | Side-Effect

| # | Verhalten | Input | Erwartet | Mutation (was bricht den Test) |
|---|-----------|-------|----------|-------------------------------|
| 1 | Beschreibung | Konkreter Input | Konkreter Output | Datei:Zeile — `alter Code` → `neuer Code` |
| 2 | Grenzfall | Konkreter Input | Konkreter Output | Datei:Zeile — `alter Code` → `neuer Code` |

## Tautologie-Checkliste
- [ ] Kein Test assertiert `x == x`
- [ ] Kein Test prueft nur Swift-Defaults (nil, 0, false)
- [ ] Kein Test prueft nur Property-Assignment (`task.x = 5; assert task.x == 5`)
- [ ] Jeder Test ruft die ECHTE Funktion/Methode auf
- [ ] Jeder Test hat eine benennbare Mutation
```

### 3. Inventory validieren + registrieren

Pruefe das Inventory:
1. Jede public Funktion in `affected_files` hat mindestens 1 Behavior
2. Jedes Behavior hat konkreten Input UND konkreten Output
3. Jedes Behavior hat eine Mutation mit Datei + Zeile
4. Tautologie-Checkliste ist abgehakt (alle Checkboxen `[x]`)

Registriere im Workflow:

```bash
python3 -c "
import sys; sys.path.insert(0, '.claude/hooks')
from workflow_state_multi import load_state, save_state

state = load_state()
active = state['active_workflow']
state['workflows'][active]['behavior_inventory_done'] = True
state['workflows'][active]['behavior_inventory_path'] = 'docs/artifacts/[workflow]/behavior-inventory.md'
save_state(state)
print('Behavior Inventory registriert')
"
```

### 4. Unit Tests schreiben — PFLICHT fuer Business-Logik

**Unit Tests sind PFLICHT wenn Business-Logik betroffen ist.**
Pure Functions (deterministisch, keine Side Effects) MUESSEN Unit Tests haben.
Nur reine UI-Aenderungen (Farbe, Layout, Text) duerfen ohne Unit Tests auskommen.

Schreibe Unit Tests **basierend auf dem Behavior Inventory** — NICHT frei erfunden!
Jeder Test MUSS einem Behavior aus dem Inventory entsprechen.

```swift
// FocusBloxTests/[FeatureName]Tests.swift

import XCTest
@testable import FocusBlox

final class [FeatureName]Tests: XCTestCase {

    /// Behavior #1 aus Inventory: [Beschreibung]
    /// Mutation: [Datei:Zeile — was bricht den Test]
    func test_[verhalten]() {
        // Arrange: Input aus Inventory
        // Act: ECHTE Funktion aufrufen
        // Assert: Erwarteter Output aus Inventory
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

### 5. UI Tests schreiben

**EVERY feature and EVERY bug MUST have UI tests.**

Create UI test file in `FocusBloxUITests/`:

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

    /// Test: [Feature element] should exist
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

### 6. Alle Tests ausfuehren — MUESSEN FEHLSCHLAGEN (RED)

**EXPECTED:** Alle Tests FAIL mit klaren Fehlermeldungen.

Verifiziere:
```bash
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/unit-test-red-output.txt
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 7. RED-Artefakte registrieren

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

Before proceeding to implementation:

- [ ] Behavior Inventory erstellt (`behavior-inventory.md`)
- [ ] Jedes Behavior hat Mutation mit Datei + Zeile
- [ ] Tautologie-Checkliste abgehakt
- [ ] `behavior_inventory_done: true` gesetzt
- [ ] Unit Tests geschrieben (basierend auf Inventory) — PFLICHT bei Business-Logik
- [ ] Unit Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] ⛔ UI Tests geschrieben in `FocusBloxUITests/`
- [ ] ⛔ UI Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] ⛔ `ui_test_red_done: true` Flag gesetzt
- [ ] ⛔ `ui_test_red_result` enthaelt "failed"
- [ ] Alle Artefakte registriert

## Next Step

After RED phase is complete:
> "TDD RED complete. Behavior Inventory + Tests written. All tests FAILED as expected. Ready for `/implement`."

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase6_implement
```

## Common Mistakes

❌ **Tests ohne Behavior Inventory** → Hook blockiert Implementation
❌ **Tautologie-Tests** (`x == x`, Property-Assignment) → Inventory erzwingt echte Behaviors
❌ **Tests that pass** → You're not doing TDD
❌ **No UI tests** → Hook will block implementation
❌ **Retroactive artifacts** → Timestamps will be checked
❌ **Unit Tests "optional"** → PFLICHT bei Business-Logik
❌ **Tests ohne benennbare Mutation** → Test ist wertlos, streichen

## Hook Enforcement

The `tdd_enforcement.py` hook checks:
1. `behavior_inventory_done: true` must be set
2. `behavior_inventory_path` must point to existing file with Mutations-Spalte
3. `ui_test_red_done: true` must be set
4. `ui_test_red_result` must contain "fail"
5. Unit + UI test artifacts must exist
6. Artifact timestamps are validated
