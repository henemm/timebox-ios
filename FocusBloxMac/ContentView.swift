//
//  ContentView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import AppKit
import os

private let logger = Logger(subsystem: "com.henning.focusblox", category: "RemindersImport")

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

    // Reminders import
    @State private var isSyncing = false
    @State private var importStatusMessage: String?

    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = true
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true

    // CloudKit sync monitor
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor

    // Quick Add
    @State private var newTaskTitle = ""

    // Recurring dialogs
    @State private var taskToDeleteRecurring: LocalTask?
    @State private var taskToEditRecurring: LocalTask?
    @State private var editSeriesMode: Bool = false

    // Base filter: exclude future-dated recurring tasks (same logic as iOS LocalTaskSource)
    private var visibleTasks: [LocalTask] {
        tasks.filter { !$0.isCompleted && $0.isVisibleInBacklog }
    }

    // Computed properties for sidebar badges
    private var tbdCount: Int {
        visibleTasks.filter { $0.isTbd }.count
    }

    private var nextUpCount: Int {
        visibleTasks.filter { $0.isNextUp }.count
    }

    private var overdueCount: Int {
        let now = Date()
        return visibleTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now
        }.count
    }

    private var upcomingCount: Int {
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return visibleTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= now && dueDate <= weekFromNow
        }.count
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var recurringCount: Int {
        tasks.filter { !$0.isCompleted && $0.recurrencePattern != "none" }.count
    }

    // Filtered tasks based on sidebar selection
    private var filteredTasks: [LocalTask] {
        switch selectedFilter {
        case .all:
            return visibleTasks
        case .category(let category):
            return visibleTasks.filter { $0.taskType == category }
        case .nextUp:
            return visibleTasks.filter { $0.isNextUp }
        case .tbd:
            return visibleTasks.filter { $0.isTbd }
        case .overdue:
            let now = Date()
            return visibleTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < now
            }
        case .upcoming:
            let now = Date()
            let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            return visibleTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= weekFromNow
            }
        case .completed:
            return tasks.filter { $0.isCompleted }
        case .recurring:
            return tasks.filter { !$0.isCompleted && $0.recurrencePattern != "none" }
        case .smartPriority:
            return visibleTasks
                .sorted {
                    TaskPriorityScoringService.calculateScore(
                        importance: $0.importance, urgency: $0.urgency, dueDate: $0.dueDate,
                        createdAt: $0.createdAt, rescheduleCount: $0.rescheduleCount,
                        estimatedDuration: $0.estimatedDuration, taskType: $0.taskType,
                        isNextUp: $0.isNextUp
                    ) > TaskPriorityScoringService.calculateScore(
                        importance: $1.importance, urgency: $1.urgency, dueDate: $1.dueDate,
                        createdAt: $1.createdAt, rescheduleCount: $1.rescheduleCount,
                        estimatedDuration: $1.estimatedDuration, taskType: $1.taskType,
                        isNextUp: $1.isNextUp
                    )
                }
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
                    completedCount: completedCount,
                    recurringCount: recurringCount
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
        .alert("Erinnerungen importiert", isPresented: Binding(
            get: { importStatusMessage != nil },
            set: { if !$0 { importStatusMessage = nil } }
        )) {
            Button("OK") { importStatusMessage = nil }
        } message: {
            Text(importStatusMessage ?? "")
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
            return visibleTasks.filter { !$0.isNextUp }
        case .category(let category):
            return visibleTasks.filter { !$0.isNextUp && $0.taskType == category }
        case .nextUp:
            return []  // Next Up section handles this
        case .tbd:
            return visibleTasks.filter { !$0.isNextUp && $0.isTbd }
        case .overdue:
            let now = Date()
            return visibleTasks.filter { task in
                guard !task.isNextUp, let dueDate = task.dueDate else { return false }
                return dueDate < now
            }
        case .upcoming:
            let now = Date()
            let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            return visibleTasks.filter { task in
                guard !task.isNextUp, let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= weekFromNow
            }
        case .completed:
            return tasks.filter { $0.isCompleted }
        case .recurring:
            return tasks.filter { !$0.isCompleted && !$0.isNextUp && $0.recurrencePattern != "none" }
        case .smartPriority:
            return visibleTasks.filter { !$0.isNextUp }
                .sorted {
                    TaskPriorityScoringService.calculateScore(
                        importance: $0.importance, urgency: $0.urgency, dueDate: $0.dueDate,
                        createdAt: $0.createdAt, rescheduleCount: $0.rescheduleCount,
                        estimatedDuration: $0.estimatedDuration, taskType: $0.taskType,
                        isNextUp: $0.isNextUp
                    ) > TaskPriorityScoringService.calculateScore(
                        importance: $1.importance, urgency: $1.urgency, dueDate: $1.dueDate,
                        createdAt: $1.createdAt, rescheduleCount: $1.rescheduleCount,
                        estimatedDuration: $1.estimatedDuration, taskType: $1.taskType,
                        isNextUp: $1.isNextUp
                    )
                }
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

                    // Show "Serie bearbeiten" for single recurring task
                    if selection.count == 1,
                       let taskId = selection.first,
                       let task = tasks.first(where: { $0.uuid == taskId }),
                       task.recurrencePattern != "none",
                       task.recurrenceGroupID != nil {
                        Divider()
                        Button("Serie bearbeiten...") {
                            taskToEditRecurring = task
                        }
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
                // CloudKit sync status indicator
                Group {
                    if cloudKitMonitor.isSyncing || isSyncing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if cloudKitMonitor.hasSyncError {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(.red)
                            .help(cloudKitMonitor.errorMessage ?? "Sync-Fehler")
                    } else {
                        Image(systemName: "checkmark.icloud")
                            .foregroundStyle(.green)
                            .help(cloudKitMonitor.lastSuccessfulSync.map {
                                "Letzter Sync: \($0.formatted(date: .omitted, time: .shortened))"
                            } ?? "CloudKit verbunden")
                    }
                }
                .accessibilityIdentifier("syncStatusIndicator")
            }

            ToolbarItem {
                Button {
                    cloudKitMonitor.triggerSync()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("syncButton")
                .help("CloudKit synchronisieren")
            }

            if remindersSyncEnabled {
                ToolbarItem {
                    Button {
                        Task { await importFromReminders() }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(isSyncing)
                    .accessibilityIdentifier("importRemindersButton")
                    .help("Erinnerungen importieren")
                }
            }

            ToolbarItem {
                Text("\(filteredTasks.count) Tasks")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            cloudKitMonitor.triggerSync()
        }
        .confirmationDialog(
            "Wiederkehrende Aufgabe löschen",
            isPresented: Binding(
                get: { taskToDeleteRecurring != nil },
                set: { if !$0 { taskToDeleteRecurring = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Nur diese Aufgabe", role: .destructive) {
                if let task = taskToDeleteRecurring {
                    deleteSingleTask(task)
                    taskToDeleteRecurring = nil
                }
            }
            Button("Alle offenen dieser Serie", role: .destructive) {
                if let task = taskToDeleteRecurring {
                    deleteRecurringSeries(task)
                    taskToDeleteRecurring = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                taskToDeleteRecurring = nil
            }
        }
        .confirmationDialog(
            "Wiederkehrende Aufgabe bearbeiten",
            isPresented: Binding(
                get: { taskToEditRecurring != nil },
                set: { if !$0 { taskToEditRecurring = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Nur diese Aufgabe") {
                if let task = taskToEditRecurring {
                    editSeriesMode = false
                    selectedTasks = [task.uuid]
                    taskToEditRecurring = nil
                }
            }
            Button("Alle offenen dieser Serie") {
                if let task = taskToEditRecurring {
                    editSeriesMode = true
                    selectedTasks = [task.uuid]
                    taskToEditRecurring = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                taskToEditRecurring = nil
            }
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
        case .recurring: return "Wiederkehrend"
        case .smartPriority: return "Priorität"
        }
    }

    private func categoryName(_ category: String) -> String {
        TaskCategory(rawValue: category)?.displayName ?? category
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
            VStack(spacing: 0) {
                if editSeriesMode && task.recurrenceGroupID != nil {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Serie wird bearbeitet")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button("Auf Serie anwenden") {
                            updateRecurringSeries(task)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(.purple.opacity(0.1))
                }
                TaskInspector(task: task) {
                    modelContext.delete(task)
                    selectedTasks.removeAll()
                }
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

    private func importFromReminders() async {
        logger.info("Started")
        isSyncing = true

        do {
            let hasAccess = try await eventKitRepo.requestReminderAccess()
            guard hasAccess else {
                logger.warning("No access — user denied Reminders permission")
                importStatusMessage = "Kein Zugriff auf Erinnerungen"
                isSyncing = false
                return
            }

            let importService = RemindersImportService(
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            let result = try await importService.importAll(
                markCompleteInReminders: remindersMarkCompleteOnImport
            )

            logger.info("Done — \(result.imported.count) imported, \(result.skippedDuplicates) skipped, \(result.enrichedRecurrence) enriched, \(result.markedComplete) marked complete, \(result.markCompleteFailures) mark-complete failures")

            importStatusMessage = importFeedbackMessage(from: result)
        } catch {
            logger.error("Failed: \(error.localizedDescription)")
            importStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func importFeedbackMessage(from result: RemindersImportService.ImportResult) -> String {
        var parts: [String] = []

        if !result.imported.isEmpty {
            parts.append("\(result.imported.count) importiert")
        }
        if result.skippedDuplicates > 0 {
            parts.append("\(result.skippedDuplicates) bereits vorhanden")
        }
        if result.enrichedRecurrence > 0 {
            parts.append("\(result.enrichedRecurrence) Wiederholungen erkannt")
        }
        if result.markCompleteFailures > 0 {
            parts.append("\(result.markCompleteFailures)x Abhaken fehlgeschlagen")
        }

        if parts.isEmpty {
            return "Keine neuen Erinnerungen"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Task Actions

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let title = newTaskTitle
        newTaskTitle = ""

        Task {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            if let newTask = try? await taskSource.createTask(title: title, taskType: "") {
                let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
                await enrichment.enrichTask(newTask)
            }
        }
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
        // Single task with recurring pattern? Show confirmation dialog
        if ids.count == 1,
           let taskId = ids.first,
           let task = tasks.first(where: { $0.uuid == taskId }),
           task.recurrencePattern != "none",
           task.recurrenceGroupID != nil {
            taskToDeleteRecurring = task
            return
        }

        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                modelContext.delete(task)
            }
        }
        try? modelContext.save()
        selectedTasks.removeAll()
    }

    private func deleteSingleTask(_ task: LocalTask) {
        modelContext.delete(task)
        try? modelContext.save()
        selectedTasks.removeAll()
    }

    private func deleteRecurringSeries(_ task: LocalTask) {
        guard let groupID = task.recurrenceGroupID else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }
        )
        if let seriesTasks = try? modelContext.fetch(descriptor) {
            for t in seriesTasks {
                modelContext.delete(t)
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

    private func updateRecurringSeries(_ task: LocalTask) {
        guard let groupID = task.recurrenceGroupID else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }
        )
        if let seriesTasks = try? modelContext.fetch(descriptor) {
            for t in seriesTasks where t.uuid != task.uuid {
                t.title = task.title
                t.importance = task.importance
                t.estimatedDuration = task.estimatedDuration
                t.tags = task.tags
                t.urgency = task.urgency
                t.taskType = task.taskType
                t.taskDescription = task.taskDescription
                t.recurrencePattern = task.recurrencePattern
                t.recurrenceWeekdays = task.recurrenceWeekdays
                t.recurrenceMonthDay = task.recurrenceMonthDay
            }
        }
        try? modelContext.save()
        editSeriesMode = false
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
