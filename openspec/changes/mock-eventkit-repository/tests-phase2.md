# Test Definitions: Mock EventKit Repository (Phase 2)

**Feature:** View Dependency Injection + UI Test Fixes

**Phase:** 2 (UI Tests - Builds on Phase 1 Foundation)

---

## Test Strategy

### Scope
- ✅ UI Tests for Timeline Views (8 failing tests)
- ✅ Focused on BlockPlanningView + PlanningView
- ❌ Other 4 Views (deferred to Phase 2B if needed)

### Test Environment
- Platform: iOS Simulator
- Permissions: None required (using Mock via Environment)
- Xcode Test Target: TimeBoxUITests

---

## UI Tests (Fix Existing Failures)

### File: `TimeBoxUITests/PlanningViewUITests.swift`

#### 1. Timeline Hour Labels Test (Currently FAILING)

**Test:** `testTimelineShowsHours`

**BEFORE (Fails):**
```swift
func testTimelineShowsHours() throws {
    app.tabBars.buttons["Blöcke"].tap()
    sleep(2)

    let hour08 = app.staticTexts["08:00"]
    let hour12 = app.staticTexts["12:00"]

    XCTAssertTrue(hour08.exists || hour12.exists, "Timeline should show hour labels")
    // ❌ FAILS: Hour labels don't exist (BlockPlanningView shows error state)
}
```

**AFTER (Should Pass):**
```swift
func testTimelineShowsHours() throws {
    // Mock is injected via Environment in TimeBoxApp
    // BlockPlanningView.loadData() → mock.requestAccess() returns true
    // Timeline renders with hour labels

    app.tabBars.buttons["Blöcke"].tap()
    sleep(2)

    let hour08 = app.staticTexts["08:00"]
    let hour12 = app.staticTexts["12:00"]

    XCTAssertTrue(hour08.exists || hour12.exists, "Timeline should show hour labels")
    // ✅ PASSES: Mock grants access, timeline renders
}
```

---

### File: `TimeBoxUITests/SchedulingUITests.swift`

#### 2. Block Planning Timeline Test (Currently FAILING)

**Test:** `testBlockPlanningViewShowsTimeline`

**Expected Result:** Timeline shows hour labels (09:00, 10:00, 11:00)

**Current Issue:** BlockPlanningView.loadData() fails auth check → shows error state

**After Fix:** Mock returns `.fullAccess` → timeline renders → hour labels exist

#### 3-8. Additional Timeline Tests (Currently FAILING)

- `testTimelineShowsFreeSlots` - Scrollable timeline
- `testTimelineSlotsExist` - Multiple hour slots visible
- `testBlocksDisplayInTimeline` - Focus blocks render
- `testChangingDateUpdatesTimeline` - Date picker works
- `testDatePickerExists` - Toolbar has date picker
- *(Additional tests as per test file)*

**All follow same pattern:**
- ❌ BEFORE: Auth denied → error state → UI elements not rendered
- ✅ AFTER: Mock auth → timeline renders → UI elements exist

---

## Implementation Validation Tests

### Manual Test: Environment Injection

**Test:** Verify Mock is injected in UI Test mode

```swift
// In TimeBoxApp.body
if ProcessInfo.processInfo.arguments.contains("-UITesting") {
    ContentView()
        .environment(\.eventKitRepository, MockEventKitRepository())
} else {
    ContentView()
        .environment(\.eventKitRepository, EventKitRepository())
}
```

**Validation:**
1. Run UI tests
2. Breakpoint in BlockPlanningView.loadData()
3. Verify `eventKitRepo` is MockEventKitRepository type
4. Verify `requestAccess()` returns true

---

### Unit Test: Environment Key

**File:** `TimeBoxTests/EnvironmentTests.swift` (NEW - Optional)

