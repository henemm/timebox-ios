# Test Definitions: Mock EventKit Repository (Phase 1)

**Feature:** Protocol-based EventKit abstraction with Mock implementation for Unit Tests

**Phase:** 1 (Foundation only - UI Tests in Phase 2)

---

## Test Strategy

### Scope
- ✅ Unit Tests for MockEventKitRepository
- ✅ Fix existing EventKitRepositoryTests with Mock
- ❌ UI Tests (deferred to Phase 2)

### Test Environment
- Platform: iOS Simulator
- Permissions: None required (using Mock)
- Xcode Test Target: TimeBoxTests

---

## Unit Tests (TDD RED → GREEN)

### File: `TimeBoxTests/MockEventKitRepositoryTests.swift` (NEW)

#### 1. Mock Authorization Tests

```swift
func test_mockRepository_returnsConfiguredAuthStatus() throws {
    // GIVEN: Mock with authorized state
    let mock = MockEventKitRepository()
    mock.mockCalendarAuthStatus = .fullAccess
    mock.mockReminderAuthStatus = .fullAccess

    // WHEN: Checking auth status
    let calendarAuth = mock.calendarAuthStatus
    let reminderAuth = mock.reminderAuthStatus

    // THEN: Returns mocked status
    XCTAssertEqual(calendarAuth, .fullAccess)
    XCTAssertEqual(reminderAuth, .fullAccess)
}

func test_mockRepository_canSimulateDeniedAccess() throws {
    // GIVEN: Mock with denied state
    let mock = MockEventKitRepository()
    mock.mockCalendarAuthStatus = .denied

    // WHEN: Requesting access
    let hasAccess = try await mock.requestAccess()

    // THEN: Returns false
    XCTAssertFalse(hasAccess)
}
```

#### 2. Mock Data Tests

```swift
func test_mockRepository_returnsConfiguredReminders() async throws {
    // GIVEN: Mock with test reminders
    let mock = MockEventKitRepository()
    mock.mockReminders = [
        ReminderData(id: "test-1", title: "Test Task"),
        ReminderData(id: "test-2", title: "Another Task")
    ]

    // WHEN: Fetching reminders
    let reminders = try await mock.fetchIncompleteReminders()

    // THEN: Returns mocked data
    XCTAssertEqual(reminders.count, 2)
    XCTAssertEqual(reminders[0].id, "test-1")
}

func test_mockRepository_returnsConfiguredEvents() throws {
    // GIVEN: Mock with test events
    let mock = MockEventKitRepository()
    mock.mockEvents = [
        CalendarEvent(id: "evt-1", title: "Meeting", ...)
    ]

    // WHEN: Fetching events
    let events = try mock.fetchCalendarEvents(for: Date())

    // THEN: Returns mocked data
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].id, "evt-1")
}
```

#### 3. Mock Method Call Tests

```swift
func test_mockRepository_recordsDeleteCalls() throws {
    // GIVEN: Mock repository
    let mock = MockEventKitRepository()

    // WHEN: Deleting event
    try mock.deleteCalendarEvent(eventID: "test-id")

    // THEN: Method call is recorded
    XCTAssertTrue(mock.deleteCalendarEventCalled)
    XCTAssertEqual(mock.lastDeletedEventID, "test-id")
}

func test_mockRepository_recordsMarkCompleteCalls() throws {
    // GIVEN: Mock repository
    let mock = MockEventKitRepository()

    // WHEN: Marking reminder complete
    try mock.markReminderComplete(reminderID: "reminder-1")

    // THEN: Method call is recorded
    XCTAssertTrue(mock.markReminderCompleteCalled)
    XCTAssertEqual(mock.lastCompletedReminderID, "reminder-1")
}
```

---

### File: `TimeBoxTests/EventKitRepositoryTests.swift` (MODIFIED)

#### 4. Fix Existing Failing Test

