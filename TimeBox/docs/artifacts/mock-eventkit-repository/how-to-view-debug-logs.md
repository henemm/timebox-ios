# How to View Debug Logs - Timeline Rendering Investigation

**Date:** 2026-01-16
**Purpose:** Understand why timeline isn't rendering in UI tests

## What Was Added

Comprehensive debug logging throughout the app to trace:

1. **Mock Injection** (TimeBoxApp.swift)
   - 🟠 Orange emoji - Shows which repository is being used
   - Logs: "TimeBoxApp: -UITesting flag detected, using MockEventKitRepository"

2. **View Lifecycle** (BlockPlanningView.swift)
   - 🟢 Green emoji - View rendering
   - 🟡 Yellow emoji - Loading state
   - 🔴 Red emoji - Error state
   - 🟣 Purple emoji - Task/onChange triggers

3. **Data Loading** (BlockPlanningView.loadData())
   - 🔵 Blue emoji - Load process steps
   - Logs: Access requests, fetch results, final state

## How to View Logs

### Option A: Console.app (Recommended for Simulator)

1. Open `/Applications/Utilities/Console.app`
2. Select your simulator from sidebar (e.g., "iPhone 17 Pro")
3. Click **Start** button to begin capturing
4. Run the UI test or launch app manually:
   ```bash
   cd /Users/hem/Documents/opt/my-daily-sprints/TimeBox
   xcodebuild test -scheme TimeBox \
     -only-testing:TimeBoxUITests/SchedulingUITests/testBlockPlanningViewShowsTimeline \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```
5. In Console.app, filter by process: "TimeBox"
6. Search for emoji markers: 🟠 🔵 🟢 🟡 🔴 🟣

### Option B: Xcode Console (Device Testing)

1. Connect your iPhone
2. Open TimeBox.xcodeproj in Xcode
3. Select your device as destination
4. Edit Scheme → Run → Arguments → Add: `-UITesting`
5. Run the app (Cmd+R)
6. Navigate to **Blöcke** tab
7. View console output in Xcode's Debug Area (Cmd+Shift+Y)
8. Look for emoji markers

### Option C: Command Line (Simulator)

```bash
# Start simulator
open -a Simulator

# Get simulator ID
xcrun simctl list devices | grep Booted

# Tail logs in real-time
xcrun simctl spawn <UDID> log stream --level debug --predicate 'processImagePath contains "TimeBox"'

# In another terminal, run the test
cd /Users/hem/Documents/opt/my-daily-sprints/TimeBox
xcodebuild test -scheme TimeBox \
  -only-testing:TimeBoxUITests/SchedulingUITests/testBlockPlanningViewShowsTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## What to Look For

### Expected Log Sequence (Successful Load):

```
🟠 TimeBoxApp: -UITesting flag detected, using MockEventKitRepository
🟠 TimeBoxApp: Mock configured with .fullAccess permissions
🟢 BlockPlanningView.body rendered - isLoading: true, errorMessage: nil
🟡 Showing: ProgressView (Loading)
🟣 .task modifier triggered - calling loadData()
🔵 BlockPlanningView.loadData() START
🔵   isLoading = true
🔵   Calling eventKitRepo.requestAccess()...
🔵   requestAccess() returned: true
🔵   Fetching calendar events for 2026-01-16...
🔵   ✅ Fetched 0 calendar events
🔵   Fetching focus blocks for 2026-01-16...
🔵   ✅ Fetched 0 focus blocks
🔵 BlockPlanningView.loadData() END
🔵   Final state: isLoading=false, errorMessage=nil, events=0, blocks=0
🟢 BlockPlanningView.body rendered - isLoading: false, errorMessage: nil
🟢 Showing: blockPlanningTimeline (0 events, 0 blocks)
```

### If Timeline Doesn't Show (Possible Scenarios):

**Scenario 1: Stuck in Loading**
```
🟡 Showing: ProgressView (Loading)
[No further logs after this]
```
→ **Diagnosis:** loadData() never completes or crashes

**Scenario 2: Error State**
```
🔴 Showing: ContentUnavailableView (Error: <message>)
```
→ **Diagnosis:** Mock throws error or returns false from requestAccess()

**Scenario 3: Timeline Shows But Empty**
```
🟢 Showing: blockPlanningTimeline (0 events, 0 blocks)
[But hour labels not found in tests]
```
→ **Diagnosis:** Timeline renders but accessibility IDs missing

## Analyzing Results

Once you have the logs, check:

1. **Is Mock being used?**
   - Look for: "TimeBoxApp: -UITesting flag detected"
   - If not present: `-UITesting` flag not set correctly

2. **Does requestAccess() succeed?**
   - Look for: "requestAccess() returned: true"
   - If false: Mock auth status not set correctly

3. **What's the final view state?**
   - isLoading: Should be false after load
   - errorMessage: Should be nil
   - events/blocks: Can be 0 (that's OK)

4. **Which view branch renders?**
   - 🟢 Timeline → Good (but why no hour labels?)
   - 🟡 Loading → Bad (stuck loading)
   - 🔴 Error → Bad (what's the error?)

## Next Steps Based on Findings

| Log Pattern | Diagnosis | Fix |
|------------|-----------|-----|
| No 🟠 logs | `-UITesting` not set | Check test setUp methods |
| Stuck at 🟡 | loadData() hangs | Add timeout, check async |
| Shows 🔴 | Error thrown | Check Mock implementation |
| Shows 🟢 but test fails | Timeline renders, accessibility issue | Add `.accessibilityIdentifier()` to hour labels |

## Cleanup

After investigation, remove debug logging:
```swift
// Remove all lines containing:
print("🟠 ...
print("🔵 ...
print("🟢 ...
print("🟡 ...
print("🔴 ...
print("🟣 ...
let _ = print(...
```

---

**Status:** Debug logging active in commit `6a4e3fd`
**Ready For:** User investigation with Console.app or device testing
