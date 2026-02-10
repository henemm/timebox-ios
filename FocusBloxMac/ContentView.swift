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

    // Shared state between Planen and Zuweisen tabs
    @State private var sharedDate = Date()
    @State private var highlightedBlockID: String?

    // Sync state
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var hasSynced = false

    // Quick Add
    @State private var newTaskTitle = ""

    // Computed properties for sidebar badges
    private var tbdCount: Int {
        tasks.filter { $0.isTbd && !$0.isCompleted }.count
    }

    private var nextUpCount: Int {
        tasks.filter { $0.isNextUp && !$0.isCompleted }.count
    }

    private var overdueCount: Int {
        let now = Date()
        return tasks.filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else { return false }
            return dueDate < now
        }.count
    }

    private var upcomingCount: Int {
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return tasks.filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else { return false }
            return dueDate >= now && dueDate <= weekFromNow
        }.count
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    // Filtered tasks based on sidebar selection
    private var filteredTasks: [LocalTask] {
        switch selectedFilter {
        case .all:
            return tasks.filter { !$0.isCompleted }
        case .category(let category):
            return tasks.filter { !$0.isCompleted && $0.taskType == category }
        case .nextUp:
            return tasks.filter { !$0.isCompleted && $0.isNextUp }
        case .tbd:
            return tasks.filter { !$0.isCompleted && $0.isTbd }
        case .overdue:
            let now = Date()
            return tasks.filter { task in
                guard !task.isCompleted, let dueDate = task.dueDate else { return false }
                return dueDate < now
            }
        case .upcoming:
            let now = Date()
            let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            return tasks.filter { task in
                guard !task.isCompleted, let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= weekFromNow
            }
        case .completed:
            return tasks.filter { $0.isCompleted }
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
            // Sidebar: Only show filter options when Backlog is selected
            if selectedSection == .backlog {
                SidebarView(
                    selectedFilter: $selectedFilter,
                    tbdCount: tbdCount,
                    nextUpCount: nextUpCount,
                    overdueCount: overdueCount,
                    upcomingCount: upcomingCount,
                    completedCount: completedCount
                )
            } else {
                // Empty sidebar for other sections
                List {
                    Text("Keine Filter")
                        .foregroundStyle(.secondary)
                }
                .listStyle(.sidebar)
                .navigationTitle(selectedSection.rawValue)
            }
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
        .toolbar(id: "mainNavigation") {
            // Main navigation in toolbar
            ToolbarItem(id: "navigationPicker", placement: .principal) {
                Picker("Bereich", selection: $selectedSection) {
                    ForEach(MainSection.allCases, id: \.self) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("mainNavigationPicker")
            }
        }
    }

    // MARK: - Main Content View (switches based on section)

    @ViewBuilder
    private var mainContentView: some View {
        switch selectedSection {
        case .backlog:
            backlogView
        case .planning:
            MacPlanningView(
                selectedDate: $sharedDate,
                onNavigateToBlock: { blockID in
                    highlightedBlockID = blockID
                    selectedSection = .assign
                }
            )
        case .assign:
            MacAssignView(
                selectedDate: $sharedDate,
                highlightedBlockID: $highlightedBlockID
            )
        case .focus:
            MacFocusView()
        case .review:
            MacReviewView()
        }
    }

    // MARK: - Backlog View

    // Next Up tasks (sorted by nextUpSortOrder)
    private var nextUpTasks: [LocalTask] {
        tasks.filter { $0.isNextUp && !$0.isCompleted }
            .sorted { ($0.nextUpSortOrder ?? Int.max) < ($1.nextUpSortOrder ?? Int.max) }
    }

    // Regular tasks (non-Next Up, filtered)
    private var regularFilteredTasks: [LocalTask] {
        switch selectedFilter {
        case .all:
            return tasks.filter { !$0.isCompleted && !$0.isNextUp }
        case .category(let category):
            return tasks.filter { !$0.isCompleted && !$0.isNextUp && $0.taskType == category }
        case .nextUp:
            return []  // Next Up section handles this
        case .tbd:
            return tasks.filter { !$0.isCompleted && !$0.isNextUp && $0.isTbd }
        case .overdue:
            let now = Date()
            return tasks.filter { task in
                guard !task.isCompleted && !task.isNextUp, let dueDate = task.dueDate else { return false }
                return dueDate < now
            }
        case .upcoming:
            let now = Date()
            let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            return tasks.filter { task in
                guard !task.isCompleted && !task.isNextUp, let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= weekFromNow
            }
        case .completed:
            return tasks.filter { $0.isCompleted }
        }
    }

    // Show Next Up section only in "All" filter
    private var showNextUpSection: Bool {
        selectedFilter == .all && !nextUpTasks.isEmpty
    }

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

            // Task List with Multi-Selection and Sections
            List(selection: $selectedTasks) {
                // MARK: Next Up Section (only in "All" filter)
                if showNextUpSection {
                    Section {
                        ForEach(nextUpTasks, id: \.uuid) { task in
                            makeBacklogRow(task: task)
                                .tag(task.uuid)
                        }
                        .onMove { from, to in
                            moveNextUpTasks(from: from, to: to)
                        }
                    } header: {
                        HStack {
                            Label("Next Up", systemImage: "arrow.up.circle.fill")
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("\(nextUpTasks.count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }

                // MARK: Regular Tasks Section
                Section {
                    ForEach(selectedFilter == .nextUp ? nextUpTasks : regularFilteredTasks, id: \.uuid) { task in
                        makeBacklogRow(task: task)
                            .tag(task.uuid)
                    }
                    .onMove { from, to in
                        moveRegularTasks(from: from, to: to)
                    }
                    .onDelete(perform: deleteTasks)
                } header: {
                    if showNextUpSection {
                        Text("Backlog")
                    }
                }
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

                    Button("Aus Next Up entfernen") {
                        removeFromNextUp(selection)
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
            // Sync only once per app start (not on every tab switch)
            guard !hasSynced else { return }
            hasSynced = true
            await syncWithReminders()
        }
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .all: return "Alle Tasks"
        case .category(let cat): return categoryName(cat)
        case .nextUp: return "Next Up"
        case .tbd: return "TBD"
        case .overdue: return "Überfällig"
        case .upcoming: return "Bald fällig"
        case .completed: return "Erledigt"
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
        let tasksToDelete = selectedFilter == .nextUp ? nextUpTasks : regularFilteredTasks
        for index in offsets {
            if index < tasksToDelete.count {
                modelContext.delete(tasksToDelete[index])
            }
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
        let maxOrder = nextUpTasks.compactMap(\.nextUpSortOrder).max() ?? 0
        var order = maxOrder + 1
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                task.isNextUp = true
                task.nextUpSortOrder = order
                order += 1
            }
        }
        try? modelContext.save()
    }

    private func removeFromNextUp(_ ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                task.isNextUp = false
                task.nextUpSortOrder = nil
            }
        }
        try? modelContext.save()
    }

    // MARK: - Drag Reorder

    private func moveNextUpTasks(from source: IndexSet, to destination: Int) {
        var orderedTasks = nextUpTasks
        orderedTasks.move(fromOffsets: source, toOffset: destination)

        // Update sort order
        for (index, task) in orderedTasks.enumerated() {
            task.nextUpSortOrder = index
        }
        try? modelContext.save()
    }

    private func moveRegularTasks(from source: IndexSet, to destination: Int) {
        var orderedTasks = regularFilteredTasks
        orderedTasks.move(fromOffsets: source, toOffset: destination)

        // Update sort order
        for (index, task) in orderedTasks.enumerated() {
            task.sortOrder = index
        }
        try? modelContext.save()
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func makeBacklogRow(task: LocalTask) -> some View {
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
    }
}

#Preview {
    ContentView()
}
