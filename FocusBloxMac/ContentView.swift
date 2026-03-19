//
//  ContentView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import AppKit
import CoreSpotlight
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
    let undoLastCompletion: () -> Void
    let hasSelection: Bool
}

// MARK: - Content View (Three-Column Layout)

struct ContentView: View {
    // Bug 90: @Query doesn't reliably refresh after CloudKit imports.
    // Using @State + manual fetch (same pattern as iOS BacklogView).
    @State private var tasks: [LocalTask] = []

    @Environment(\.modelContext) private var modelContext

    // EventKit for Reminders sync
    @Environment(\.eventKitRepository) private var eventKitRepo

    // Navigation state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Binding var selectedSection: MainSection
    @State private var selectedFilter: SidebarFilter = .priority
    @State private var selectedTasks: Set<UUID> = []
    @State private var scrollToTaskID: UUID?  // Bug 94: Auto-scroll after task creation
    @State private var inspectorOverrideTaskID: UUID?  // Bug 94: Inspector fallback when List resets selection

    // Shared date for Blox tab
    @State private var sharedDate = Date()

    // Reminders import
    @State private var isSyncing = false
    @State private var importStatusMessage: String?

    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = true
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true

    // Coach mode
    @AppStorage("coachModeEnabled") private var coachModeEnabled: Bool = false

    // CloudKit sync monitor
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @Environment(DeferredSortController.self) private var deferredSort
    @Environment(DeferredCompletionController.self) private var deferredCompletion

    // Task creation via sheet
    @State private var showCreateTask = false

    @State private var searchText = ""

    // Recurring dialogs
    @State private var taskToDeleteRecurring: LocalTask?
    @State private var taskToEditRecurring: LocalTask?
    @State private var editSeriesMode: Bool = false
    @State private var taskToEndSeries: LocalTask?


    // MARK: - Data Refresh (Bug 90: replaces @Query for reliable CloudKit sync)

    /// Fetches all tasks from the persistent store, forcing context merge first.
    /// Called on initial load, after CloudKit sync, and after local add/delete.
    private func refreshTasks() {
        do {
            // Force context merge with persistent store (Bug 38 pattern)
            try modelContext.save()
            let descriptor = FetchDescriptor<LocalTask>(
                sortBy: [SortDescriptor(\LocalTask.createdAt, order: .reverse)]
            )
            tasks = try modelContext.fetch(descriptor)
        } catch {
            print("[ContentView] refreshTasks failed: \(error)")
        }
    }

    // MARK: - Search Filter
    private func matchesSearch(_ task: LocalTask) -> Bool {
        guard task.modelContext != nil else { return false }  // Bug 78: skip detached objects
        guard !searchText.isEmpty else { return true }
        let query = searchText
        if task.title.localizedCaseInsensitiveContains(query) { return true }
        if task.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        if let cat = TaskCategory(rawValue: task.taskType),
           cat.localizedName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    // Base filter: exclude future-dated recurring tasks (same logic as iOS LocalTaskSource)
    private var visibleTasks: [LocalTask] {
        tasks.filter { $0.modelContext != nil && !$0.isCompleted && $0.isVisibleInBacklog }  // Bug 78: skip detached
    }

    // Computed properties for sidebar badges
    private var overdueCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return visibleTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday && !task.isNextUp && task.assignedFocusBlockID == nil
        }.count
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var recurringCount: Int {
        tasks.filter { $0.isTemplate && !$0.isCompleted }.count
    }

    // Filtered tasks based on sidebar selection + search
    private var filteredTasks: [LocalTask] {
        let base: [LocalTask]
        switch selectedFilter {
        case .priority:
            base = visibleTasks
                .sorted { scoreFor($0) > scoreFor($1) }
        case .recent:
            base = visibleTasks
                .sorted { a, b in
                    let aDate = max(a.createdAt, a.modifiedAt ?? .distantPast)
                    let bDate = max(b.createdAt, b.modifiedAt ?? .distantPast)
                    return aDate > bDate
                }
        case .overdue:
            let startOfToday = Calendar.current.startOfDay(for: Date())
            base = visibleTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .completed:
            base = tasks.filter { $0.modelContext != nil && $0.isCompleted }  // Bug 78: skip detached
        case .recurring:
            base = tasks.filter { $0.modelContext != nil && $0.isTemplate && !$0.isCompleted }  // Bug 78
        }
        return searchText.isEmpty ? base : base.filter { matchesSearch($0) }
    }