```swift
func test_environmentKey_defaultsToRealRepository() {
    // GIVEN: Default environment
    let view = TestHostingView()

    // WHEN: Reading environment key
    // THEN: Returns EventKitRepository instance
    XCTAssertTrue(view.repo is EventKitRepository)
}

func test_environmentKey_canBeOverridden() {
    // GIVEN: Environment with Mock
    let mock = MockEventKitRepository()
    let view = TestHostingView()
        .environment(\.eventKitRepository, mock)

    // WHEN: Reading environment key
    // THEN: Returns Mock instance
    XCTAssertTrue(view.repo is MockEventKitRepository)
}
```

---

## Test Execution Plan

### Preparation
1. Implement EnvironmentKey for EventKitRepository
2. Update TimeBoxApp to inject Mock in UI Test mode
3. Update BlockPlanningView to use `@Environment` instead of `@State`
4. Update PlanningView (if needed for navigation)

### Execution
```bash
# Run only Timeline UI tests
xcodebuild test -scheme TimeBox \
  -only-testing:TimeBoxUITests/PlanningViewUITests/testTimelineShowsHours \
  -only-testing:TimeBoxUITests/SchedulingUITests \
  -destination 'platform=iOS Simulator,id=...'
```

### Expected Results

**Before:**
```
Test Suite 'PlanningViewUITests' failed
  testTimelineShowsHours: ❌ FAILED (hour labels not found)

Test Suite 'SchedulingUITests' failed
  Executed 7 tests, with 7 failures
```

**After:**
```
Test Suite 'PlanningViewUITests' passed
  testTimelineShowsHours: ✅ PASSED

Test Suite 'SchedulingUITests' passed
  Executed 7 tests, with 0 failures ✅
```

---

## Success Criteria

### Must Pass (BLOCKING)
- ✅ All 8 Timeline UI tests pass
- ✅ No regressions in existing tests
- ✅ Build succeeds
- ✅ App runs normally in production mode (non-test)

### Test Metrics
- UI Tests: 29 total
  - Before: 21 passed, 8 failed (Timeline tests)
  - After: 29 passed, 0 failed ✅
- Unit Tests: Unchanged (79 tests)

---

## Edge Cases to Test

### 1. Production vs Test Mode
**Test:** App uses correct repository based on launch arguments

```swift
// Production launch (no -UITesting flag)
→ Uses EventKitRepository (real)
→ Requests actual device permissions

// UI Test launch (with -UITesting flag)
→ Uses MockEventKitRepository
→ No permission prompts
→ Timeline renders immediately
```

### 2. Tab Navigation
**Test:** Switching between tabs maintains Environment

```swift
func testTabSwitchingMaintainsEnvironment() {
    // GIVEN: App launched with Mock
    // WHEN: Switch to "Blöcke" tab → "Aufgaben" tab → "Blöcke" tab
    app.tabBars.buttons["Blöcke"].tap()
    app.tabBars.buttons["Aufgaben"].tap()
    app.tabBars.buttons["Blöcke"].tap()

    // THEN: Timeline still renders (Mock still injected)
    XCTAssertTrue(app.staticTexts["08:00"].exists)
}
```

### 3. Mock Data Persistence
**Test:** Mock data doesn't leak between tests

```swift
override func setUp() {
    // Each test gets fresh app launch → fresh Mock
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-UITesting"]
    app.launch()
}

override func tearDown() {
    // Mock is discarded
    app.terminate()
}
```

---

## Risk Assessment

### LOW Risk
- ✅ Environment Injection is standard SwiftUI pattern
- ✅ Mock already tested in Phase 1
- ✅ Production code unchanged (uses real EventKitRepository)
- ✅ Only UI Test mode uses Mock

### Mitigation
- Check for `-UITesting` flag explicitly
- Default to real EventKitRepository if flag missing
- Add assertion in TimeBoxApp to verify correct mode

---

## Out of Scope (Phase 2B - Optional)

Views NOT updated in this phase:
- ❌ FocusLiveView
- ❌ TaskAssignmentView
- ❌ SettingsView
- ❌ SprintReviewSheet

**Reason:** Not involved in failing Timeline tests. Can be updated later if their tests fail.

---

**Status:** ⛔ BLOCKING - Must be approved before implementation
**Depends On:** Phase 1 (EventKitRepositoryProtocol + Mock) ✅ DONE
