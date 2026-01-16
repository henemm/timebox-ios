# Test Definitions: Task System v2.0 - Phase 1

**Feature ID:** task-system-v2-phase1
**Type:** Unit Tests + Integration Tests
**Created:** 2026-01-16
**Status:** In Progress (TDD RED)

---

## Test Strategy

**Approach:** Test-Driven Development (TDD)
1. **RED** - Write failing tests first
2. **GREEN** - Implement minimum code to pass
3. **REFACTOR** - Clean up implementation

**Coverage Goals:**
- Unit Tests: 100% coverage for new LocalTask fields and protocol conformance
- Integration Tests: End-to-end task creation with all fields
- Manual Validation: UI functionality and SwiftData persistence

---

## Unit Tests

### LocalTaskTests.swift (New Tests)

#### Test: New Fields Have Correct Defaults
```swift
func test_localTask_defaultValues() throws {
    let task = LocalTask(title: "Test Task", priority: 0)

    XCTAssertEqual(task.urgency, "not_urgent")
    XCTAssertEqual(task.taskType, "maintenance")
    XCTAssertEqual(task.isRecurring, false)
    XCTAssertNil(task.taskDescription)
    XCTAssertNil(task.externalID)
    XCTAssertEqual(task.sourceSystem, "local")
}
```

#### Test: Urgency Can Be Set
```swift
func test_localTask_urgencyCanBeSet() throws {
    let task = LocalTask(
        title: "Urgent Task",
        priority: 3,
        urgency: "urgent"
    )

    XCTAssertEqual(task.urgency, "urgent")
}
```

#### Test: Task Type Can Be Set
```swift
func test_localTask_taskTypeCanBeSet() throws {
    let taskIncome = LocalTask(title: "Work", priority: 2, taskType: "income")
    let taskMaintenance = LocalTask(title: "Fix", priority: 1, taskType: "maintenance")
    let taskRecharge = LocalTask(title: "Rest", priority: 0, taskType: "recharge")

    XCTAssertEqual(taskIncome.taskType, "income")
    XCTAssertEqual(taskMaintenance.taskType, "maintenance")
    XCTAssertEqual(taskRecharge.taskType, "recharge")
}
```

#### Test: Recurring Flag Can Be Set
```swift
func test_localTask_recurringFlagWorks() throws {
    let recurringTask = LocalTask(
        title: "Weekly Review",
        priority: 2,
        isRecurring: true
    )

    XCTAssertTrue(recurringTask.isRecurring)
}
```

#### Test: Description Can Be Set
```swift
func test_localTask_descriptionCanBeSet() throws {
    let task = LocalTask(
        title: "Research",
        priority: 1,
        taskDescription: "Investigate new frameworks for iOS development"
    )

    XCTAssertEqual(task.taskDescription, "Investigate new frameworks for iOS development")
}
```

#### Test: External ID Can Be Set (For Sync)
```swift
func test_localTask_externalIDCanBeSet() throws {
    let task = LocalTask(
        title: "Synced Task",
        priority: 2,
        externalID: "notion-page-abc123"
    )

    XCTAssertEqual(task.externalID, "notion-page-abc123")
}
```

#### Test: Source System Can Be Set
```swift
func test_localTask_sourceSystemCanBeSet() throws {
    let localTask = LocalTask(title: "Local", priority: 0, sourceSystem: "local")
    let notionTask = LocalTask(title: "Notion", priority: 1, sourceSystem: "notion")

    XCTAssertEqual(localTask.sourceSystem, "local")
    XCTAssertEqual(notionTask.sourceSystem, "notion")
}
```

#### Test: All Fields Can Be Set Together
```swift
func test_localTask_allFieldsCanBeSet() throws {
    let task = LocalTask(
        title: "Complete Task",
        priority: 3,
        category: "Work",
        dueDate: Date(),
        manualDuration: 30,
        urgency: "urgent",
        taskType: "income",
        isRecurring: true,
        taskDescription: "Important work task",
        externalID: "notion-123",
        sourceSystem: "notion"
    )

    XCTAssertEqual(task.title, "Complete Task")
    XCTAssertEqual(task.priority, 3)
    XCTAssertEqual(task.category, "Work")
    XCTAssertEqual(task.manualDuration, 30)
    XCTAssertEqual(task.urgency, "urgent")
    XCTAssertEqual(task.taskType, "income")
    XCTAssertTrue(task.isRecurring)
    XCTAssertEqual(task.taskDescription, "Important work task")
    XCTAssertEqual(task.externalID, "notion-123")
    XCTAssertEqual(task.sourceSystem, "notion")
}
```

---

### TaskSourceTests.swift (Protocol Conformance)