    // Selected task for inspector (single selection)
    private var selectedTask: LocalTask? {
        // Bug 94: Try List selection first, then fall back to inspector override
        if selectedTasks.count == 1, let taskId = selectedTasks.first {
            return tasks.first { $0.uuid == taskId }
        }
        // Bug 94: Fallback — after task creation, NSTableView may reset selectedTasks
        if let overrideId = inspectorOverrideTaskID {
            return tasks.first { $0.uuid == overrideId }
        }
        return nil
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Show filter options when Backlog is selected
            if selectedSection == .backlog {
                SidebarView(
                    selectedFilter: $selectedFilter,
                    overdueCount: overdueCount,
                    completedCount: completedCount,
                    recurringCount: recurringCount
                )
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
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
        .task {
            refreshTasks()
            if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
                cloudKitMonitor.triggerSync()
            }
        }
        .onChange(of: cloudKitMonitor.remoteChangeCount) { _, _ in
            // Bug 90: Manual re-fetch after CloudKit import (replaces unreliable @Query).
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                refreshTasks()
                // Enrich remote tasks (Watch, Share Extension, Siri) that arrived without attributes
                let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
                let enriched = await enrichment.enrichAllTbdTasks()
                if enriched > 0 { refreshTasks() }
            }
        }
        .toolbar(id: "mainNavigation") {
            // Main navigation in toolbar
            ToolbarItem(id: "navigationPicker", placement: .principal) {
                Picker("Bereich", selection: $selectedSection) {
                    ForEach(MainSection.allCases, id: \.self) { section in
                        Label(
                            section == .review && coachModeEnabled ? "Mein Tag" : section.rawValue,
                            systemImage: section == .review && coachModeEnabled ? "sun.and.horizon" : section.icon
                        )
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
                selectedDate: $sharedDate
            )
        case .focus:
            MacFocusView()
        case .review:
            if coachModeEnabled {
                CoachMeinTagView()
            } else {
                MacReviewView()
            }
        }
    }

    // MARK: - Backlog View

    // Next Up tasks (sorted by nextUpSortOrder, search-filtered)
    private var nextUpTasks: [LocalTask] {
        tasks.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && $0.blockerTaskID == nil && matchesSearch($0) }
            .sorted { ($0.nextUpSortOrder ?? Int.max) < ($1.nextUpSortOrder ?? Int.max) }
    }

    // Regular tasks (non-Next Up, top-level only — blocked tasks rendered inline under their blocker)
    private var regularFilteredTasks: [LocalTask] {
        let base: [LocalTask]
        switch selectedFilter {
        case .priority:
            base = visibleTasks.filter { !$0.isNextUp && $0.blockerTaskID == nil }
                .sorted { scoreFor($0) > scoreFor($1) }
        case .recent:
            base = visibleTasks.filter { !$0.isNextUp && $0.blockerTaskID == nil }
                .sorted { a, b in
                    let aDate = max(a.createdAt, a.modifiedAt ?? .distantPast)
                    let bDate = max(b.createdAt, b.modifiedAt ?? .distantPast)
                    return aDate > bDate
                }
        case .overdue:
            let startOfToday = Calendar.current.startOfDay(for: Date())
            base = visibleTasks.filter { task in
                guard !task.isNextUp, task.blockerTaskID == nil, let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }.sorted { scoreFor($0) > scoreFor($1) }
        case .completed:
            base = tasks.filter { $0.modelContext != nil && $0.isCompleted }  // Bug 78
        case .recurring:
            base = tasks.filter { $0.modelContext != nil && $0.isTemplate && !$0.isCompleted }  // Bug 78
        }
        return searchText.isEmpty ? base : base.filter { matchesSearch($0) }
    }

    // Tasks blocked by a given blocker task
    private func blockedDependents(of blockerID: String) -> [LocalTask] {
        visibleTasks.filter { $0.blockerTaskID == blockerID && !$0.isNextUp }
    }

    /// Number of incomplete tasks that depend on the given task
    private func dependentCount(for taskID: String) -> Int {
        visibleTasks.filter { $0.blockerTaskID == taskID }.count
    }

