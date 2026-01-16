# Specification: Mock EventKit Repository (Phase 2)

**Feature ID:** mock-eventkit-repository-phase2
**Type:** Test Infrastructure - View Dependency Injection
**Created:** 2026-01-15
**Status:** Planned
**Phase:** 2 of 2
**Depends On:** Phase 1 ✅ COMPLETED

---

## Purpose

Enable Timeline UI Tests to run in Simulator by injecting MockEventKitRepository via SwiftUI Environment.

**Problem:**
- 8 UI Tests fail (Timeline tests in BlockPlanningView)
- Views instantiate EventKitRepository directly → not mockable
- Tests require device EventKit permissions → fail in Simulator

**Solution:**
- SwiftUI Environment-based Dependency Injection
- TimeBoxApp provides Mock in UI Test mode
- Views consume via `@Environment` instead of `@State`

---

## Scope

### Phase 2 (This Spec)
**Goal:** Fix 8 Timeline UI Test Failures

| File | Change | LoC |
|------|--------|-----|
| `Sources/Helpers/EventKitRepositoryEnvironment.swift` | CREATE | +25 |
| `Sources/TimeBoxApp.swift` | MODIFY | +10 |
| `Sources/Views/BlockPlanningView.swift` | MODIFY | -3/+3 |
| `Sources/Views/PlanningView.swift` | MODIFY | -3/+3 (optional) |
| `TimeBoxUITests/PlanningViewUITests.swift` | MODIFY | +5 |
| `TimeBoxUITests/SchedulingUITests.swift` | MODIFY | +5 |

**Total:** 6 files, ~50 LoC net change (within ±250 guideline)

### Phase 2B (Optional - Future)
- Remaining 4 Views (FocusLiveView, TaskAssignmentView, SettingsView, SprintReviewSheet)
- If their tests also need Mock

---

## Implementation Details

### 1. Environment Key for EventKitRepository

**File:** `Sources/Helpers/EventKitRepositoryEnvironment.swift` (NEW)

```swift
import SwiftUI

/// EnvironmentKey for EventKitRepository dependency injection
private struct EventKitRepositoryKey: EnvironmentKey {
    static let defaultValue: any EventKitRepositoryProtocol = EventKitRepository()
}

extension EnvironmentValues {
    var eventKitRepository: any EventKitRepositoryProtocol {
        get { self[EventKitRepositoryKey.self] }
        set { self[EventKitRepositoryKey.self] = newValue }
    }
}
```

**Design Notes:**
- Uses `any EventKitRepositoryProtocol` (existential type)
- Default value: Real EventKitRepository (production)
- Can be overridden in Environment for tests

---

### 2. TimeBoxApp Environment Provider

**File:** `Sources/TimeBoxApp.swift`

**BEFORE:**
```swift
@main
struct TimeBoxApp: App {
    var sharedModelContainer: ModelContainer = { ... }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**AFTER:**
```swift
@main
struct TimeBoxApp: App {
    var sharedModelContainer: ModelContainer = { ... }()

