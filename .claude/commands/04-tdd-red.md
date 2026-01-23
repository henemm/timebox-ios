# Phase 5: TDD RED - Write Failing Tests

You are in **Phase 5 - TDD RED Phase**.

## Purpose

Write tests BEFORE implementation. Tests MUST FAIL because the functionality doesn't exist yet.

**If tests pass → you're not doing TDD, you're testing existing code.**

## ⛔ MANDATORY: UI TESTS REQUIRED

**EVERY feature and EVERY bug MUST have UI tests.**

This is NON-NEGOTIABLE. No implementation without UI tests that:
1. Are written FIRST (before any code changes)
2. FAIL when run (because feature doesn't exist yet)
3. Test the actual user interface elements
4. Have verified failure output captured

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

### 2. Write UI Tests FIRST

Create UI test file in `TimeBoxUITests/`:

```swift
// TimeBoxUITests/[FeatureName]UITests.swift

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

    /// Test: [User interaction] should [result]
    /// EXPECTED TO FAIL: Functionality not implemented
    func test[Interaction]Works() throws {
        // Test steps that WILL FAIL because feature doesn't exist
    }
}
```

### 3. Run UI Tests - MUST FAIL (RED)

```bash
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54' \
  -only-testing:TimeBoxUITests/[FeatureName]UITests \
  2>&1 | tee docs/artifacts/[workflow]/ui-test-red-output.txt
```

**EXPECTED:** Tests FAIL with clear error messages.

### 4. Capture REAL Artifacts

```bash
# Create artifacts directory
mkdir -p docs/artifacts/[workflow-name]

# Verify tests failed
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 5. Register UI Test Artifact

```bash
python3 -c "
import sys; sys.path.insert(0, '.claude/hooks')
from workflow_state_multi import add_test_artifact, load_state, save_state

state = load_state()
active = state['active_workflow']

# Add UI test artifact
add_test_artifact(active, {
    'type': 'ui_test_output',
    'path': 'docs/artifacts/[workflow]/ui-test-red-output.txt',
    'description': 'UI Test FAILED: [element] does not exist - XCTAssertTrue failed',
    'phase': 'phase5_tdd_red'
})

# SET THE MANDATORY FLAGS
state['workflows'][active]['ui_test_red_done'] = True
state['workflows'][active]['ui_test_red_result'] = 'failed: [describe what failed]'
save_state(state)
print('UI Test RED artifact registered with verified failure')
"
```

### 6. (Optional) Write Unit Tests

If business logic is involved, also write unit tests:

```bash
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54' \
  -only-testing:TimeBoxTests/[FeatureName]Tests \
  2>&1 | tee docs/artifacts/[workflow]/unit-test-red-output.txt
```

## RED Phase Checklist

Before proceeding to implementation:

- [ ] ⛔ UI tests written in `TimeBoxUITests/`
- [ ] ⛔ UI tests executed and FAILED
- [ ] ⛔ `ui_test_red_done: true` flag set
- [ ] ⛔ `ui_test_red_result` contains "failed"
- [ ] UI test artifact registered with failure description
- [ ] (Optional) Unit tests written and failed

## Next Step

After RED phase is complete:
> "TDD RED complete. UI tests written in `TimeBoxUITests/[Feature]UITests.swift`. All tests FAILED as expected. Ready for `/implement`."

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase6_implement
```

## Common Mistakes

❌ **Tests that pass** → You're not doing TDD
❌ **No UI tests** → Hook will block implementation
❌ **Retroactive artifacts** → Timestamps will be checked
❌ **Exemption files** → No longer accepted
❌ **Skip to implement** → `ui_test_red_done` flag check will block you

## Hook Enforcement

The `tdd_enforcement.py` hook now checks:
1. `ui_test_red_done: true` must be set
2. `ui_test_red_result` must contain "fail"
3. Artifact timestamps are validated
4. No retroactive artifacts allowed