    // Show Next Up section in all views except Completed
    private var showNextUpSection: Bool {
        selectedFilter != .completed && selectedFilter != .recurring && !nextUpTasks.isEmpty
    }

    // MARK: - Priority Section Helpers

    // Calculate priority score for a task (delegates to shared DeferredSortController)
    private func scoreFor(_ task: LocalTask) -> Int {
        let liveScore = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp,
            dependentTaskCount: dependentCount(for: task.id)
        )
        let base = deferredSort.effectiveScore(id: task.id, liveScore: liveScore)
        let boost = coachBoostedIDs.contains(task.id) ? TaskPriorityScoringService.coachBoostValue : 0
        return min(100, base + boost)
    }

    // Overdue tasks (non-NextUp, non-blocked, dueDate before today, sorted by priority score)
    private var overdueTasks: [LocalTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return visibleTasks.filter { task in
            guard !task.isNextUp, task.blockerTaskID == nil, let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday && matchesSearch(task)
        }.sorted { scoreFor($0) > scoreFor($1) }
    }

    // Color for priority tier section headers
    private func tierColor(_ tier: TaskPriorityScoringService.PriorityTier) -> Color {
        switch tier {
        case .doNow: return .red
        case .planSoon: return .orange
        case .eventually: return .yellow
        case .someday: return .gray
        }
    }

    // MARK: - Coach-Boosted IDs (score boost instead of separate section)

    private var planItems: [PlanItem] {
        visibleTasks.map { PlanItem(localTask: $0) }
    }

    /// IDs of tasks that get a +15 score boost from Coach/Monster mode.
    private var coachBoostedIDs: Set<String> {
        guard coachModeEnabled else { return [] }
        return Set(CoachBacklogViewModel.coachBoostedTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
    }

    @AppStorage("selectedCoach") private var selectedCoach: String = ""

    private var backlogView: some View {
        VStack(spacing: 0) {
            // MARK: - Inline Search (FEATURE_023_v2)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Tasks durchsuchen", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("backlogSearchField")
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            // Task List with Multi-Selection and Sections
            List(selection: $selectedTasks) {
                // Monster header (coach mode only)
                if coachModeEnabled {
                    MonsterIntentionHeader(selectedCoach: selectedCoach, imageHeight: 80)
                        .listRowSeparator(.hidden)
                }

                // MARK: Next Up Section (only in "All" filter)
                if showNextUpSection {
                    Section {
                        ForEach(nextUpTasks, id: \.uuid) { task in
                            makeBacklogRow(task: task)
                                .tag(task.uuid)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        removeFromNextUp([task.uuid])
                                    } label: {
                                        Label("Entfernen", systemImage: "arrow.down.circle.fill")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteTasksByIds([task.uuid])
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }

                                    Button {
                                        selectedTasks = [task.uuid]
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
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
                    .accessibilityIdentifier(coachModeEnabled ? "coachNextUpSection" : "nextUpSection")
                }

                // MARK: Regular Tasks — Priority Tier Sections or Flat List
                if selectedFilter == .priority {
                    // Overdue section (at top, like iOS)
                    if !overdueTasks.isEmpty {
                        Section {
                            ForEach(overdueTasks, id: \.uuid) { task in
                                taskRowWithSwipe(task: task)
                            }
                        } header: {
                            HStack {
                                Text("Überfällig")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                Spacer()
                                Text("\(overdueTasks.count)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Priority tier sections (coach-boosted tasks stay in tier with +15 score boost)
                    ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
                        let tierTasks = regularFilteredTasks.filter { task in
                            let taskTier = TaskPriorityScoringService.PriorityTier.from(score: scoreFor(task))
                            let isOverdue = overdueTasks.contains(where: { $0.uuid == task.uuid })
                            return taskTier == tier && !isOverdue
                        }.sorted { scoreFor($0) > scoreFor($1) }

                        if !tierTasks.isEmpty {
                            Section {
                                ForEach(tierTasks, id: \.uuid) { task in
                                    taskRowWithSwipe(task: task)
                                }
                            } header: {
                                HStack {
                                    Text(tier.label)
                                        .font(.headline)
                                        .foregroundStyle(tierColor(tier))
                                    Spacer()
                                    Text("\(tierTasks.count)")
                                        .font(.caption)
                                        .foregroundStyle(tierColor(tier))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tierColor(tier).opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } else {
                    // Non-priority filters: flat list (recent, overdue, completed, recurring)
                    Section {
                        ForEach(regularFilteredTasks, id: \.uuid) { task in
                            taskRowWithSwipe(task: task)
                        }
                        .onMove { from, to in
                            moveRegularTasks(from: from, to: to)
                        }
                    } header: {
                        if showNextUpSection {
                            Text("Backlog")
                        }
                    }
                }
            }
            .contextMenu(forSelectionType: UUID.self) { selection in
                backlogContextMenu(for: selection)
            } primaryAction: { selection in
                // Double-click opens inspector (already selected)
            }
            // Bug 94: Auto-scroll to newly created task
            .scrollPosition(id: $scrollToTaskID, anchor: .center)
            // Bug 94: Clear inspector override when user manually selects a task
            .onChange(of: selectedTasks) { _, newValue in
                if !newValue.isEmpty {
                    inspectorOverrideTaskID = nil
                }
            }
            .accessibilityIdentifier(coachModeEnabled ? "coachTaskList" : "backlogTaskList")
        }
        .navigationTitle(filterTitle)
        .sheet(isPresented: $showCreateTask) {
            MacTaskCreateSheet {
                refreshTasks()
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showCreateTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("macAddTaskButton")
                .help("Neuer Task")
            }

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
        .confirmationDialog(
            "Serie beenden?",
            isPresented: Binding(
                get: { taskToEndSeries != nil },
                set: { if !$0 { taskToEndSeries = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Serie beenden", role: .destructive) {
                if let task = taskToEndSeries {
                    endSeries(task)
                    taskToEndSeries = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                taskToEndSeries = nil
            }
        } message: {
            Text("Die Vorlage und alle offenen Aufgaben werden gelöscht. Erledigte Aufgaben bleiben erhalten.")
        }
    }

    private var filterTitle: String {
        switch selectedFilter {
        case .priority: return "Priorität"
        case .recent: return "Zuletzt"
        case .overdue: return "Überfällig"
        case .completed: return "Erledigt"
        case .recurring: return "Wiederkehrend"
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
        showCreateTask = true
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

            refreshTasks()
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

    private func deleteTasks(at offsets: IndexSet) {
        let tasksToDelete = regularFilteredTasks
        for index in offsets {
            if index < tasksToDelete.count {
                modelContext.delete(tasksToDelete[index])
            }
        }
        try? modelContext.save()
    }

    // MARK: - Postpone (Bug 85-C)

    private func postponeTask(_ task: LocalTask, byDays days: Int) {
        if let newDue = LocalTask.postpone(task, byDays: days, context: modelContext) {
            NotificationService.cancelDueDateNotifications(taskID: task.id)
            NotificationService.scheduleDueDateNotifications(
                taskID: task.id, title: task.title, dueDate: newDue
            )
        }
    }

    private func releaseDependency(_ task: LocalTask) {
        task.blockerTaskID = nil
        try? modelContext.save()
        refreshTasks()
    }

    @ViewBuilder
    private func backlogContextMenu(for selection: Set<UUID>) -> some View {
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

            singleTaskContextMenuItems(for: selection)

            Divider()

            Button("Löschen", role: .destructive) {
                deleteTasksByIds(selection)
            }
        }
    }

    @ViewBuilder
    private func singleTaskContextMenuItems(for selection: Set<UUID>) -> some View {
        if selection.count == 1,
           let taskId = selection.first,
           let task = tasks.first(where: { $0.uuid == taskId }) {
            if task.dueDate != nil {
                Menu("Verschieben") {
                    Button("Morgen") { postponeTask(task, byDays: 1) }
                    Button("Nächste Woche") { postponeTask(task, byDays: 7) }
                }
            }
            if task.blockerTaskID != nil {
                Button("Abhängigkeit entfernen") {
                    releaseDependency(task)
                }
            }
            if task.recurrencePattern != "none",
               task.recurrenceGroupID != nil {
                Divider()
                Button("Serie bearbeiten...") {
                    taskToEditRecurring = task
                }
            }
        }
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
        refreshTasks()
        selectedTasks.removeAll()
    }

    private func deleteSingleTask(_ task: LocalTask) {
        modelContext.delete(task)
        try? modelContext.save()
        refreshTasks()
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
        refreshTasks()
        selectedTasks.removeAll()
    }

    /// Ends a recurring series: deletes template + all open children, preserves completed history.
    private func endSeries(_ task: LocalTask) {
        guard let groupID = task.recurrenceGroupID else { return }
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        try? syncEngine.deleteRecurringTemplate(groupID: groupID)
        refreshTasks()
        selectedTasks.removeAll()
    }

    private func markTasksCompleted(_ ids: Set<UUID>) {
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }), task.blockerTaskID == nil {
                deferredCompletion.scheduleCompletion(id: task.id) { [modelContext] in
                    let taskSource = LocalTaskSource(modelContext: modelContext)
                    let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                    try? syncEngine.completeTask(itemID: task.id)
                }
            }
        }
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
                t.recurrenceInterval = task.recurrenceInterval
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
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }), task.blockerTaskID == nil {
                try? syncEngine.updateNextUp(itemID: task.id, isNextUp: true)
            }
        }
    }

    private func removeFromNextUp(_ ids: Set<UUID>) {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        for id in ids {
            if let task = tasks.first(where: { $0.uuid == id }) {
                try? syncEngine.updateNextUp(itemID: task.id, isNextUp: false)
            }
        }
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

    // MARK: - Task Row with Swipe Actions (shared by all sections)

    @ViewBuilder
    private func taskRowWithSwipe(task: LocalTask) -> some View {
        makeBacklogRow(task: task)
            .id(task.uuid)  // Bug 94: View identity for ScrollViewReader.scrollTo()
            .tag(task.uuid)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    if task.isNextUp {
                        removeFromNextUp([task.uuid])
                    } else {
                        addToNextUp([task.uuid])
                    }
                } label: {
                    Label(
                        task.isNextUp ? "Entfernen" : "Next Up",
                        systemImage: task.isNextUp ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                    )
                }
                .tint(task.isNextUp ? .orange : .green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteTasksByIds([task.uuid])
                } label: {
                    Label("Löschen", systemImage: "trash")
                }

                Button {
                    selectedTasks = [task.uuid]
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
                .tint(.blue)
            }

        // Blocked dependents (no swipe actions — cannot be actioned until blocker is done)
        ForEach(blockedDependents(of: task.id), id: \.uuid) { blockedTask in
            makeBacklogRow(task: blockedTask, isBlocked: true)
                .tag(blockedTask.uuid)
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func makeBacklogRow(task: LocalTask, isBlocked: Bool = false) -> some View {
        MacBacklogRow(
            task: task,
            onToggleComplete: {
                // Templates can't be completed — checkbox means "end series"
                if task.isTemplate {
                    taskToEndSeries = task
                } else {
                    deferredCompletion.scheduleCompletion(id: task.id) { [modelContext] in
                        let taskSource = LocalTaskSource(modelContext: modelContext)
                        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                        try? syncEngine.completeTask(itemID: task.id)
                    }
                }
            },
            onImportanceCycle: { newValue in
                freezeSortOrder()
                task.importance = newValue
                try? modelContext.save()
                deferredSort.scheduleDeferredResort(id: task.id)
            },
            onUrgencyToggle: { newValue in
                freezeSortOrder()
                task.urgency = newValue
                try? modelContext.save()
                deferredSort.scheduleDeferredResort(id: task.id)
            },
            onCategorySelect: { category in
                freezeSortOrder()
                task.taskType = category
                try? modelContext.save()
                deferredSort.scheduleDeferredResort(id: task.id)
            },
            onDurationSelect: { duration in
                freezeSortOrder()
                task.estimatedDuration = duration
                try? modelContext.save()
                deferredSort.scheduleDeferredResort(id: task.id)
            },
            isPendingResort: deferredSort.isPending(task.id),
            isCompletionPending: deferredCompletion.isPending(task.id),
            isBlocked: isBlocked,
            dependentCount: dependentCount(for: task.id),
            effectiveScore: scoreFor(task),
            effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: scoreFor(task))
        )
    }

    // MARK: - Deferred Sort Helper (delegates to shared DeferredSortController)

    private func freezeSortOrder() {
        deferredSort.freeze(scores: Dictionary(uniqueKeysWithValues: visibleTasks.filter { !$0.isNextUp }.map {
            ($0.id, scoreFor($0))
        }))
    }
}

#Preview {
    ContentView(selectedSection: .constant(.backlog))
}
