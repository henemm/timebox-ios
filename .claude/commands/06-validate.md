# Phase 7: Validation

You are starting the **Validation Phase**.

## ⛔ CRITICAL: ALL TESTS MUST PASS

**Before validation can succeed:**
1. ALL Unit Tests must PASS
2. ALL UI Tests must PASS
3. NO manual testing requests allowed

```bash
# Run ALL tests
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54' \
  2>&1 | tee docs/artifacts/[workflow]/validation-test-output.txt

# Check results
grep -E "(passed|failed)" docs/artifacts/[workflow]/validation-test-output.txt
```

**If ANY test fails:**
1. DO NOT proceed to validation
2. GO BACK and FIX THE CODE
3. Re-run tests until ALL PASS
4. **NEVER ask user to test manually**

## Prerequisites

Check workflow state:
```bash
python3 .claude/hooks/workflow_state_multi.py status
```

Required:
- `current_phase`: `phase6_implement` or later
- `ui_test_red_done`: `true`
- `ui_test_red_result`: contains "failed"

## Validation Checklist

- [ ] ⛔ ALL Unit Tests PASS (green)
- [ ] ⛔ ALL UI Tests PASS (green)
- [ ] Build compiles without errors
- [ ] No regressions introduced
- [ ] Edge cases handled

## Run Validation

```bash
# 1. Build check
xcodebuild build -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54'

# 2. Unit Tests
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54' \
  -only-testing:TimeBoxTests 2>&1 | grep -E "(passed|failed)"

# 3. UI Tests
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'id=D9E26087-132A-44CB-9883-59073DD9CC54' \
  -only-testing:TimeBoxUITests 2>&1 | grep -E "(passed|failed)"
```

## Update Workflow State

**Only after ALL tests pass:**

```bash
python3 -c "
import sys; sys.path.insert(0, '.claude/hooks')
from workflow_state_multi import load_state, save_state, add_test_artifact

state = load_state()
active = state['active_workflow']

# Add GREEN test artifact
add_test_artifact(active, {
    'type': 'ui_test_output',
    'path': 'docs/artifacts/[workflow]/validation-test-output.txt',
    'description': 'ALL TESTS PASSED: [N] unit tests, [M] UI tests green',
    'phase': 'phase7_validate'
})

# Update flags
state['workflows'][active]['ui_test_green_done'] = True
state['workflows'][active]['ui_test_green_result'] = 'All [N] tests passed'
state['workflows'][active]['current_phase'] = 'phase7_validate'
save_state(state)
"

python3 .claude/hooks/workflow_state_multi.py phase phase7_validate
```

## On Test Failure

**If tests fail:**
1. ❌ DO NOT say "bitte manuell testen"
2. ❌ DO NOT proceed to validation
3. ✅ FIX the code
4. ✅ Re-run tests
5. ✅ Repeat until ALL GREEN

## Next Step

**Only when ALL tests pass:**

> "Validation successful. All [N] unit tests and [M] UI tests passed. Ready for commit."

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase8_complete
```

## ⛔ FORBIDDEN

- "Bitte auf Device testen"
- "Bitte manuell prüfen"
- "UI Test fehlgeschlagen, bitte testen"
- Any request for manual testing

**Automated tests ARE the validation. If they fail, FIX THE CODE.**