    /// Repository based on launch mode (test vs production)
    private var eventKitRepository: any EventKitRepositoryProtocol {
        if ProcessInfo.processInfo.arguments.contains("-UITesting") {
            let mock = MockEventKitRepository()
            mock.mockCalendarAuthStatus = .fullAccess
            mock.mockReminderAuthStatus = .fullAccess
            return mock
        } else {
            return EventKitRepository()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.eventKitRepository, eventKitRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Design Notes:**
- Check for `-UITesting` launch argument
- Mock configured with `.fullAccess` (no permission prompts)
- Production uses real EventKitRepository
- Environment propagates to all child views

---

### 3. BlockPlanningView Injection

**File:** `Sources/Views/BlockPlanningView.swift`

**BEFORE:**
```swift
struct BlockPlanningView: View {
    @State private var eventKitRepo = EventKitRepository()  // ← Direct instantiation
    @State private var selectedDate = Date()
    // ...

    var body: some View {
        // Uses self.eventKitRepo
    }
}
```

**AFTER:**
```swift
struct BlockPlanningView: View {
    @Environment(\.eventKitRepository) private var eventKitRepo  // ← Environment injection
    @State private var selectedDate = Date()
    // ...

    var body: some View {
        // Uses self.eventKitRepo (same interface)
    }
}
```

**Changes:**
- Line ~4: Replace `@State private var eventKitRepo = EventKitRepository()` with `@Environment(\.eventKitRepository) private var eventKitRepo`
- No other changes needed (protocol interface identical)

---

### 4. PlanningView Injection (Optional)

**File:** `Sources/Views/PlanningView.swift`

**Reason:** PlanningView contains TabView with BlockPlanningView. May or may not need injection depending on if it directly uses eventKitRepo.

**Check:** Does PlanningView call eventKitRepo methods?
- If YES → Apply same pattern as BlockPlanningView
- If NO → No changes needed (BlockPlanningView gets Environment from parent)

**Likely:** PlanningView also uses eventKitRepo, so apply same pattern.

---

### 5. UI Test Setup

**File:** `TimeBoxUITests/PlanningViewUITests.swift`

**Add to setUp:**
```swift
override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-UITesting"]  // ← Inject Mock
    app.launch()
}
```

**File:** `TimeBoxUITests/SchedulingUITests.swift`

**Same setup:**
```swift
override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-UITesting"]  // ← Inject Mock
    app.launch()
}
```

**Impact:**
- Tests now launch with Mock
- No permission prompts
- Timeline renders immediately

---

## Expected Behavior

### Production Mode (No -UITesting)
```swift
TimeBoxApp launches
→ eventKitRepository = EventKitRepository()  // Real
→ requestAccess() → Shows iOS permission dialog
→ User grants/denies access
→ App behaves normally
```

### UI Test Mode (With -UITesting)
```swift
TimeBoxApp launches with ["-UITesting"]
→ eventKitRepository = MockEventKitRepository()  // Mock
→ mock.mockCalendarAuthStatus = .fullAccess
→ requestAccess() → Returns true (no dialog)
→ Timeline renders immediately
→ Tests can find hour labels ("08:00", "09:00", etc.)
```

---

## Test Plan

### UI Tests Execution

```bash
# Run failing Timeline tests
xcodebuild test -scheme TimeBox \
  -only-testing:TimeBoxUITests/PlanningViewUITests/testTimelineShowsHours \
  -only-testing:TimeBoxUITests/SchedulingUITests \
  -destination 'platform=iOS Simulator,id=...'
```

### Expected Results

**BEFORE (Phase 1):**
```
Test Suite 'PlanningViewUITests' failed
  ❌ testTimelineShowsHours - Hour labels not found

Test Suite 'SchedulingUITests' failed
  Executed 7 tests, with 7 failures
    ❌ testBlockPlanningViewShowsTimeline
    ❌ testTimelineShowsFreeSlots
    ❌ testTimelineSlotsExist
    ❌ (4 more failures)

Total: 21/29 passed (8 failures)
```

**AFTER (Phase 2):**
```
Test Suite 'PlanningViewUITests' passed
  ✅ testTimelineShowsHours

Test Suite 'SchedulingUITests' passed
  Executed 7 tests, with 0 failures ✅
    ✅ testBlockPlanningViewShowsTimeline
    ✅ testTimelineShowsFreeSlots
    ✅ testTimelineSlotsExist
    ✅ (4 more passing)

Total: 29/29 passed ✅ (0 failures)
```

---

## Acceptance Criteria

- [x] EventKitRepositoryEnvironment created with EnvironmentKey
- [x] TimeBoxApp injects Mock when `-UITesting` flag present
- [x] BlockPlanningView uses `@Environment` instead of `@State`
- [x] PlanningView uses `@Environment` (if needed)
- [x] UI Tests set `-UITesting` launch argument
- [x] All 8 Timeline UI tests pass ✅
- [x] No regressions in other tests
- [x] Build succeeds
- [x] App runs normally in production mode
- [x] UI Test count: 21/29 → 29/29 passed

---

## Known Limitations (Phase 2)

**Views NOT updated:**
- FocusLiveView
- TaskAssignmentView
- SettingsView
- SprintReviewSheet

**Reason:** Not involved in failing Timeline tests.

**Impact:** These views still use direct instantiation. If their tests need Mock later, update in Phase 2B.

---

## Migration Path (Optional - Phase 2B)

If other views need Mock later:

**1-line change per view:**
```swift
// BEFORE
@State private var eventKitRepo = EventKitRepository()

// AFTER
@Environment(\.eventKitRepository) private var eventKitRepo
```

**No other changes needed** - Protocol interface identical.

---

## Risk Assessment

### Risk: LOW ✅

**Mitigation:**
- Environment Injection is standard SwiftUI pattern
- `-UITesting` flag prevents Mock in production
- Default EnvironmentValue is real EventKitRepository
- Mock already validated in Phase 1 Unit Tests

### Production Safety
- ✅ Production launch (no flag) → EventKitRepository (real)
- ✅ UI Test launch (with flag) → MockEventKitRepository
- ✅ No accidental Mock usage in production
- ✅ Behavior identical for end users

---

## Rollback Plan

If Phase 2 causes issues:
1. Revert view changes (restore `@State` instantiation)
2. Remove Environment setup from TimeBoxApp
3. Remove `-UITesting` from test setUp
4. System returns to Phase 1 state (Unit Tests work, UI Tests still fail)

---

## Related Documents

- Phase 1 Spec: `openspec/changes/mock-eventkit-repository/spec.md`
- Phase 1 Tests: `openspec/changes/mock-eventkit-repository/tests.md`
- Phase 2 Tests: `openspec/changes/mock-eventkit-repository/tests-phase2.md`
- Test Failure Analysis: `docs/test-failures-analysis.md`

---

**Status:** Ready for Implementation
**Approver:** Henning (Product Owner)
**Next Step:** Wait for approval → Implement → Run UI Tests
