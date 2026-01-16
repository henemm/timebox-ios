# Specification: Task System v2.0 - Phase 1 (Data Model & Enhanced Input)

**Feature ID:** task-system-v2-phase1
**Type:** Data Model Extension + UI Enhancement
**Created:** 2026-01-16
**Status:** In Progress
**Phase:** 1 of 3

---

## Purpose

Enable comprehensive task metadata capture for Eisenhower Matrix planning, focus block execution, and future external system synchronization.

**Problem:**
- LocalTask lacks fields for urgency (separate from priority), task categorization by type, and sync metadata
- CreateTaskView doesn't capture duration (required for focus block planning)
- No recurring task support
- No description field for task details
- Data model not ready for Notion/Todoist integration

**Solution:**
- Extend LocalTask with 6 new fields: urgency, taskType, isRecurring, description, externalID, sourceSystem
- Update TaskSourceData protocol to expose new fields
- Enhance CreateTaskView with Duration picker, Task Type selector, Urgency toggle, Recurring toggle, Description editor
- Update LocalTaskSource CRUD operations to handle new fields

---

## Scope

### Phase 1 (This Spec)
**Goal:** Data model foundation + enhanced task input

| File | Change | LoC |
|------|--------|-----|
| `Sources/Models/LocalTask.swift` | Add 6 fields, update init() | +30 |
| `Sources/Protocols/TaskSource.swift` | Extend TaskSourceData protocol | +45 |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Update createTask(), updateTask() | +55 |
| `Sources/Views/TaskCreation/CreateTaskView.swift` | Add 5 UI sections (Duration, Type, Urgency, Recurring, Description) | +125 |
| `TimeBoxTests/LocalTaskTests.swift` | Add tests for new fields | +35 |
| `TimeBoxTests/TaskSourceTests.swift` | Update protocol conformance tests | +30 |

**Total:** 6 files, ~320 LoC

### Dependencies
- **Upstream:** None (foundational phase)
- **Downstream:** Phase 2 (Eisenhower Matrix needs urgency field), Phase 3 (Review needs recurring flag), Phase 4 (Sync needs externalID/sourceSystem)

**Out of Scope (Phase 1):**
- ❌ Eisenhower Matrix UI (Phase 2)
- ❌ Filtering/Sorting BacklogView (Phase 2)
- ❌ Focus block buffer validation (Phase 3)
- ❌ Notion/Todoist connectors (Phase 4)

---

## Implementation Details

### 1. LocalTask Model Extensions

**File:** `Sources/Models/LocalTask.swift`

```swift
import Foundation
import SwiftData

@Model
final class LocalTask {
    // EXISTING FIELDS (unchanged)
    var uuid: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var priority: Int = 0
    var category: String?
    var categoryColorHex: String?
    var dueDate: Date?
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var manualDuration: Int?  // RENAME candidate: just "duration"?

    // NEW FIELDS (Phase 1)
    var urgency: String = "not_urgent"              // "urgent" | "not_urgent"
    var taskType: String = "maintenance"            // "income" | "maintenance" | "recharge"
    var isRecurring: Bool = false
    var taskDescription: String?                    // Note: "description" conflicts with protocol
    var externalID: String?                         // Notion page ID, Todoist task ID, etc.
    var sourceSystem: String = "local"              // "local" | "notion" | "todoist"

    // COMPUTED (TaskSourceData conformance)
    var id: String { uuid.uuidString }

    init(
        uuid: UUID = UUID(),
        title: String,
        priority: Int,
        isCompleted: Bool = false,
        category: String? = nil,
        categoryColorHex: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        manualDuration: Int? = nil,
        urgency: String = "not_urgent",
        taskType: String = "maintenance",
        isRecurring: Bool = false,
        taskDescription: String? = nil,
        externalID: String? = nil,
        sourceSystem: String = "local"
    ) {
        self.uuid = uuid
        self.title = title
        self.priority = priority
        self.isCompleted = isCompleted
        self.category = category
        self.categoryColorHex = categoryColorHex
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.manualDuration = manualDuration
        self.urgency = urgency
        self.taskType = taskType
        self.isRecurring = isRecurring
        self.taskDescription = taskDescription
        self.externalID = externalID
        self.sourceSystem = sourceSystem
    }
}

// MARK: - TaskSourceData Conformance
extension LocalTask: TaskSourceData {
    var categoryTitle: String? { category }
}
```

---

### 2. TaskSource Protocol Extensions

**File:** `Sources/Protocols/TaskSource.swift`