#### Test: TaskSourceData Protocol Exposes New Fields
```swift
func test_taskSourceData_exposesNewFields() throws {
    let task = LocalTask(
        title: "Test",
        priority: 2,
        urgency: "urgent",
        taskType: "income",
        isRecurring: true,
        taskDescription: "Test description"
    )

    let taskData: any TaskSourceData = task

    XCTAssertEqual(taskData.urgency, "urgent")
    XCTAssertEqual(taskData.taskType, "income")
    XCTAssertTrue(taskData.isRecurring)
    XCTAssertEqual(taskData.taskDescription, "Test description")
}
```

#### Test: LocalTask Conforms to Extended TaskSourceData
```swift
func test_localTask_conformsToTaskSourceData() throws {
    let task = LocalTask(title: "Conformance Test", priority: 1)

    XCTAssertTrue(task is TaskSourceData)
    XCTAssertNotNil((task as TaskSourceData).urgency)
    XCTAssertNotNil((task as TaskSourceData).taskType)
}
```

---

### LocalTaskSourceTests.swift (CRUD Operations)

#### Test: Create Task With All Fields
```swift
func test_createTask_withAllFields_succeeds() async throws {
    let container = try ModelContainer(
        for: LocalTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let taskSource = LocalTaskSource(modelContext: context)

    let task = try await taskSource.createTask(
        title: "Full Task",
        category: "Test",
        dueDate: Date(),
        priority: 3,
        duration: 45,
        urgency: "urgent",
        taskType: "income",
        isRecurring: true,
        description: "Comprehensive test task"
    )

    XCTAssertEqual(task.title, "Full Task")
    XCTAssertEqual(task.category, "Test")
    XCTAssertEqual(task.priority, 3)
    XCTAssertEqual(task.manualDuration, 45)
    XCTAssertEqual(task.urgency, "urgent")
    XCTAssertEqual(task.taskType, "income")
    XCTAssertTrue(task.isRecurring)
    XCTAssertEqual(task.taskDescription, "Comprehensive test task")
    XCTAssertEqual(task.sourceSystem, "local")
}
```

#### Test: Create Task With Minimal Fields
```swift
func test_createTask_withMinimalFields_usesDefaults() async throws {
    let container = try ModelContainer(
        for: LocalTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let taskSource = LocalTaskSource(modelContext: context)

    let task = try await taskSource.createTask(
        title: "Minimal Task",
        category: nil,
        dueDate: nil,
        priority: 0,
        duration: nil,
        urgency: "not_urgent",
        taskType: "maintenance",
        isRecurring: false,
        description: nil
    )

    XCTAssertEqual(task.title, "Minimal Task")
    XCTAssertNil(task.category)
    XCTAssertNil(task.dueDate)
    XCTAssertEqual(task.priority, 0)
    XCTAssertNil(task.manualDuration)
    XCTAssertEqual(task.urgency, "not_urgent")
    XCTAssertEqual(task.taskType, "maintenance")
    XCTAssertFalse(task.isRecurring)
    XCTAssertNil(task.taskDescription)
}
```

#### Test: Update Task Updates New Fields
```swift
func test_updateTask_updatesNewFields() async throws {
    let container = try ModelContainer(
        for: LocalTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let taskSource = LocalTaskSource(modelContext: context)

    // Create task
    let task = try await taskSource.createTask(
        title: "Original",
        category: nil,
        dueDate: nil,
        priority: 0,
        duration: 15,
        urgency: "not_urgent",
        taskType: "maintenance",
        isRecurring: false,
        description: nil
    )

    // Update task
    try await taskSource.updateTask(
        taskID: task.id,
        title: "Updated",
        category: nil,
        dueDate: nil,
        priority: 3,
        duration: 30,
        urgency: "urgent",
        taskType: "income",
        isRecurring: true,
        description: "New description"
    )

    // Verify updates
    let descriptor = FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.uuid == task.uuid }
    )
    let updatedTask = try context.fetch(descriptor).first!

    XCTAssertEqual(updatedTask.title, "Updated")
    XCTAssertEqual(updatedTask.priority, 3)
    XCTAssertEqual(updatedTask.manualDuration, 30)
    XCTAssertEqual(updatedTask.urgency, "urgent")
    XCTAssertEqual(updatedTask.taskType, "income")
    XCTAssertTrue(updatedTask.isRecurring)
    XCTAssertEqual(updatedTask.taskDescription, "New description")
}
```

---

## Integration Tests

### End-to-End Task Creation

#### Test Scenario: User Creates Task With All Fields
**Steps:**
1. Open TimeBox app
2. Navigate to Backlog tab
3. Tap "+" button
4. CreateTaskView opens
5. Enter values:
   - Title: "Buy groceries"
   - Duration: 30 min (via stepper)
   - Priority: "Mittel" (tag 2)
   - Urgency: "Dringend" (tap segment)
   - Task Type: "Schneeschaufeln" (maintenance)
   - Category: "Besorgungen"
   - Due Date: Toggle on, select tomorrow 2pm
   - Recurring: Toggle on
   - Description: "Milk, bread, eggs from Rewe"
