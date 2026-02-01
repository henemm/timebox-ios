//
//  ContentView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - Focused Values for Keyboard Commands

struct TaskActionsKey: FocusedValueKey {
    typealias Value = TaskActions
}

extension FocusedValues {
    var taskActions: TaskActions? {
        get { self[TaskActionsKey.self] }
        set { self[TaskActionsKey.self] = newValue }
    }
}

struct TaskActions {
    let focusNewTask: () -> Void
    let completeSelected: () -> Void
    let editSelected: () -> Void
    let deleteSelected: () -> Void
    let hasSelection: Bool
}

// MARK: - Content View (Three-Column Layout)

struct ContentView: View {
    @Query(sort: \LocalTask.createdAt, order: .reverse)
    private var tasks: [LocalTask]

    @Environment(\.modelContext) private var modelContext

    // Three-column state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selectedTasks: Set<UUID> = []

    // Quick Add
    @State private var newTaskTitle = ""

    // Computed properties for sidebar badges
    private var tbdCount: Int {
        tasks.filter { $0.isTbd && !$0.isCompleted }.count
    }

    private var nextUpCount: Int {
        tasks.filter { $0.isNextUp && !$0.isCompleted }.count
    }

    // Filtered tasks based on sidebar selection
    private var filteredTasks: [LocalTask] {
        let incomplete = tasks.filter { !$0.isCompleted }

        switch selectedFilter {
        case .all:
            return incomplete
        case .category(let category):
            return incomplete.filter { $0.taskType == category }
        case .nextUp:
            return incomplete.filter { $0.isNextUp }
        case .tbd:
            return incomplete.filter { $0.isTbd }
        }
    }