```swift
// EXTEND TaskSourceData protocol
protocol TaskSourceData {
    var id: String { get }
    var title: String { get }
    var isCompleted: Bool { get }
    var priority: Int { get }
    var categoryTitle: String? { get }
    var categoryColorHex: String? { get }
    var dueDate: Date? { get }

    // NEW in Phase 1
    var urgency: String { get }                 // "urgent" | "not_urgent"
    var taskType: String { get }                // "income" | "maintenance" | "recharge"
    var isRecurring: Bool { get }
    var taskDescription: String? { get }
    var externalID: String? { get }
    var sourceSystem: String { get }
}

// EXTEND TaskSourceWritable.createTask()
protocol TaskSourceWritable: TaskSource {
    func createTask(
        title: String,
        category: String?,
        dueDate: Date?,
        priority: Int,
        // NEW parameters
        duration: Int?,
        urgency: String,
        taskType: String,
        isRecurring: Bool,
        description: String?
    ) async throws -> TaskData

    func updateTask(
        taskID: String,
        title: String?,
        category: String?,
        dueDate: Date?,
        priority: Int?,
        // NEW parameters
        duration: Int?,
        urgency: String?,
        taskType: String?,
        isRecurring: Bool?,
        description: String?
    ) async throws
}
```

---

### 3. LocalTaskSource CRUD Updates

**File:** `Sources/Services/TaskSources/LocalTaskSource.swift`

```swift
func createTask(
    title: String,
    category: String?,
    dueDate: Date?,
    priority: Int,
    duration: Int?,
    urgency: String = "not_urgent",
    taskType: String = "maintenance",
    isRecurring: Bool = false,
    description: String? = nil
) async throws -> LocalTask {
    let maxOrder = (try? modelContext.fetch(FetchDescriptor<LocalTask>())
        .map(\.sortOrder).max()) ?? 0

    let task = LocalTask(
        title: title,
        priority: priority,
        category: category,
        dueDate: dueDate,
        sortOrder: maxOrder + 1,
        manualDuration: duration,
        urgency: urgency,
        taskType: taskType,
        isRecurring: isRecurring,
        taskDescription: description,
        sourceSystem: "local"  // Always local for LocalTaskSource
    )

    modelContext.insert(task)
    try modelContext.save()
    return task
}

func updateTask(
    taskID: String,
    title: String?,
    category: String?,
    dueDate: Date?,
    priority: Int?,
    duration: Int?,
    urgency: String?,
    taskType: String?,
    isRecurring: Bool?,
    description: String?
) async throws {
    guard let uuid = UUID(uuidString: taskID) else {
        throw TaskSourceError.invalidTaskID
    }

    let descriptor = FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.uuid == uuid }
    )

    guard let task = try modelContext.fetch(descriptor).first else {
        throw TaskSourceError.taskNotFound
    }

    if let title = title { task.title = title }
    if let category = category { task.category = category }
    if let dueDate = dueDate { task.dueDate = dueDate }
    if let priority = priority { task.priority = priority }
    if let duration = duration { task.manualDuration = duration }
    if let urgency = urgency { task.urgency = urgency }
    if let taskType = taskType { task.taskType = taskType }
    if let isRecurring = isRecurring { task.isRecurring = isRecurring }
    if let description = description { task.taskDescription = description }

    try modelContext.save()
}
```

---

### 4. CreateTaskView UI Enhancements

**File:** `Sources/Views/TaskCreation/CreateTaskView.swift`

```swift
struct CreateTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority = 0

    // NEW: Phase 1 fields
    @State private var duration: Int = 15                    // Default 15min
    @State private var urgency: String = "not_urgent"
    @State private var taskType: String = "maintenance"
    @State private var isRecurring: Bool = false
    @State private var description: String = ""

    @State private var isSaving = false

    var onSave: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                // EXISTING: Title
                Section {
                    TextField("Task-Titel", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                // NEW: Duration (required field)
                Section {
                    Stepper("Dauer: \(duration) min", value: $duration, in: 5...240, step: 5)
                } header: {
                    Text("Zeitbedarf")
                } footer: {
                    Text("Geschätzte Dauer für diese Aufgabe")
                }

                // EXISTING: Priority
                Section {
                    Picker("Priorität", selection: $priority) {
                        Text("Keine").tag(0)
                        Text("Niedrig").tag(1)
                        Text("Mittel").tag(2)
                        Text("Hoch").tag(3)
                    }
                }

                // NEW: Urgency (Eisenhower Matrix)
                Section {
                    Picker("Dringlichkeit", selection: $urgency) {
                        Text("Nicht dringend").tag("not_urgent")
                        Text("Dringend").tag("urgent")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Dringlichkeit")
                } footer: {
                    Text("Dringend = Deadline oder zeitkritisch")
                }

                // NEW: Task Type
                Section {
                    Picker("Aufgabentyp", selection: $taskType) {
                        Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
                        Label("Schneeschaufeln", systemImage: "wrench.and.screwdriver").tag("maintenance")
                        Label("Energie aufladen", systemImage: "battery.100").tag("recharge")
                    }
                } header: {
                    Text("Kategorie")
                }

                // EXISTING: Category (free-form)
                Section {
                    TextField("Kategorie (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Z.B. 'Hausarbeit', 'Recherche', 'Besorgungen'")
                }

                // EXISTING: Due Date
                Section {
                    Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // NEW: Recurring
                Section {
                    Toggle("Wiederkehrende Aufgabe", isOn: $isRecurring)
                } footer: {
                    Text("Aufgabe bleibt nach Abschluss im Backlog")
                }

                // NEW: Description
                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Notizen zur Aufgabe...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Beschreibung (optional)")
                }
            }
            .navigationTitle("Neuer Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveTask()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveTask() {
        guard !title.isEmpty else { return }
        isSaving = true

        let taskSource = LocalTaskSource(modelContext: modelContext)
        Task {
            do {
                _ = try await taskSource.createTask(
                    title: title,
                    category: category.isEmpty ? nil : category,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: priority,
                    duration: duration,
                    urgency: urgency,
                    taskType: taskType,
                    isRecurring: isRecurring,
                    description: description.isEmpty ? nil : description
                )
                await MainActor.run {
                    onSave?()
                    dismiss()
                }
            } catch {
                print("Error saving task: \(error)")
                isSaving = false
            }
        }
    }
}
```

