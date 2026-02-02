---
entity_id: MAC-013
type: feature
created: 2026-01-31
status: done
workflow: macos-backlog-view
---

# MAC-013: Backlog View

- [ ] Approved for implementation

## Purpose

Backlog-Ansicht optimiert für den großen Bildschirm mit Drei-Spalten-Layout, Kategorien-Filter in der Sidebar und Multi-Selection für Bulk-Aktionen.

## Scope

**Files:**
- `FocusBloxMac/ContentView.swift` (MAJOR MODIFY)
- `FocusBloxMac/MacBacklogRow.swift` (CREATE)
- `FocusBloxMac/TaskInspector.swift` (CREATE)

**Estimated:** +200 / -30 LoC

## Implementation Details

### 1. Three-Column Layout

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    // Sidebar: Category Filter
    SidebarView()
} content: {
    // Main: Task List
    TaskListView(filter: selectedCategory)
} detail: {
    // Inspector: Task Details
    TaskInspector(task: selectedTask)
}
```

### 2. Sidebar mit Kategorien-Filter

```swift
struct SidebarView: View {
    @Binding var selectedCategory: String?

    var body: some View {
        List(selection: $selectedCategory) {
            Section("Kategorien") {
                Label("Alle", systemImage: "tray.full")
                    .tag(nil as String?)
                Label("Geld verdienen", systemImage: "dollarsign.circle")
                    .tag("income")
                Label("Pflege", systemImage: "wrench.and.screwdriver")
                    .tag("maintenance")
                // ... weitere Kategorien
            }

            Section("Status") {
                Label("Next Up", systemImage: "arrow.up.circle")
                Label("TBD", systemImage: "questionmark.circle")
            }
        }
        .listStyle(.sidebar)
    }
}
```

### 3. Multi-Selection

```swift
@State private var selectedTasks: Set<UUID> = []

List(selection: $selectedTasks) {
    ForEach(filteredTasks, id: \.uuid) { task in
        MacBacklogRow(task: task)
            .tag(task.uuid)
    }
}
.contextMenu(forSelectionType: UUID.self) { selection in
    if selection.count > 1 {
        Button("Set Category...") { ... }
        Button("Delete \(selection.count) Tasks", role: .destructive) { ... }
    }
}
```

### 4. MacBacklogRow (kompakter als iOS)

```swift
struct MacBacklogRow: View {
    let task: LocalTask

    var body: some View {
        HStack(spacing: 8) {
            // Completion Circle
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")

            // Title + Duration
            VStack(alignment: .leading) {
                Text(task.title)
                    .lineLimit(1)
                if let duration = task.estimatedDuration {
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Category Badge
            CategoryBadge(taskType: task.taskType)

            // TBD Indicator
            if task.isTbd {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
            }
        }
    }
}
```

### 5. TaskInspector (Detail Panel)

```swift
struct TaskInspector: View {
    @Bindable var task: LocalTask

    var body: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $task.title)
            }

            Section("Details") {
                Picker("Importance", selection: $task.importance) { ... }
                Picker("Urgency", selection: urgencyBinding) { ... }
                Stepper("Duration: \(task.estimatedDuration ?? 15) min",
                        value: durationBinding, in: 5...120, step: 5)
            }

            Section("Category") {
                Picker("Type", selection: $task.taskType) { ... }
            }

            Section {
                Button("Delete Task", role: .destructive) { ... }
            }
        }
        .formStyle(.grouped)
    }
}
```

## Test Plan

### Build Verification (TDD RED)

Da macOS keine UI Test-Infrastruktur hat, verwenden wir Build-Tests:

- [ ] Test 1: `NavigationSplitView` mit 3 Spalten vorhanden
- [ ] Test 2: `selectedTasks` als `Set<UUID>` (Multi-Select)
- [ ] Test 3: macOS Build kompiliert
- [ ] Test 4: iOS Build keine Regression

### Manual Verification (nach Implementation)

- [ ] Sidebar zeigt Kategorien
- [ ] Klick auf Kategorie filtert Liste
- [ ] ⌘-Klick ermöglicht Multi-Selection
- [ ] Rechtsklick auf Selection zeigt Bulk Actions
- [ ] Inspector zeigt Task-Details
- [ ] Änderungen im Inspector speichern sofort

## Acceptance Criteria

- [ ] Drei-Spalten-Layout (Sidebar + List + Inspector)
- [ ] Kategorien in Sidebar filterbar
- [ ] Multi-Select mit ⌘-Click funktioniert
- [ ] Bulk-Aktionen (Kategorie setzen, löschen)
- [ ] macOS und iOS Builds erfolgreich

## Dependencies

- MAC-001: App Foundation ✅
- MAC-012: Keyboard Navigation ✅

## Out of Scope

- Drag & Drop (MAC-020)
- View Mode Switcher (komplexer als Sidebar)
- Sortierung via Table Headers
