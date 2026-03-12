# VALIDATION REPORT: Monster Coach Phase 3b (Smart Notifications)

**Date:** 2026-03-12  
**Status:** FAILED - 3 Critical Bugs Found  
**Test Results:** 27/27 Unit Tests PASS, but logic bugs not caught by tests  

---

## Executive Summary

The Monster Coach Phase 3b implementation has **3 critical bugs** that violate the specification:

1. **FOKUS fulfillment logic is inverted** — contradicts spec "Block today OR 70% completion"
2. **Notification window scheduling can produce backwards times** — silent failure for evening users
3. **Block completion percentage not implemented** — spec requires 70% threshold

These are NOT caught by unit tests because the tests don't validate the SPEC correctly.

---

## VALIDATION RESULTS

### ✅ PASSED: Test Infrastructure
- All 27 unit tests pass (14 IntentionEvaluation, 7 Notification, 6 Intent Service tests)
- Test structure is sound
- Accessibility identifiers correctly added for UI testing

### ✅ PASSED: Input Validation
- @AppStorage defaults are reasonable (maxCount: 2, window: 10-18)
- Picker enforces 1-3 for maxCount (no 0 corruption possible via UI)
- DatePickers restrict to hours only

### ❌ FAILED: FOKUS Intention Logic

**Location:** `Sources/Services/IntentionEvaluationService.swift:33-37`

**What was implemented:**
```swift
case .fokus:
    let hasBlocks = !focusBlocksToday(focusBlocks, now: now).isEmpty
    let hasOutsideTasks = completedToday(tasks, now: now)
        .contains { $0.assignedFocusBlockID == nil }
    return hasBlocks && !hasOutsideTasks
```

**What spec says (proposal.md:54):**
```
| .fokus | Mindestens ein Focus Block heute ODER Block-Completion >= 70% |
```

**The Problem:**
- Implementation: `hasBlocks && !hasOutsideTasks` (AND logic)
- Spec: `hasBlocks OR blockCompletion >= 70%` (OR logic)

These are **fundamentally different conditions!**

**Impact:**
```
Scenario A: User creates 1 empty block, completes 0 tasks
  - Implementation: fulfilled = true && true = TRUE (✓ appears fulfilled)
  - Spec intent: fulfilled = true || 0% = FALSE (✗ should be unfulfilled)

Scenario B: User completes 5 tasks OUTSIDE blocks, creates no blocks
  - Implementation: fulfilled = false && false = TRUE (✓ reports as unfulfilled)
  - Spec intent: fulfilled = false || 0% = FALSE (✓ correctly unfulfilled)
  - BUT: Message would be "Kein Block geplant" when user completed many tasks!

Scenario C: User has block with 80% completion
  - Implementation: Can't evaluate (missing completion helper)
  - Spec intent: fulfilled = true || 80% = TRUE
```

**Missing Code:**
The FOKUS logic is missing the block completion percentage calculation entirely.

**Root Cause:**
Spec vs. implementation mismatch. The spec uses OR, implementation uses AND.

---

### ❌ FAILED: Notification Window Scheduling

**Location:** `Sources/Services/NotificationService.swift:510-524`

**What was implemented:**
```swift
let startComps = DateComponents(hour: settings.coachNudgeWindowStartHour, minute: 0)
let endComps = DateComponents(hour: settings.coachNudgeWindowEndHour, minute: 0)

guard let windowStart = cal.nextDate(
    after: cal.startOfDay(for: now),
    matching: startComps, matchingPolicy: .nextTime
),
let windowEnd = cal.nextDate(
    after: cal.startOfDay(for: now),
    matching: endComps, matchingPolicy: .nextTime
) else { return }
```

**The Problem — Case 1: Evening User (now = 19:00, settings = 10:00-18:00)**

Time progression:
- now = 19:00 (today)
- startOfDay = 00:00 (today)
- nextDate(after: 00:00, matching 10:00) = 10:00 (today) ← PAST!
- nextDate(after: 00:00, matching 18:00) = 18:00 (today) ← PAST!

In buildDailyNudgeRequests:
- `guard windowEnd > now` checks: 18:00 > 19:00 = FALSE
- Returns empty array ✓ (correct by accident)

