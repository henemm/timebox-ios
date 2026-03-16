import SwiftUI
import SwiftData

/// Coach-mode Backlog: Monster header + ranked tasks (matching first, rest below).
/// Replaces BacklogView when coachModeEnabled == true.
struct CoachBacklogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @Environment(DeferredSortController.self) private var deferredSort
    @Environment(DeferredCompletionController.self) private var deferredCompletion
    @AppStorage("selectedCoach") private var selectedCoach: String = ""
    @State private var planItems: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateTask = false
    @State private var taskToEdit: PlanItem?
    @State private var selectedItemForDuration: PlanItem?
    @State private var selectedItemForCategory: PlanItem?
    @State private var searchText: String = ""
    @AppStorage("coachBacklogViewMode") private var selectedMode: BacklogView.ViewMode = .priority
    @State private var completeFeedback = false
    @State private var nextUpFeedback = false
    @State private var showUndoAlert = false
    @State private var undoResultMessage = ""

    // MARK: - Recurring Task Dialog State
    @State private var taskToDeleteRecurring: PlanItem?
    @State private var taskToEditRecurring: PlanItem?
    @State private var editSeriesMode: Bool = false
    @State private var taskToEndSeries: PlanItem?

    // MARK: - Task Sections (via shared CoachBacklogViewModel)

    private var searchFilteredItems: [PlanItem] {
        guard !searchText.isEmpty else { return planItems }
        return planItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var nextUpTasks: [PlanItem] {
        CoachBacklogViewModel.nextUpTasks(from: searchFilteredItems)
    }

    private var coachBoostedTasks: [PlanItem] {
        CoachBacklogViewModel.coachBoostedTasks(from: searchFilteredItems, selectedCoach: selectedCoach)
    }

    private var remainingTasks: [PlanItem] {
        CoachBacklogViewModel.remainingTasks(from: searchFilteredItems, selectedCoach: selectedCoach)
    }

    private var overdueTasks: [PlanItem] {
        CoachBacklogViewModel.overdueTasks(from: remainingTasks)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Lade Tasks...")
                } else if let error = errorMessage {
                    ContentUnavailableView("Fehler", systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    taskList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    viewModeSwitcher
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateTask = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")
                }
            }
            .withSettingsToolbar()
            .sheet(isPresented: $showCreateTask) {
                TaskFormSheet {
                    Task { await loadTasks() }
                }
            }
            .sheet(item: $taskToEdit) { task in
                TaskFormSheet(
                    task: task,
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recPat, recWeek, recMonth, recInterval in
                        if editSeriesMode {
                            updateRecurringSeries(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recPat, recurrenceWeekdays: recWeek, recurrenceMonthDay: recMonth, recurrenceInterval: recInterval)
                            editSeriesMode = false
                        } else {
                            updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description)
                        }
                    },
                    onDelete: { deleteTask(task) }
                )
            }
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
            .sheet(item: $selectedItemForCategory) { item in
                CategoryPicker(currentCategory: item.taskType) { newCategory in
                    updateCategory(for: item, category: newCategory)
                    selectedItemForCategory = nil
                }
            }
            .sensoryFeedback(.success, trigger: completeFeedback)
            .sensoryFeedback(.success, trigger: nextUpFeedback)
        }
        .searchable(text: $searchText, prompt: "Tasks durchsuchen")
        #if canImport(UIKit)
        .onShake {
            undoLastCompletion()
        }
        #endif
        .alert("Rückgängig", isPresented: $showUndoAlert) {
            Button("OK") { }
        } message: {
            Text(undoResultMessage)
        }
        // MARK: - Recurring Task Dialogs
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
                    taskToEdit = task
                    taskToEditRecurring = nil
                }
            }
            Button("Alle offenen dieser Serie") {
                if let task = taskToEditRecurring {
                    editSeriesMode = true
                    taskToEdit = task
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
        .task { await loadTasks() }
        .onChange(of: cloudKitMonitor.remoteChangeCount) { _, _ in
            guard deferredSort.pendingIDs.isEmpty else { return }
            Task { await loadTasks() }
        }
        .refreshable { await loadTasks() }
    }

    // MARK: - Task List (switches based on ViewMode)

    @ViewBuilder
    private var taskList: some View {
        switch selectedMode {
        case .priority:
            priorityView
        case .recent:
            recentView
        case .overdue:
            overdueView
        case .recurring:
            recurringView
        case .completed:
            completedView
        }
    }

    // MARK: - Priority View (Coach-Boost + Tiers)

    private var priorityView: some View {
        List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !nextUpTasks.isEmpty {
                Section {
                    ForEach(nextUpTasks) { item in
                        coachRow(item)
                        ForEach(blockedTasks(for: item.id)) { blocked in
                            blockedRow(blocked)
                        }
                    }
                } header: {
                    sectionHeader("Next Up", icon: "arrow.up.circle.fill", count: nextUpTasks.count, color: .green)
                }
                .accessibilityIdentifier("coachNextUpSection")
            }

            if !coachBoostedTasks.isEmpty, let sectionTitle = CoachBacklogViewModel.coachSectionTitle(for: selectedCoach) {
                Section {
                    ForEach(coachBoostedTasks) { item in
                        coachRow(item)
                        ForEach(blockedTasks(for: item.id)) { blocked in
                            blockedRow(blocked)
                        }
                    }
                } header: {
                    sectionHeader(sectionTitle, count: coachBoostedTasks.count, color: .purple)
                }
                .accessibilityIdentifier("coachBoostSection")
            }

            if !overdueTasks.isEmpty {
                Section {
                    ForEach(overdueTasks) { item in
                        coachRow(item)
                        ForEach(blockedTasks(for: item.id)) { blocked in
                            blockedRow(blocked)
                        }
                    }
                } header: {
                    sectionHeader("Überfällig", count: overdueTasks.count, color: .red)
                }
            }

            ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
                let overdueIDs = Set(overdueTasks.map(\.id))
                let tierItems = CoachBacklogViewModel.tierTasks(from: remainingTasks, tier: tier, excludeIDs: overdueIDs)
                if !tierItems.isEmpty {
                    Section {
                        ForEach(tierItems) { item in
                            coachRow(item)
                            ForEach(blockedTasks(for: item.id)) { blocked in
                                blockedRow(blocked)
                            }
                        }
                    } header: {
                        sectionHeader(tier.label, count: tierItems.count, color: tierColor(tier))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Recent View

    private var recentView: some View {
        let items = CoachBacklogViewModel.recentTasks(from: searchFilteredItems)
        return List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            Section {
                ForEach(items) { item in
                    coachRow(item)
                    ForEach(blockedTasks(for: item.id)) { blocked in
                        blockedRow(blocked)
                    }
                }
            } header: {
                Text("Zuletzt bearbeitet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Overdue View

    private var overdueView: some View {
        let allOverdue = CoachBacklogViewModel.overdueTasks(from: searchFilteredItems)
        return List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if allOverdue.isEmpty {
                ContentUnavailableView("Keine überfälligen Tasks", systemImage: "checkmark.circle",
                                       description: Text("Alle Tasks sind im Zeitplan."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(allOverdue) { item in
                        coachRow(item)
                        ForEach(blockedTasks(for: item.id)) { blocked in
                            blockedRow(blocked)
                        }
                    }
                } header: {
                    sectionHeader("Überfällig", count: allOverdue.count, color: .red)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Recurring View

    private var recurringView: some View {
        let items = CoachBacklogViewModel.recurringTasks(from: searchFilteredItems)
        return List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if items.isEmpty {
                ContentUnavailableView("Keine wiederkehrenden Tasks", systemImage: "arrow.triangle.2.circlepath",
                                       description: Text("Erstelle wiederkehrende Tasks mit einem Wiederholungsmuster."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(items) { item in
                        coachRow(item)
                        ForEach(blockedTasks(for: item.id)) { blocked in
                            blockedRow(blocked)
                        }
                    }
                } header: {
                    Text("Wiederkehrend")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Completed View

    private var completedView: some View {
        let items = CoachBacklogViewModel.completedTasks(from: searchFilteredItems)
        return List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if items.isEmpty {
                ContentUnavailableView("Keine erledigten Tasks", systemImage: "checkmark.circle",
                                       description: Text("Erledigte Tasks erscheinen hier."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(items) { item in
                        coachRow(item)
                    }
                } header: {
                    Text("Erledigt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, icon: String? = nil, count: Int, color: Color) -> some View {
        HStack {
            if let icon {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    // MARK: - ViewMode Switcher

    private var viewModeSwitcher: some View {
        Menu {
            ForEach(BacklogView.ViewMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) { selectedMode = mode }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                Text(selectedMode.rawValue)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1))
        }
        .accessibilityIdentifier("coachViewModeSwitcher")
    }

    private func tierColor(_ tier: TaskPriorityScoringService.PriorityTier) -> Color {
        switch tier {
        case .doNow: return .red
        case .planSoon: return .orange
        case .eventually: return .yellow
        case .someday: return .gray
        }
    }

    // MARK: - Monster Header (shared component)

    private var monsterHeader: some View {
        MonsterIntentionHeader(selectedCoach: selectedCoach, imageHeight: 100)
    }

    // MARK: - Blocked Task Helpers

    private func blockedTasks(for blockerID: String) -> [PlanItem] {
        searchFilteredItems.filter { $0.blockerTaskID == blockerID }
    }

    private func blockedRow(_ item: PlanItem) -> some View {
        BacklogRow(
            item: item,
            onEditTap: { handleEditTap(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
            isBlocked: true
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                releaseDependency(item)
            } label: {
                Label("Freigeben", systemImage: "link.badge.plus")
            }
            .tint(.orange)
        }
    }

    private func releaseDependency(_ item: PlanItem) {
        guard let itemUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        task.blockerTaskID = nil
        task.modifiedAt = Date()
        try? modelContext.save()
        Task { await loadTasks() }
    }

    // MARK: - Coach Row (with Discipline Color)

    private func coachRow(_ item: PlanItem) -> some View {
        let discipline = Discipline.resolveOpen(
            manualDiscipline: item.manualDiscipline,
            rescheduleCount: item.rescheduleCount,
            importance: item.importance
        )
        return BacklogRow(
            item: item,
            onComplete: { completeTask(item) },
            onDurationTap: { selectedItemForDuration = item },
            onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
            onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
            onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
            onCategoryTap: { selectedItemForCategory = item },
            onEditTap: { handleEditTap(item) },
            onDeleteTap: { deleteTask(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
            isPendingResort: deferredSort.isPending(item.id),
            isCompletionPending: deferredCompletion.isPending(item.id),
            disciplineColor: discipline.color
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            Section("Disziplin") {
                ForEach(Discipline.allCases, id: \.self) { d in
                    Button {
                        updateDiscipline(for: item, discipline: d.rawValue)
                    } label: {
                        Label(d.displayName, systemImage: d.icon)
                    }
                    .tint(d.color)
                }
                if item.manualDiscipline != nil {
                    Divider()
                    Button {
                        updateDiscipline(for: item, discipline: nil)
                    } label: {
                        Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            if item.dueDate != nil {
                postponeMenu(for: item)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                nextUpFeedback.toggle()
                updateNextUp(for: item, isNextUp: !item.isNextUp)
            } label: {
                Label(item.isNextUp ? "Entfernen" : "Next Up",
                      systemImage: item.isNextUp ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
            }
            .tint(item.isNextUp ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleteTask(item) } label: {
                Label("Löschen", systemImage: "trash")
            }
            Button { handleEditTap(item) } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Data Loading

    private func loadTasks() async {
        cloudKitMonitor.triggerSync()
        isLoading = planItems.isEmpty
        errorMessage = nil
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            planItems = try await syncEngine.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Task Actions

    private func updateDiscipline(for item: PlanItem, discipline: String?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateDiscipline(itemID: item.id, discipline: discipline)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Disziplin konnte nicht geändert werden."
        }
    }

    private func updateNextUp(for item: PlanItem, isNextUp: Bool) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: item.id, isNextUp: isNextUp)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Next Up Status konnte nicht geändert werden."
        }
    }

    private func completeTask(_ item: PlanItem) {
        // Templates can't be completed — checkbox means "end series"
        if item.isTemplate, item.recurrenceGroupID != nil {
            taskToEndSeries = item
            return
        }
        completeFeedback.toggle()
        deferredCompletion.scheduleCompletion(id: item.id) { [modelContext] in
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.completeTask(itemID: item.id)
                await loadTasks()
            } catch {
                errorMessage = "Task konnte nicht erledigt werden."
            }
        }
    }

    private func deleteTask(_ task: PlanItem) {
        // Template? Show "end series" dialog instead of deleting
        if task.isTemplate, task.recurrenceGroupID != nil {
            taskToEndSeries = task
            return
        }
        // Recurring child? Show confirmation dialog
        if let pattern = task.recurrencePattern,
           pattern != "none",
           task.recurrenceGroupID != nil {
            taskToDeleteRecurring = task
            return
        }
        deleteSingleTask(task)
    }

    private func deleteSingleTask(_ task: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteTask(itemID: task.id)
            NotificationService.cancelDueDateNotifications(taskID: task.id)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Task konnte nicht gelöscht werden."
        }
    }

    private func deleteRecurringSeries(_ task: PlanItem) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteRecurringSeries(groupID: groupID)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Serie konnte nicht gelöscht werden."
        }
    }

    private func endSeries(_ task: PlanItem) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteRecurringTemplate(groupID: groupID)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Serie konnte nicht beendet werden."
        }
    }

    private func handleEditTap(_ task: PlanItem) {
        // Recurring task? Show edit series dialog
        if let pattern = task.recurrencePattern,
           pattern != "none",
           task.recurrenceGroupID != nil {
            taskToEditRecurring = task
            return
        }
        taskToEdit = task
    }

    private func updateRecurringSeries(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String?, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil, recurrenceInterval: Int? = nil) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateRecurringSeries(
                groupID: groupID, title: title, importance: priority,
                duration: duration, tags: tags, urgency: urgency,
                taskType: taskType ?? task.taskType, dueDate: dueDate, description: description,
                recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays,
                recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval
            )
            Task { await loadTasks() }
        } catch {
            errorMessage = "Serie konnte nicht aktualisiert werden."
        }
    }

    private func saveTitleEdit(for task: PlanItem, title: String) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(
                itemID: task.id, title: title, importance: task.importance,
                duration: task.estimatedDuration, tags: task.tags,
                urgency: task.urgency, taskType: task.taskType,
                dueDate: task.dueDate, description: task.taskDescription
            )
            Task { await loadTasks() }
        } catch {
            errorMessage = "Titel konnte nicht gespeichert werden."
        }
    }

    private func updateTask(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String?, dueDate: Date?, description: String?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(
                itemID: task.id, title: title, importance: priority,
                duration: duration, tags: tags, urgency: urgency,
                taskType: taskType ?? task.taskType, dueDate: dueDate, description: description
            )
            Task { await loadTasks() }
        } catch {
            errorMessage = "Task konnte nicht aktualisiert werden."
        }
    }

    private func updateImportance(for item: PlanItem, importance: Int?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.importance = importance
            task.modifiedAt = Date()
            try modelContext.save()
            freezeSortOrder()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
            scheduleDeferredResort(for: item.id)
        } catch {
            errorMessage = "Wichtigkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateUrgency(for item: PlanItem, urgency: String?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.urgency = urgency
            task.modifiedAt = Date()
            try modelContext.save()
            freezeSortOrder()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
            scheduleDeferredResort(for: item.id)
        } catch {
            errorMessage = "Dringlichkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateDuration(for item: PlanItem, minutes: Int?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.estimatedDuration = minutes
            task.modifiedAt = Date()
            try modelContext.save()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
        } catch {
            errorMessage = "Dauer konnte nicht aktualisiert werden."
        }
    }

    private func updateCategory(for item: PlanItem, category: String) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.taskType = category
            task.modifiedAt = Date()
            try modelContext.save()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
        } catch {
            errorMessage = "Kategorie konnte nicht aktualisiert werden."
        }
    }

    // MARK: - Postpone

    private func postponeMenu(for item: PlanItem) -> some View {
        Menu {
            Button { postponeTask(item, byDays: 1) } label: {
                Label("Morgen", systemImage: "sunrise")
            }
            Button { postponeTask(item, byDays: 7) } label: {
                Label("Nächste Woche", systemImage: "calendar.badge.plus")
            }
        } label: {
            Label("Verschieben", systemImage: "calendar.badge.clock")
        }
    }

    private func postponeTask(_ item: PlanItem, byDays days: Int) {
        guard let taskUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate<LocalTask> { $0.uuid == taskUUID })
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        if let newDue = LocalTask.postpone(task, byDays: days, context: modelContext) {
            NotificationService.cancelDueDateNotifications(taskID: task.id)
            NotificationService.scheduleDueDateNotifications(taskID: task.id, title: task.title, dueDate: newDue)
        }
        Task { await loadTasks() }
    }

    // MARK: - Undo

    private func undoLastCompletion() {
        guard TaskCompletionUndoService.canUndo else {
            undoResultMessage = "Nichts zum Rückgängigmachen"
            showUndoAlert = true
            return
        }
        do {
            if let title = try TaskCompletionUndoService.undo(in: modelContext) {
                undoResultMessage = "\(title) wiederhergestellt"
                completeFeedback.toggle()
                Task { await loadTasks() }
            }
        } catch {
            undoResultMessage = "Fehler: \(error.localizedDescription)"
        }
        showUndoAlert = true
    }

    // MARK: - Deferred Sort Helpers

    private func freezeSortOrder() {
        deferredSort.freeze(scores: Dictionary(uniqueKeysWithValues: planItems.map { ($0.id, $0.priorityScore) }))
    }

    private func scheduleDeferredResort(for itemID: String) {
        deferredSort.scheduleDeferredResort(id: itemID) { [self] in
            await loadTasks()
        }
    }
}