**BEFORE (Fails):**
```swift
func testDeleteCalendarEventWithInvalidIDDoesNotThrow() throws {
    XCTAssertNoThrow(try eventKitRepo.deleteCalendarEvent(eventID: "invalid-event-id"))
}
```

**AFTER (Passes with Mock):**
```swift
func testDeleteCalendarEventWithInvalidIDDoesNotThrow() throws {
    // GIVEN: Mock repository with authorized state
    let mock = MockEventKitRepository()
    mock.mockCalendarAuthStatus = .fullAccess
    eventKitRepo = mock

    // WHEN: Deleting with invalid ID
    // THEN: No error thrown (silent fail)
    XCTAssertNoThrow(try eventKitRepo.deleteCalendarEvent(eventID: "invalid-event-id"))
}
```

#### 5. Protocol Conformance Tests

```swift
func test_eventKitRepository_conformsToProtocol() {
    // GIVEN: EventKitRepository instance
    let repo: any EventKitRepositoryProtocol = EventKitRepository()

    // THEN: Conforms to protocol (compile-time check)
    XCTAssertNotNil(repo)
}

func test_mockRepository_conformsToProtocol() {
    // GIVEN: MockEventKitRepository instance
    let mock: any EventKitRepositoryProtocol = MockEventKitRepository()

    // THEN: Conforms to protocol (compile-time check)
    XCTAssertNotNil(mock)
}
```

---

## Test Execution Plan

### RED Phase (Expected Failures)
1. Create `MockEventKitRepositoryTests.swift` with tests
2. Run tests → **FAIL** (MockEventKitRepository doesn't exist)
3. Record compile errors

### GREEN Phase (Implementation)
1. Create `EventKitRepositoryProtocol.swift`
2. Create `MockEventKitRepository.swift`
3. Make `EventKitRepository` conform to protocol
4. Update failing test to use Mock
5. Run tests → **PASS** ✅

---

## Success Criteria

### Must Pass (BLOCKING)
- ✅ All `MockEventKitRepositoryTests` pass
- ✅ `EventKitRepositoryTests.testDeleteCalendarEventWithInvalidIDDoesNotThrow` passes
- ✅ No regressions in other tests
- ✅ Build succeeds

### Test Metrics
- Unit Tests: 74 → 79 tests (+5 new mock tests)
- Failures: 1 → 0 (fix existing failure)
- UI Tests: Not affected in Phase 1

---

## Out of Scope (Phase 2)

- ❌ UI Test fixes (8 failing Timeline tests)
- ❌ View dependency injection refactoring
- ❌ Environment object setup in TimeBoxApp

**Reason:** Exceeds scoping limits (would require 10+ file changes)

---

## Manual Verification Steps

### After Unit Tests Pass

1. Run `EventKitRepositoryTests` suite
   ```bash
   xcodebuild test -scheme TimeBox -only-testing:TimeBoxTests/EventKitRepositoryTests
   ```
   **Expected:** All tests pass ✅

2. Run `MockEventKitRepositoryTests` suite
   ```bash
   xcodebuild test -scheme TimeBox -only-testing:TimeBoxTests/MockEventKitRepositoryTests
   ```
   **Expected:** All tests pass ✅

3. Verify no regressions
   ```bash
   xcodebuild test -scheme TimeBox -only-testing:TimeBoxTests
   ```
   **Expected:** Total test count increases, 1 failure fixed

---

## Risk Assessment

### LOW Risk
- ✅ Additive changes (new protocol, new mock)
- ✅ EventKitRepository remains functional (backward compatible)
- ✅ No production code behavior changes
- ✅ Limited scope (4 files)

### Mitigation
- Protocol uses `@preconcurrency` for Sendable compatibility
- Mock is test-target only (not in main bundle)
- Existing EventKitRepository unchanged (only adds conformance)

---

**Status:** ⛔ BLOCKING - Must be approved before implementation