BUT: The window times are WRONG:
- windowStart = 10:00 (today, 9 hours ago)
- windowEnd = 18:00 (today, 1 hour ago)

**The Problem — Case 2: User sets backwards window (Von 18:00 Bis 10:00)**

Settings: coachNudgeWindowStartHour = 18, coachNudgeWindowEndHour = 10
Time: now = 14:00 (today)

- nextDate(after: 00:00, matching 18:00) = 18:00 (today)
- nextDate(after: 00:00, matching 10:00) = 10:00 (today) ← EARLIER than 18:00!

In buildDailyNudgeRequests:
```swift
let windowDuration = windowEnd.timeIntervalSince(effectiveStart)
// 10:00 - 18:00 = negative!
guard windowDuration > 0 else { return [] }
```

Returns empty because negative duration ✓ (guards correctly)

BUT: No error reported to user. Settings silently fail.

**The Problem — Case 3: Next-day boundary (Von 22:00 Bis 06:00)**

Spec allows this (overnight window). But implementation can't handle it:
- Both nextDate calls return TODAY's times
- Window never spans to tomorrow

**Impact:**
- Evening users (after 18:00) never get notifications scheduled → SILENT FAILURE
- Backwards window (18:00 to 10:00) silently produces empty array → SILENT FAILURE
- No validation that endHour > startHour
- No validation that window hasn't already passed

**Missing Code:**
Need to validate:
```swift
guard settings.coachNudgeWindowStartHour < settings.coachNudgeWindowEndHour else {
    print("⚠️ Coach nudge window is backwards")
    return
}
// Also need to handle case where window start is in past
let now = Date()
if windowStart < now {
    windowStart = max(now, windowStart) // Move to now if past
}
```

---

### ❌ FAILED: Missing Block Completion Helper

**Location:** `Sources/Services/IntentionEvaluationService.swift:33-37` (referenced by spec:54)

**What spec requires (proposal.md:54):**
```
| .fokus | Mindestens ein Focus Block heute ODER Block-Completion >= 70% |
```

**What's implemented:**
- Only checks `!focusBlocksToday(focusBlocks, now: now).isEmpty`
- Zero code to calculate block completion percentage

**Missing implementation:**
```swift
// MISSING: Calculate completion ratio from FocusBlock
static func calculateBlockCompletion(_ block: FocusBlock) -> Double {
    guard !block.taskIDs.isEmpty else { return 0.0 }
    let completedCount = Double(block.completedTaskIDs.count)
    let totalCount = Double(block.taskIDs.count)
    return completedCount / totalCount
}
```

**Impact:**
- A block with 1 task completed out of 10 (10% complete) counts as "block exists" ✓
- A block with 0 tasks counts as "block exists" ✓
- Nowhere in code can you evaluate "80% complete" per spec
- FOKUS fulfillment can never be true via the OR condition

**Root Cause:**
Spec requirement for "70% completion OR" was not implemented — only the "block exists" part was coded.

---

### ⚠️ WARNING: Gap Detection Called with Empty Data

**Location:** `Sources/Views/MorningIntentionView.swift:103-110`

**What was implemented:**
```swift
if let primary = selections.first,
   let gap = IntentionEvaluationService.detectGap(
       intention: primary, tasks: [], focusBlocks: []
   ) {
    NotificationService.scheduleDailyNudges(intention: primary, gap: gap)
}
```

