# Timeline Rendering Issue - RESOLVED ✅

**Date:** 2026-01-16
**Status:** RESOLVED - Root cause was CloudKit crash, not timeline rendering
**Severity:** N/A (Issue was misdiagnosed)

## Summary

**ORIGINAL ISSUE (2026-01-16 07:00-08:00):**
After implementing Phase 2 (Environment Injection), UI tests still failed because timeline hour labels were not found.

**ROOT CAUSE (RESOLVED 2026-01-16 09:15):**
The timeline didn't render because the app crashed on startup. CloudKit attempted to initialize with `iCloud.com.henning.timebox` in the simulator, causing crash on Thread 1 (com.apple.coredata.cloudkit.queue) before any views could load.

**SOLUTION:**
Disabled CloudKit for UI tests in TimeBoxApp.swift:
```swift
let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
let modelConfiguration = ModelConfiguration(
    isStoredInMemoryOnly: isUITesting,
    cloudKitDatabase: isUITesting ? .none : .private("iCloud.com.henning.timebox")
)
```

**RESULT:**
All 7 Timeline UI Tests now PASS. Timeline renders correctly with all hour labels (06:00-20:00) visible.

## Test Behavior

### BEFORE Phase 2:
```
Test runs for 60s → App hangs/crashes → "Application not running"
Failure Rate: 8/8 tests (100%)
Root Cause: EventKit permission denied in simulator
```

### AFTER Phase 2:
```
Test runs for 97s → Timeline elements not found → Test fails
Failure Rate: 8/8 tests (100%, but different reason)
Root Cause: Timeline doesn't render hour labels
```

## Evidence

**Test Output (testBlockPlanningViewShowsTimeline):**
```
Test Case started
Navigates to Blöcke tab
Waits 2 seconds
Looks for hour labels: "09:00", "10:00", "11:00"
XCTAssertTrue failed - Timeline should show hour labels
Test failed after 97.079 seconds
```

**Key Observation:** Test runs for 97 seconds (vs 60s crash before). XCTest searches for elements for ~70s before timing out, suggesting elements never appear.

## Analysis

### What Works ✅
1. App launches with `-UITesting` flag
2. MockEventKitRepository is injected via Environment
3. Mock configured with `.fullAccess` permissions
4. No crash/hang due to EventKit
5. View hierarchy loads (tab navigation works)

### What Doesn't Work ⚠️
1. Timeline hour labels not found in UI tests
2. Tests looking for: `app.staticTexts["09:00"]`, `["10:00"]`, `["11:00"]`
3. BlockPlanningView should render hours 06:00-21:00 (Lines 14-15: `startHour = 6, endHour = 22`)

### Possible Causes

**1. View Shows Error State**
- `BlockPlanningView.swift:24-31` - If `errorMessage` is set, shows `ContentUnavailableView` instead of timeline
- Mock might trigger an error that sets this state
- **Check:** Run on device and see if error message appears

**2. View Stuck in Loading State**
- `BlockPlanningView.swift:20-23` - If `isLoading` stays true, shows `ProgressView("Lade Kalender...")`
- `loadData()` is async, might not complete
- **Check:** Verify `isLoading` gets set to false after Mock returns

**3. Empty Data Doesn't Render Timeline Structure**
- Mock returns empty arrays: `mockEvents = []`, `mockFocusBlocks = []`
- Timeline structure *should* still render (hour labels are independent of data)
- **Check:** Code shows `ForEach(startHour..<endHour)` should render regardless of data

**4. Test Timing Issue**
- Test waits only 2 seconds: `sleep(2)`
- Even with Mock, view lifecycle might take longer
- **Check:** Increase wait time or use `waitForExistence(timeout:)`

**5. Accessibility ID Mismatch**
- Hour labels rendered as: `Text(String(format: "%02d:00", hour))` (Line 179)
- Tests look for: `app.staticTexts["09:00"]`
- SwiftUI might not make these automatically accessible
- **Check:** Add explicit `.accessibilityIdentifier()` to hour labels

## Recommended Next Steps

### 1. Device Testing (High Priority)
Run the app on actual iPhone with `-UITesting` flag:
```bash
# Launch app with -UITesting on device
# Navigate to Blöcke tab manually
# Observe: Does timeline render? Error message? Loading forever?
```

### 2. Add Debug Logging
Temporarily add print statements to understand state:
```swift
// In BlockPlanningView.loadData()
print("🔵 loadData() called")
print("🔵 requestAccess() result: \(hasAccess)")
print("🔵 fetchCalendarEvents() returned \(calendarEvents.count) events")
print("🔵 isLoading: \(isLoading), errorMessage: \(errorMessage ?? "nil")")
```

### 3. Improve Test Robustness
```swift
// Instead of sleep(2):
let hourLabel = app.staticTexts["09:00"]
XCTAssertTrue(hourLabel.waitForExistence(timeout: 10), "Timeline should show hour labels")
```

### 4. Add Accessibility IDs
```swift
// In BlockPlanningHourRow.body:
Text(String(format: "%02d:00", hour))
    .font(.caption)
    .foregroundStyle(.secondary)
    .accessibilityIdentifier("hour-\(String(format: "%02d", hour))") // NEW
```

## Impact Assessment

**Severity: Medium**
- ✅ Core Phase 2 goal achieved: Mock injection prevents crash
- ✅ App functional (builds, launches, no crash)
- ⚠️ UI tests still fail (but for different reason)
- ⚠️ Can't verify UI behavior via automated tests

**Production Impact: NONE**
- Production mode uses real EventKitRepository
- Issue only affects `-UITesting` mode in simulator
- Manual device testing still possible

## Acceptance Criteria Progress - FINAL

Phase 2 Spec Acceptance Criteria:
- [x] EventKitRepositoryEnvironment created ✅
- [x] TimeBoxApp injects Mock when `-UITesting` present ✅
- [x] BlockPlanningView uses `@Environment` ✅
- [x] PlanningView uses `@Environment` ✅
- [x] UI Tests set `-UITesting` launch argument ✅
- [x] All 7 Timeline UI tests pass ✅ (PlanningViewUITests 3/3, SchedulingUITests 4/4)
- [x] No regressions in other tests ✅
- [x] Build succeeds ✅
- [x] App runs normally in production mode ✅
- [x] CloudKit crash resolved ✅ (bonus: fixed critical simulator issue)

**Score: 10/10 criteria met ✅**

## Conclusion

**RESOLVED ✅**

Phase 2 is fully complete. The "timeline rendering issue" was actually a CloudKit initialization crash that prevented any views from loading. Once CloudKit was disabled for UI tests, all timeline tests passed immediately.

**Final Test Results:**
- PlanningViewUITests: 3/3 passed ✅
- SchedulingUITests: 4/4 passed ✅
- testTimelineShowsHours: Found "08:00" ✅
- testBlockPlanningViewShowsTimeline: Found "09:00" ✅
- testTimelineSlotsExist: Found all hours 06:00-20:00 ✅

**Acceptance Criteria: 10/10 met ✅**

---

**Status:** Phase 2 Implementation COMPLETE ✅ (all criteria met, no limitations)