6. Tap "Speichern"
7. CreateTaskView dismisses
8. Backlog refreshes

**Expected Result:**
- Task appears at top of Backlog list
- Task shows title "Buy groceries"
- Duration badge shows "30min"
- Swipe to edit → all fields retained correctly
- SwiftData query returns task with all 11 fields populated

---

## Manual Validation Checklist

### CreateTaskView UI
- [ ] Title field accepts text input
- [ ] Duration stepper increments by 5 (5, 10, 15, ..., 240)
- [ ] Priority picker shows 4 options (Keine, Niedrig, Mittel, Hoch)
- [ ] Urgency segmented control toggles between "Nicht dringend" and "Dringend"
- [ ] Task Type picker shows 3 options with icons (💰 Geld, 🔧 Schneeschaufeln, 🔋 Energie)
- [ ] Category text field accepts free-form text
- [ ] Due Date toggle shows/hides DatePicker
- [ ] Recurring toggle functional
- [ ] Description TextEditor expands, accepts multi-line text
- [ ] Placeholder text "Notizen zur Aufgabe..." appears when empty
- [ ] "Speichern" button disabled when title empty
- [ ] "Abbrechen" button dismisses sheet without saving

### Data Persistence
- [ ] Task created with title-only → defaults applied correctly
- [ ] Task created with all fields → all values persist
- [ ] App restart → task still exists with correct values
- [ ] CloudKit sync enabled → task syncs to other devices
- [ ] Existing tasks (created before Phase 1) still load correctly

### Backward Compatibility
- [ ] Existing tasks display in Backlog without errors
- [ ] Existing tasks show default values for new fields
- [ ] No SwiftData migration errors in console
- [ ] No CloudKit sync conflicts

---

## Edge Cases

### Test: Empty Description Should Be Stored As Nil
```swift
func test_createTask_emptyDescription_storedAsNil() async throws {
    let task = try await taskSource.createTask(
        title: "Task",
        category: nil,
        dueDate: nil,
        priority: 0,
        duration: 15,
        urgency: "not_urgent",
        taskType: "maintenance",
        isRecurring: false,
        description: ""  // Empty string
    )

    XCTAssertNil(task.taskDescription)  // Should be nil, not empty string
}
```

### Test: Duration Must Be Positive
```swift
func test_createTask_negativeDuration_fails() async throws {
    do {
        _ = try await taskSource.createTask(
            title: "Invalid",
            category: nil,
            dueDate: nil,
            priority: 0,
            duration: -10,  // Invalid
            urgency: "not_urgent",
            taskType: "maintenance",
            isRecurring: false,
            description: nil
        )
        XCTFail("Should throw error for negative duration")
    } catch {
        // Expected
    }
}
```

### Test: Invalid Urgency Value Falls Back To Default
```swift
func test_createTask_invalidUrgency_usesDefault() async throws {
    // Note: In Swift, this would be a compile-time error with enums
    // For string-based approach, add validation in createTask()
}
```

---

## Performance Tests

### Test: Create 100 Tasks Completes Within 2 Seconds
```swift
func test_createManyTasks_performsWell() async throws {
    let startTime = Date()

    for i in 0..<100 {
        _ = try await taskSource.createTask(
            title: "Task \(i)",
            category: nil,
            dueDate: nil,
            priority: 0,
            duration: 15,
            urgency: "not_urgent",
            taskType: "maintenance",
            isRecurring: false,
            description: nil
        )
    }

    let elapsed = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(elapsed, 2.0, "Creating 100 tasks should take < 2 seconds")
}
```

---

## Test Execution Order

1. **TDD RED Phase:**
   - Run all tests (all fail)
   - Verify compilation errors for missing fields

2. **TDD GREEN Phase:**
   - Add fields to LocalTask
   - Extend protocols
   - Update LocalTaskSource
   - Update CreateTaskView
   - Run tests (all pass)

3. **Manual Validation:**
   - Build app
   - Create task with all fields
   - Verify SwiftData persistence
   - Test backward compatibility

---

## Success Criteria

**Phase 1 Tests PASS When:**
- [ ] All LocalTaskTests green (8 new tests)
- [ ] All TaskSourceTests green (2 conformance tests)
- [ ] All LocalTaskSourceTests green (3 CRUD tests)
- [ ] Manual validation checklist 100% complete
- [ ] No SwiftData migration errors
- [ ] No UI layout issues in CreateTaskView
- [ ] Existing tasks load without errors

**Performance Acceptable When:**
- [ ] Task creation < 100ms per task
- [ ] UI responds within 200ms
- [ ] SwiftData fetch < 50ms for 1000 tasks

---

## References

- Spec: [spec.md](./spec.md)
- User Requirement: `requests/create_task_input_flow.md`
- Existing Tests: `TimeBoxTests/LocalTaskTests.swift`
- Existing Tests: `TimeBoxTests/TaskSourceTests.swift`