**The Problem:**
At 7 AM when user sets intention, they have done NOTHING yet:
- tasks: [] (no tasks completed today — it's 7 AM!)
- focusBlocks: [] (no blocks created yet)

Gap detection on empty data:

| Intention | Gap with empty data | Correct? |
|-----------|---------------------|----------|
| .survival | nil ✓ | Correct (no notifications) |
| .bhag | .noBhagBlockCreated ✓ | Correct (user hasn't acted yet) |
| .fokus | .noFocusBlockPlanned ✓ | Correct (morning, no blocks expected) |
| .growth | .noLearningTask ✗ | WRONG (it's 7 AM, hasn't had time!) |
| .connection | .noConnectionTask ✗ | WRONG (hasn't had time!) |
| .balance | .onlySingleCategory ✗ | WRONG (0 categories completed, not "single") |

**Impact:**
- For GROWTH/CONNECTION/BALANCE: notifications scheduled with wrong gap reason at morning
- Spec says gap detection finds "Luecken" (gaps between intention and action)
- But calling it at 7 AM before any action = guaranteed gap (but not a real gap!)

**Better approach:**
- Don't schedule notifications with gap at morning
- Either: Use placeholder text (ignore gap at morning)
- Or: Check gap only when notifications are about to fire (requires background task)

**Current mitigation:** User won't see notifications until later anyway (window 10:00-18:00), so this surfaces as poor text ("Du wolltest was Neues lernen" at 7 AM when just 3 hours free).

---

### ⚠️ WARNING: BHAG Gap Logic Returns Same Case Twice

**Location:** `Sources/Services/IntentionEvaluationService.swift:69-78`

**What was implemented:**
```swift
case .bhag:
    let todayBlocks = focusBlocksToday(focusBlocks, now: now)
    let hour = Calendar.current.component(.hour, from: now)
    if todayBlocks.isEmpty {
        return .noBhagBlockCreated  // Line 73
    }
    if hour >= 13 {
        return .bhagTaskNotStarted
    }
    return .noBhagBlockCreated  // Line 78 ← Same as line 73!
```

**The Problem:**
If blocks exist but time < 13:00, returns `.noBhagBlockCreated`
But `.noBhagBlockCreated` is also returned when NO blocks exist!

Two different situations return the same gap type:
1. No blocks created at all (real gap)
2. Blocks created but morning time (not really a gap, just early)

**Semantic mismatch with spec:**
- `noBhagBlockCreated`: "Kein Block mit BHAG-Task"
- `bhagTaskNotStarted`: "Nachmittags noch kein BHAG-Task erledigt"

Code returns `noBhagBlockCreated` for BOTH cases.

**Impact:**
- User gets same notification at 9 AM (blocks exist but morning) and 2 PM (no blocks)
- Message is semantically wrong for the morning case
- Text should be different for "You have a block" vs. "You have no block"

**Better implementation:**
```swift
case .bhag:
    let todayBlocks = focusBlocksToday(focusBlocks, now: now)
    if todayBlocks.isEmpty {
        return .noBhagBlockCreated
    }
    // Blocks exist, check if BHAG task is in those blocks
    let bhagTaskInBlocks = completedToday(tasks, now: now)
        .contains { $0.importance == 3 }
    if !bhagTaskInBlocks {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 13 ? .bhagTaskNotStarted : .noBhagBlockStarted
    }
    return nil  // Fulfilled
```

---

### ⚠️ WARNING: Thread Safety Annotation Misuse

**Location:** `Sources/Services/NotificationService.swift:455`

**What was implemented:**
```swift
@MainActor
enum NotificationService {
    private static nonisolated(unsafe) let dailyNudgePrefix = "coach-nudge-"
    
    nonisolated static func buildDailyNudgeRequests(...) -> [UNNotificationRequest] {
        // Uses dailyNudgePrefix here (line 494)
    }
    
    static func scheduleDailyNudges(...) {
        // @MainActor context
    }
}
```

**The Problem:**
- `dailyNudgePrefix` is marked `nonisolated(unsafe)`
- It's used in `buildDailyNudgeRequests` which is `nonisolated`
- If `buildDailyNudgeRequests` is called from background thread, accessing `dailyNudgePrefix` is a data race

**However:** Since it's a constant String (read-only), actual risk is minimal.

**Better approach:**
```swift
private static let dailyNudgePrefix = "coach-nudge-"  // Remove unsafe, keep in enum

// Or: Use inline string
let identifier = "coach-nudge-\(i)"
```

**Impact:** Low — String is read-only, immutable. But technically violates Swift concurrency safety model.

---

## Test Plan to Verify Bugs

### Unit Test Gaps

The current unit tests PASS but don't catch the logic bugs because:

1. **FOKUS test doesn't check BOTH conditions of spec**
   - Test only checks: "hasBlocks && !hasOutsideTasks"
   - Doesn't test: "blockCompletion >= 70%" (missing code!)

2. **Window test doesn't test evening user scenario**
   - Test: 08:00 with window 10:00-18:00 ✓
   - Missing: 19:00 with window 10:00-18:00 (should be empty)

3. **Gap detection test calls with DATA instead of empty**
   - Current test provides actual tasks
   - Morning scenario (empty tasks) not tested

### Required Tests

```swift
// Test FOKUS block completion path (currently impossible)
func test_isFulfilled_fokus_whenBlockCompletionIs80Percent_returnsTrue() {
    let block = FocusBlock(..., completedTaskIDs: [1,2,3,4], taskIDs: [1,2,3,4,5])
    // Missing implementation: Can't test
    XCTAssertTrue(...)
}

// Test window timing for evening user (19:00)
func test_buildDailyNudgeRequests_eveningUser_afterWindowEnd() {
    let now = Calendar.current.date(bySettingHour: 19, minute: 0, ...)!
    let requests = NotificationService.buildDailyNudgeRequests(
        intention: .bhag, gap: .noBhagBlockCreated,
        windowStart: Calendar.current.date(bySettingHour: 10, ...)!,
        windowEnd: Calendar.current.date(bySettingHour: 18, ...)!,
        maxCount: 2, now: now
    )
    XCTAssertTrue(requests.isEmpty, "Evening user after window should not get notifications")
}

// Test gap with empty data (morning scenario)
func test_detectGap_growthMorningWithNoTasks_stillGetsGap() {
    let morning = Calendar.current.date(bySettingHour: 7, minute: 0, ...)!
    let result = IntentionEvaluationService.detectGap(
        intention: .growth, tasks: [], focusBlocks: [], now: morning
    )
    // Question: Should this return .noLearningTask (it's 7 AM!) or nil (too early)?
    // Current behavior: .noLearningTask (wrong semantic)
}
```

---

## Recommendations

### CRITICAL — Must Fix Before Release

1. **Fix FOKUS Logic to match spec (Block exists OR 70% completion)**
   ```swift
   case .fokus:
       let hasBlocks = !focusBlocksToday(focusBlocks, now: now).isEmpty
       let blockCompletion = focusBlocksToday(focusBlocks, now: now)
           .allSatisfy { block in
               let ratio = Double(block.completedTaskIDs.count) / Double(max(1, block.taskIDs.count))
               return ratio >= 0.70
           }
       return hasBlocks || blockCompletion
   ```

2. **Validate and fix window scheduling**
   ```swift
   guard settings.coachNudgeWindowStartHour < settings.coachNudgeWindowEndHour else {
       print("⚠️ Coach nudge window is invalid (start >= end)")
       return
   }
   ```
   Then use `max(windowStart, now)` for effective start time.

3. **Add block completion percentage calculation**
   ```swift
   static func calculateBlockCompletion(_ block: FocusBlock) -> Double {
       guard !block.taskIDs.isEmpty else { return 0.0 }
       return Double(block.completedTaskIDs.count) / Double(block.taskIDs.count)
   }
   ```

### HIGH — Fix Before Users See

4. **Fix BHAG gap logic to not return same case twice**
   - Return different gap when blocks exist but morning vs. no blocks

5. **Fix gap detection morning scenario**
   - Don't call with empty data, or use different placeholder gap

6. **Add settings validation UI**
   - DatePicker should prevent start >= end
   - Show warning if window is in past

### MEDIUM — Nice to Have

7. **Remove nonisolated(unsafe) annotation**
   - Keep dailyNudgePrefix inside enum without unsafe marker

8. **Make afternoon check timezone-explicit**
   - Document that 13:00 is hardcoded as "afternoon"

---

## Conclusion

**Status: FAILED** 

The implementation has 3 critical bugs that violate the specification:
1. FOKUS fulfillment uses AND when spec requires OR
2. Window scheduling fails silently for evening users
3. Block completion percentage not implemented per spec

These bugs are **not caught by the unit tests** because the tests don't validate the spec correctly — they validate the implementation instead.

**Recommendation: Block release. Fix bugs 1-3 and add unit tests that explicitly test spec requirements.**

---

*Report generated: 2026-03-12 | Validation performed by Claude Code Validation Agent*