---

## Expected Behavior

### Task Creation Flow
1. User taps "+" in BacklogView
2. CreateTaskView sheet opens
3. User enters:
   - Title (required)
   - Duration via stepper (default 15min)
   - Priority picker (default "Keine")
   - Urgency segmented control (default "Nicht dringend")
   - Task Type picker (default "Schneeschaufeln")
   - Category text field (optional)
   - Due Date toggle + picker (optional)
   - Recurring toggle (default off)
   - Description text editor (optional)
4. User taps "Speichern"
5. Task persists to SwiftData with all fields
6. BacklogView refreshes, new task appears at top

### Validation Rules
- **Required:** title (non-empty string), duration (5-240 min)
- **Optional:** category, dueDate, description, externalID
- **Defaults:** priority=0, urgency="not_urgent", taskType="maintenance", isRecurring=false, sourceSystem="local"

### Data Persistence
- All new fields stored in SwiftData
- CloudKit sync enabled (if configured in ModelContainer)
- Fields backward-compatible (existing tasks get default values)

---

## Acceptance Criteria

### Data Model
- [ ] LocalTask has 6 new fields: urgency, taskType, isRecurring, taskDescription, externalID, sourceSystem
- [ ] All new fields have sensible defaults (non-nullable except description/externalID)
- [ ] Existing tasks still load correctly (backward compatibility)

### Protocol Layer
- [ ] TaskSourceData protocol exposes all 6 new fields
- [ ] TaskSourceWritable.createTask() accepts new parameters
- [ ] TaskSourceWritable.updateTask() accepts new parameters
- [ ] LocalTask conforms to updated TaskSourceData protocol

### UI Layer
- [ ] CreateTaskView has 5 new UI sections (Duration, Urgency, Task Type, Recurring, Description)
- [ ] Duration stepper works (5-240min, step 5)
- [ ] Urgency segmented control toggles "urgent"/"not_urgent"
- [ ] Task Type picker shows 3 options with icons
- [ ] Recurring toggle functional
- [ ] Description TextEditor expands/scrolls

### Integration
- [ ] Task created with all fields → persists to SwiftData correctly
- [ ] Task appears in BacklogView with correct sortOrder
- [ ] All unit tests pass (LocalTaskTests, TaskSourceTests)

### Backward Compatibility
- [ ] Existing tasks without new fields load with defaults
- [ ] No migration errors in SwiftData
- [ ] CloudKit sync unaffected (new fields sync correctly)

---

## Testing Strategy

See [tests.md](./tests.md) for detailed test definitions.

**TDD Approach:**
1. Write failing tests first (RED)
2. Implement features (GREEN)
3. Refactor for clarity (REFACTOR)

**Test Coverage:**
- Unit Tests: LocalTaskTests, TaskSourceTests
- Integration Tests: Task creation end-to-end
- Manual Validation: Create task with all 11 fields, verify SwiftData persistence

---

## Migration Notes

**Backward Compatibility:**
- Existing LocalTask instances automatically get default values for new fields
- SwiftData handles schema migration automatically
- No manual migration script needed

**CloudKit Sync:**
- New fields sync to iCloud automatically
- Devices without latest app version see tasks with default values
- No conflict resolution needed (defaults are sensible)

---

## Known Limitations

- Task Type is limited to 3 predefined values (Income, Maintenance, Recharge) - no custom types in Phase 1
- Recurring tasks don't auto-create copies yet (implementation in future phase)
- External sync (Notion/Todoist) not implemented (Phase 4)
- Urgency and Priority are separate fields (Eisenhower logic in Phase 2)

---

## References

- Main Plan: `/Users/hem/.claude/plans/immutable-yawning-moonbeam.md`
- User Requirement: `requests/create_task_input_flow.md`
- User Requirement: `requests/task_data_integrity_and_sync.md` (sync fields)
- Existing Implementation: `Sources/Models/LocalTask.swift`
- Existing Implementation: `Sources/Views/TaskCreation/CreateTaskView.swift`
