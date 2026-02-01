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

    // EventKit for Reminders sync
    private let eventKitRepo = EventKitRepository()

    // Navigation state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSection: MainSection = .backlog
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selectedTasks: Set<UUID> = []

    // Sync state
    @State private var isSyncing = false
    @State private var syncError: String?

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
            // Sidebar: Navigation + Filters
            SidebarView(
                selectedSection: $selectedSection,
                selectedFilter: $selectedFilter,
                tbdCount: tbdCount,
                nextUpCount: nextUpCount
            )
        } content: {
            // Main Content based on selected section
            mainContentView
        } detail: {
            // Inspector: Task Details (only for Backlog)
            if selectedSection == .backlog {
                inspectorView
            } else {
                EmptyView()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
    }

    // MARK: - Main Content View (switches based on section)

    @ViewBuilder
    private var mainContentView: some View {
        switch selectedSection {
        case .backlog:
            backlogView
        case .planning:
            MacPlanningView()
        case .review:
            MacReviewView()
        }
    }

    // MARK: - Backlog View

    private var backlogView: some View {
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
                        onCategorySelect: { category in
                            task.taskType = category
                            try? modelContext.save()
                        },
                        onDurationSelect: { duration in
                            task.estimatedDuration = duration
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
                // Sync status indicator
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .accessibilityIdentifier("syncStatusIndicator")
                } else {
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("syncStatusIndicator")
                }
            }

            ToolbarItem {
                Button {
                    Task { await syncWithReminders() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .disabled(isSyncing)
                .accessibilityIdentifier("syncRemindersButton")
                .help("Mit Apple Erinnerungen synchronisieren")
            }

            ToolbarItem {
                Text("\(filteredTasks.count) Tasks")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            // Sync on appear if enabled
            await syncWithReminders()
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
    }

    func completeSelectedTasks() {
        markTasksCompleted(selectedTasks)
    }

    func deleteSelectedTasks() {
        deleteTasksByIds(selectedTasks)
    }

    // MARK: - Sync Actions

    private func syncWithReminders() async {
        // Default to enabled if not set
        if !UserDefaults.standard.bool(forKey: "remindersSyncEnabledSet") {
            UserDefaults.standard.set(true, forKey: "remindersSyncEnabled")
            UserDefaults.standard.set(true, forKey: "remindersSyncEnabledSet")
        }

        guard UserDefaults.standard.bool(forKey: "remindersSyncEnabled") else { return }

        isSyncing = true
        syncError = nil

        do {
            // Request access if needed
            let hasAccess = try await eventKitRepo.requestReminderAccess()
            guard hasAccess else {
                syncError = "Kein Zugriff auf Erinnerungen"
                isSyncing = false
                return
            }

            // Import from Reminders
            let syncService = RemindersSyncService(
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            _ = try await syncService.importFromReminders()
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
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
