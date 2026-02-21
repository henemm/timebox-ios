import SwiftUI
import SwiftData

struct BacklogView: View {
    // MARK: - ViewMode Definition
    enum ViewMode: String, CaseIterable, Identifiable {
        case priority = "Priorität"
        case recent = "Zuletzt"
        case overdue = "Überfällig"
        case recurring = "Wiederkehrend"
        case completed = "Erledigt"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .priority: return "chart.bar.fill"
            case .recent: return "clock.arrow.circlepath"
            case .overdue: return "exclamationmark.circle"
            case .completed: return "checkmark.circle"
            case .recurring: return "arrow.triangle.2.circlepath"
            }
        }

        var emptyStateMessage: (title: String, description: String) {
            switch self {
            case .priority:
                return ("Keine Tasks", "Tippe auf + um einen neuen Task zu erstellen.")
            case .recent:
                return ("Keine Tasks", "Tippe auf + um einen neuen Task zu erstellen.")
            case .overdue:
                return ("Keine überfälligen Tasks", "Alle Tasks sind im Zeitplan.")
            case .completed:
                return ("Keine erledigten Tasks", "Erledigte Tasks der letzten 7 Tage erscheinen hier.")
            case .recurring:
                return ("Keine wiederkehrenden Tasks", "Erstelle wiederkehrende Tasks mit einem Wiederholungsmuster.")
            }
        }
    }

    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @AppStorage("backlogViewMode") private var selectedMode: ViewMode = .priority
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = false
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true
    @State private var planItems: [PlanItem] = []
    @State private var allRecurringItems: [PlanItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var importStatusMessage: String?
    @State private var reorderTrigger = false
    @State private var selectedItemForDuration: PlanItem?
    @State private var selectedItemForImportance: PlanItem?
    @State private var selectedItemForCategory: PlanItem?
    @State private var taskToEditDirectly: PlanItem?
    @State private var durationFeedback = false
    @State private var showCreateTask = false
    @State private var nextUpFeedback = false
    @State private var completeFeedback = false
    @State private var taskToEdit: PlanItem?
    @State private var completedTasks: [PlanItem] = []
    @State private var taskToDeleteRecurring: PlanItem?
    @State private var taskToEditRecurring: PlanItem?
    @State private var editSeriesMode: Bool = false
    @State private var taskToEndSeries: PlanItem?
    @State private var searchText = ""

    // MARK: - Search Filter
    private func matchesSearch(_ item: PlanItem) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText
        if item.title.localizedCaseInsensitiveContains(query) { return true }
        if item.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        if let cat = TaskCategory(rawValue: item.taskType),
           cat.localizedName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    // MARK: - Next Up Tasks
    private var nextUpTasks: [PlanItem] {
        planItems.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && matchesSearch($0) }
    }

    private var backlogTasks: [PlanItem] {
        // Filter: nicht erledigt, nicht Next Up, nicht einem FocusBlock zugeordnet
        planItems.filter { !$0.isCompleted && !$0.isNextUp && $0.assignedFocusBlockID == nil && matchesSearch($0) }
    }

    // MARK: - Recurring Tasks (only templates = series overview)
    private var recurringTasks: [PlanItem] {
        allRecurringItems.filter { $0.isTemplate && !$0.isCompleted && matchesSearch($0) }
    }

    // MARK: - Overdue Tasks (dueDate < today)
    private var overdueTasks: [PlanItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return backlogTasks.filter { item in
            guard let due = item.dueDate else { return false }
            return due < startOfToday
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    // MARK: - Recent Tasks (sorted by most recent date)
    private var recentTasks: [PlanItem] {
        backlogTasks.sorted { a, b in
            let aDate = max(a.createdAt, a.modifiedAt ?? .distantPast)
            let bDate = max(b.createdAt, b.modifiedAt ?? .distantPast)
            return aDate > bDate
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Lade Tasks...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if planItems.isEmpty {
                    let emptyState = selectedMode.emptyStateMessage
                    ContentUnavailableView(
                        emptyState.title,
                        systemImage: "checklist",
                        description: Text(emptyState.description)
                    )
                } else {
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    viewModeSwitcher

                    if remindersSyncEnabled {
                        Button {
                            Task { await importFromReminders() }
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("importRemindersButton")
                    }

                    Button {
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")
                }
            }
            .withSettingsToolbar()
            .alert("Erinnerungen importiert", isPresented: Binding(
                get: { importStatusMessage != nil },
                set: { if !$0 { importStatusMessage = nil } }
            )) {
                Button("OK") { importStatusMessage = nil }
            } message: {
                Text(importStatusMessage ?? "")
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
            .sensoryFeedback(.success, trigger: durationFeedback)
            .sensoryFeedback(.success, trigger: nextUpFeedback)
            .sensoryFeedback(.success, trigger: completeFeedback)
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
            .sheet(item: $selectedItemForImportance) { item in
                ImportancePicker(currentImportance: item.importance) { newImportance in
                    updateImportance(for: item, importance: newImportance)
                    selectedItemForImportance = nil
                }
            }
            .sheet(item: $selectedItemForCategory) { item in
                CategoryPicker(currentCategory: item.taskType) { newCategory in
                    updateCategory(for: item, category: newCategory)
                    selectedItemForCategory = nil
                }
            }
            .sheet(item: $taskToEditDirectly) { task in
                TaskFormSheet(
                    task: task,
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, recurrenceInterval in
                        if editSeriesMode {
                            updateRecurringSeries(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)
                            editSeriesMode = false
                        } else {
                            updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)
                        }
                    },
                    onDelete: {
                        deleteTask(task)
                    }
                )
            }
            .sheet(isPresented: $showCreateTask) {
                TaskFormSheet {
                    Task {
                        await loadTasks()
                    }
                }
            }
            .sheet(item: $taskToEdit) { task in
                TaskDetailSheet(
                    task: task,
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, recurrenceInterval in
                        updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)
                    },
                    onDelete: {
                        deleteTask(task)
                    }
                )
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
                        taskToEditDirectly = task
                        taskToEditRecurring = nil
                    }
                }
                Button("Alle offenen dieser Serie") {
                    if let task = taskToEditRecurring {
                        editSeriesMode = true
                        taskToEditDirectly = task
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
        .searchable(text: $searchText, prompt: "Tasks durchsuchen")
        .task(id: remindersSyncEnabled) {
            await loadTasks()
        }
        .onChange(of: cloudKitMonitor.remoteChangeCount) { oldVal, newVal in
            print("[CloudKit Debug] remoteChange onChange FIRED: \(oldVal) -> \(newVal)")
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                await refreshLocalTasks()
            }
        }
        .refreshable {
            await loadTasks()
        }
    }

    private func loadTasks() async {
        cloudKitMonitor.triggerSync()
        isLoading = true
        errorMessage = nil

        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            planItems = try await syncEngine.sync()
            allRecurringItems = try await syncEngine.syncRecurringTasks()
            completedTasks = try await syncEngine.syncCompletedTasks(days: 7)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func importFromReminders() async {
        do {
            let hasAccess = try await eventKitRepo.requestReminderAccess()
            guard hasAccess else {
                importStatusMessage = "Kein Zugriff auf Erinnerungen"
                return
            }

            let importService = RemindersImportService(
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            let result = try await importService.importAll(
                markCompleteInReminders: remindersMarkCompleteOnImport
            )

            importStatusMessage = importFeedbackMessage(from: result)

            // Reload to show imported tasks
            await loadTasks()
        } catch {
            importStatusMessage = "Import fehlgeschlagen"
        }
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

    /// Refresh tasks from local database only - no loading indicator, no Reminders import.
    /// Use this for Quick Edits to preserve scroll position and avoid overwriting local changes.
    private func refreshLocalTasks() async {
        print("[CloudKit Debug] refreshLocalTasks() START - current planItems: \(planItems.count)")
        do {
            // Force context merge with persistent store before fetch.
            // Without this, modelContext returns cached/stale data after CloudKit import.
            // This is the same mechanism that makes Pull-to-Refresh work (via triggerSync -> save).
            try modelContext.save()

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            planItems = try await syncEngine.sync()
            allRecurringItems = try await syncEngine.syncRecurringTasks()
            print("[CloudKit Debug] refreshLocalTasks() DONE - new planItems: \(planItems.count)")
        } catch {
            print("[CloudKit Debug] refreshLocalTasks() ERROR: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        planItems.move(fromOffsets: source, toOffset: destination)

        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateSortOrder(for: planItems)
            reorderTrigger.toggle()
        } catch {
            errorMessage = "Sortierung konnte nicht gespeichert werden."
        }
    }

    private func updateDuration(for item: PlanItem, minutes: Int?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateDuration(itemID: item.id, minutes: minutes)
            durationFeedback.toggle()

            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Dauer konnte nicht gespeichert werden."
        }
    }

    private func updateNextUp(for item: PlanItem, isNextUp: Bool) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: item.id, isNextUp: isNextUp)
            nextUpFeedback.toggle()

            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Next Up Status konnte nicht geändert werden."
        }
    }

    private func updateTask(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil, recurrenceInterval: Int? = nil) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: task.id, title: title, importance: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)

            // Reschedule due date notifications
            NotificationService.cancelDueDateNotifications(taskID: task.id)
            if let dueDate {
                NotificationService.scheduleDueDateNotifications(taskID: task.id, title: title, dueDate: dueDate)
            }

            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Task konnte nicht aktualisiert werden."
        }
    }

    private func updateImportance(for item: PlanItem, importance: Int?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: item.id, title: item.title, importance: importance, duration: item.estimatedDuration, tags: item.tags, urgency: item.urgency, taskType: item.taskType, dueDate: item.dueDate, description: item.taskDescription)

            // Refresh local data only - no loading indicator, no Reminders import
            // This preserves scroll position and avoids overwriting local changes
            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Wichtigkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateUrgency(for item: PlanItem, urgency: String?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: item.id, title: item.title, importance: item.importance, duration: item.estimatedDuration, tags: item.tags, urgency: urgency, taskType: item.taskType, dueDate: item.dueDate, description: item.taskDescription)

            // Refresh local data only - no loading indicator, no Reminders import
            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Dringlichkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateCategory(for item: PlanItem, category: String) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: item.id, title: item.title, importance: item.importance, duration: item.estimatedDuration, tags: item.tags, urgency: item.urgency, taskType: category, dueDate: item.dueDate, description: item.taskDescription)
            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Kategorie konnte nicht aktualisiert werden."
        }
    }

    private func deleteTask(_ task: PlanItem) {
        // Recurring task? Show confirmation dialog
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

            // Cancel due date notifications
            NotificationService.cancelDueDateNotifications(taskID: task.id)

            Task {
                await loadTasks()
            }
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

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Serie konnte nicht gelöscht werden."
        }
    }

    /// Ends a recurring series: deletes template + all open children, preserves completed history.
    private func endSeries(_ task: PlanItem) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteRecurringTemplate(groupID: groupID)

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Serie konnte nicht beendet werden."
        }
    }

    private func handleEditTap(_ task: PlanItem) {
        // Recurring task? Show confirmation dialog
        if let pattern = task.recurrencePattern,
           pattern != "none",
           task.recurrenceGroupID != nil {
            taskToEditRecurring = task
            return
        }
        taskToEditDirectly = task
    }

    private func updateRecurringSeries(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil, recurrenceInterval: Int? = nil) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateRecurringSeries(groupID: groupID, title: title, importance: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Serie konnte nicht aktualisiert werden."
        }
    }

    private func saveTitleEdit(for task: PlanItem, title: String) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(
                itemID: task.id,
                title: title,
                importance: task.importance,
                duration: task.estimatedDuration,
                tags: task.tags,
                urgency: task.urgency,
                taskType: task.taskType,
                dueDate: task.dueDate,
                description: task.taskDescription
            )

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Titel konnte nicht gespeichert werden."
        }
    }

    private func completeTask(_ item: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.completeTask(itemID: item.id)
            completeFeedback.toggle()

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Task konnte nicht als erledigt markiert werden."
        }
    }

    // MARK: - View Mode Switcher
    private var viewModeSwitcher: some View {
        Menu {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) {
                        selectedMode = mode
                    }
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
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("viewModeSwitcher")
    }

    // MARK: - Next Up Section (inline in List)
    @ViewBuilder
    private var nextUpListSection: some View {
        if !nextUpTasks.isEmpty {
            Section {
                ForEach(nextUpTasks) { item in
                    BacklogRow(
                        item: item,
                        onComplete: { completeTask(item) },
                        onDurationTap: { selectedItemForDuration = item },
                        onAddToNextUp: { updateNextUp(for: item, isNextUp: false) },
                        onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                        onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                        onCategoryTap: { selectedItemForCategory = item },
                        onEditTap: { taskToEditDirectly = item },
                        onDeleteTap: { deleteTask(item) },
                        onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            updateNextUp(for: item, isNextUp: false)
                        } label: {
                            Label("Entfernen", systemImage: "arrow.down.circle.fill")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTask(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        Button {
                            taskToEditDirectly = item
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            } header: {
                HStack {
                    Label("Next Up", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(nextUpTasks.count)")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Backlog Row with Swipe Actions (shared helper)
    @ViewBuilder
    private func backlogRowWithSwipe(_ item: PlanItem) -> some View {
        BacklogRow(
            item: item,
            onComplete: { completeTask(item) },
            onDurationTap: { selectedItemForDuration = item },
            onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
            onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
            onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
            onCategoryTap: { selectedItemForCategory = item },
            onEditTap: { handleEditTap(item) },
            onDeleteTap: { deleteTask(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) }
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                updateNextUp(for: item, isNextUp: true)
            } label: {
                Label("Next Up", systemImage: "arrow.up.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTask(item)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            Button {
                handleEditTap(item)
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Priority View (with overdue section at top)
    private var priorityView: some View {
        List {
            nextUpListSection

            // Overdue tasks at top
            if !overdueTasks.isEmpty {
                Section {
                    ForEach(overdueTasks) { item in
                        backlogRowWithSwipe(item)
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

            // Priority tiers
            ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
                let tierTasks = backlogTasks
                    .filter { task in task.priorityTier == tier && !overdueTasks.contains(where: { $0.id == task.id }) }
                    .sorted { $0.priorityScore > $1.priorityScore }
                if !tierTasks.isEmpty {
                    Section {
                        ForEach(tierTasks) { item in
                            backlogRowWithSwipe(item)
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Recent View (sorted by most recent date)
    private var recentView: some View {
        List {
            nextUpListSection

            Section {
                ForEach(recentTasks) { item in
                    backlogRowWithSwipe(item)
                }
            } header: {
                Text("Zuletzt bearbeitet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Overdue View (only overdue tasks)
    private var overdueView: some View {
        List {
            nextUpListSection

            if overdueTasks.isEmpty {
                ContentUnavailableView(
                    "Keine überfälligen Tasks",
                    systemImage: "checkmark.circle",
                    description: Text("Alle Tasks sind im Zeitplan.")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(overdueTasks) { item in
                        backlogRowWithSwipe(item)
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Recurring View (wiederkehrende Tasks)
    private var recurringView: some View {
        List {
            ForEach(recurringTasks) { item in
                BacklogRow(
                    item: item,
                    onComplete: {
                        // Templates can't be completed — checkbox means "end series"
                        if item.isTemplate {
                            taskToEndSeries = item
                        } else {
                            completeTask(item)
                        }
                    },
                    onDurationTap: { selectedItemForDuration = item },
                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                    onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { selectedItemForCategory = item },
                    onEditTap: {
                        // Template edit always means series edit — no dialog needed
                        if item.isTemplate {
                            editSeriesMode = true
                            taskToEditDirectly = item
                        } else {
                            handleEditTap(item)
                        }
                    },
                    onDeleteTap: {
                        if item.isTemplate {
                            taskToEndSeries = item
                        } else {
                            deleteTask(item)
                        }
                    },
                    onTitleSave: { newTitle in
                        saveTitleEdit(for: item, title: newTitle)
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        updateNextUp(for: item, isNextUp: true)
                    } label: {
                        Label("Next Up", systemImage: "arrow.up.circle.fill")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteTask(item)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }

                    Button {
                        taskToEditDirectly = item
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Completed View (erledigte Tasks der letzten 7 Tage)
    private var completedView: some View {
        List {
            if completedTasks.isEmpty {
                let emptyState = ViewMode.completed.emptyStateMessage
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: "checkmark.circle",
                    description: Text(emptyState.description)
                )
                .padding(.top, 40)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(completedTasks) { item in
                    CompletedTaskRow(
                        item: item,
                        onUncomplete: { uncompleteTask(item) },
                        onDelete: { deleteTask(item) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            uncompleteTask(item)
                        } label: {
                            Label("Wiederherstellen", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTask(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTasks()
        }
    }

    private func tierColor(_ tier: TaskPriorityScoringService.PriorityTier) -> Color {
        switch tier {
        case .doNow: return .red
        case .planSoon: return .orange
        case .eventually: return .yellow
        case .someday: return .gray
        }
    }

    private func uncompleteTask(_ item: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.uncompleteTask(itemID: item.id)
            completeFeedback.toggle()

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Task konnte nicht wiederhergestellt werden."
        }
    }
}

// MARK: - Completed Task Row

struct CompletedTaskRow: View {
    let item: PlanItem
    let onUncomplete: () -> Void
    let onDelete: () -> Void

    private var completedDateText: String {
        guard let completedAt = item.completedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: completedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                // Strikethrough title
                Text(item.title)
                    .font(.subheadline)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !completedDateText.isEmpty {
                    Text("Erledigt \(completedDateText)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Undo button
            Button {
                onUncomplete()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("undoCompleteButton_\(item.id)")

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title2)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("deleteCompletedButton_\(item.id)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("completedTaskRow_\(item.id)")
    }
}