    // Selected task for inspector (single selection)
    private var selectedTask: LocalTask? {
        guard selectedTasks.count == 1,
              let taskId = selectedTasks.first else { return nil }
        return tasks.first { $0.uuid == taskId }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Category Filter
            SidebarView(
                selectedFilter: $selectedFilter,
                tbdCount: tbdCount,
                nextUpCount: nextUpCount
            )
        } content: {
            // Main: Task List
            taskListView
        } detail: {
            // Inspector: Task Details
            inspectorView
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Task List View

    private var taskListView: some View {
        VStack(spacing: 0) {
            // Quick Add Bar
            HStack {
                TextField("Neuer Task...", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newTaskTextField")
                    .onSubmit { addTask() }

                Button {
                    addTask()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newTaskTitle.isEmpty)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .accessibilityIdentifier("addTaskButton")
            }
            .padding()

            Divider()

            // Task List with Multi-Selection
            List(selection: $selectedTasks) {
                ForEach(filteredTasks, id: \.uuid) { task in
                    MacBacklogRow(
                        task: task,
                        onToggleComplete: {
                            task.isCompleted.toggle()
                            try? modelContext.save()
                        },
                        onImportanceCycle: { newValue in
                            task.importance = newValue
                            try? modelContext.save()
                        },
                        onUrgencyToggle: { newValue in
                            task.urgency = newValue
                            try? modelContext.save()
                        },
                        onCategoryTap: {
                            // Cycle through categories
                            let categories = ["income", "maintenance", "recharge", "learning", "giving_back",
                                              "deep_work", "shallow_work", "meetings", "creative", "strategic"]
                            if let currentIndex = categories.firstIndex(of: task.taskType) {
                                let nextIndex = (currentIndex + 1) % categories.count
                                task.taskType = categories[nextIndex]
                            } else {
                                task.taskType = categories[0]
                            }
                            try? modelContext.save()
                        },
                        onDurationTap: {
                            // Cycle through duration presets
                            let presets = [15, 30, 45, 60, 90, 120]
                            if let current = task.estimatedDuration,
                               let currentIndex = presets.firstIndex(of: current) {
                                let nextIndex = (currentIndex + 1) % presets.count
                                task.estimatedDuration = presets[nextIndex]
                            } else {
                                task.estimatedDuration = presets[0]
                            }
                            try? modelContext.save()
                        }
                    )
                    .tag(task.uuid)
                }
                .onDelete(perform: deleteTasks)
            }
            .contextMenu(forSelectionType: UUID.self) { selection in
                if !selection.isEmpty {
                    Button("Als erledigt markieren") {
                        markTasksCompleted(selection)
                    }

                    Divider()

                    Menu("Kategorie setzen") {
                        Button("Geld verdienen") { setCategory("income", for: selection) }
                        Button("Pflege") { setCategory("maintenance", for: selection) }
                        Button("Energie") { setCategory("recharge", for: selection) }
                        Button("Lernen") { setCategory("learning", for: selection) }
                        Button("Weitergeben") { setCategory("giving_back", for: selection) }
                        Divider()
                        Button("Deep Work") { setCategory("deep_work", for: selection) }
                        Button("Shallow Work") { setCategory("shallow_work", for: selection) }
                        Button("Meetings") { setCategory("meetings", for: selection) }
                        Button("Kreativ") { setCategory("creative", for: selection) }
                        Button("Strategie") { setCategory("strategic", for: selection) }
                    }

                    Button("Zu Next Up hinzufügen") {
                        addToNextUp(selection)
                    }

                    Divider()

                    Button("Löschen", role: .destructive) {
                        deleteTasksByIds(selection)
                    }
                }
            } primaryAction: { selection in
                // Double-click opens inspector (already selected)
            }
        }
        .navigationTitle(filterTitle)
        .toolbar {
            ToolbarItem {
                Text("\(filteredTasks.count) Tasks")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .all: return "Alle Tasks"
        case .category(let cat): return categoryName(cat)
        case .nextUp: return "Next Up"
        case .tbd: return "TBD"
        }
    }

    private func categoryName(_ category: String) -> String {
        switch category {
        case "income": return "Geld verdienen"
        case "maintenance": return "Pflege"
        case "recharge": return "Energie"
        case "learning": return "Lernen"
        case "giving_back": return "Weitergeben"
        default: return category
        }
    }

    // MARK: - Inspector View

    @ViewBuilder
    private var inspectorView: some View {
        if selectedTasks.count > 1 {
            // Multi-selection view
            TaskInspectorMultiSelection(
                count: selectedTasks.count,
                onSetCategory: { category in
                    setCategory(category, for: selectedTasks)
                },
                onDelete: {
                    deleteTasksByIds(selectedTasks)
                }
            )
        } else if let task = selectedTask {
            // Single task inspector
            TaskInspector(task: task) {
                modelContext.delete(task)
                selectedTasks.removeAll()
            }
        } else {
            // Empty state
            TaskInspectorEmptyState()
        }
    }

    // MARK: - Keyboard Actions

    func focusNewTaskField() {
        // Native TextField handles focus automatically
        // Could be enhanced with NSApp.keyWindow?.makeFirstResponder
    }

    func completeSelectedTasks() {
        markTasksCompleted(selectedTasks)
    }

    func deleteSelectedTasks() {
        deleteTasksByIds(selectedTasks)
    }

    // MARK: - Task Actions

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let task = LocalTask(title: newTaskTitle)
        modelContext.insert(task)
        try? modelContext.save()
        newTaskTitle = ""
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTasks[index])
        }
        try? modelContext.save()
    }

    private func deleteTasksByIds(_ ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                modelContext.delete(task)
            }
        }
        try? modelContext.save()
        selectedTasks.removeAll()
    }

    private func markTasksCompleted(_ ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                task.isCompleted = true
            }
        }
        try? modelContext.save()
    }

    private func setCategory(_ category: String, for ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                task.taskType = category
            }
        }
        try? modelContext.save()
    }

    private func addToNextUp(_ ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                task.isNextUp = true
            }
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
}
