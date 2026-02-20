import SwiftUI
import SwiftData

struct BacklogView: View {
    // MARK: - ViewMode Definition
    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "Liste"
        case eisenhowerMatrix = "Matrix"
        case category = "Kategorie"
        case duration = "Dauer"
        case dueDate = "Fälligkeit"
        case tbd = "TBD"
        case completed = "Erledigt"
        case recurring = "Wiederkehrend"
        case smartPriority = "Priorität"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .eisenhowerMatrix: return "square.grid.2x2"
            case .category: return "folder"
            case .duration: return "clock"
            case .dueDate: return "calendar"
            case .tbd: return "questionmark.circle"
            case .completed: return "checkmark.circle"
            case .recurring: return "arrow.triangle.2.circlepath"
            case .smartPriority: return "chart.bar.fill"
            }
        }

        var emptyStateMessage: (title: String, description: String) {
            switch self {
            case .list:
                return ("Keine Tasks", "Tippe auf + um einen neuen Task zu erstellen.")
            case .eisenhowerMatrix:
                return ("Keine Tasks für Matrix", "Setze Wichtigkeit und Dringlichkeit für deine Tasks.")
            case .category:
                return ("Keine Tasks in Kategorien", "Erstelle Tasks und weise ihnen Kategorien zu.")
            case .duration:
                return ("Keine Tasks mit Dauer", "Setze geschätzte Dauern für deine Tasks.")
            case .dueDate:
                return ("Keine Tasks mit Fälligkeitsdatum", "Setze Fälligkeitsdaten für deine Tasks.")
            case .tbd:
                return ("Keine unvollständigen Tasks", "Alle Tasks haben Wichtigkeit, Dringlichkeit und Dauer.")
            case .completed:
                return ("Keine erledigten Tasks", "Erledigte Tasks der letzten 7 Tage erscheinen hier.")
            case .recurring:
                return ("Keine wiederkehrenden Tasks", "Erstelle wiederkehrende Tasks mit einem Wiederholungsmuster.")
            case .smartPriority:
                return ("Keine Tasks", "Erstelle Tasks, um die Prioritäts-Sortierung zu sehen.")
            }
        }
    }

    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @AppStorage("backlogViewMode") private var selectedMode: ViewMode = .list
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

    // MARK: - Next Up Tasks
    private var nextUpTasks: [PlanItem] {
        planItems.filter { $0.isNextUp && !$0.isCompleted }
    }

    private var backlogTasks: [PlanItem] {
        // Filter: nicht erledigt, nicht Next Up, nicht einem FocusBlock zugeordnet
        planItems.filter { !$0.isCompleted && !$0.isNextUp && $0.assignedFocusBlockID == nil }
    }

    // MARK: - Eisenhower Matrix Filters (nur vollständige Tasks, keine TBDs)
    private var doFirstTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.importance == 3 && !$0.isTbd && !$0.isCompleted && !$0.isNextUp }
    }

    private var scheduleTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.importance == 3 && !$0.isTbd && !$0.isCompleted && !$0.isNextUp }
    }

    private var delegateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && ($0.importance ?? 0) < 3 && !$0.isTbd && !$0.isCompleted && !$0.isNextUp }
    }

    private var eliminateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && ($0.importance ?? 0) < 3 && !$0.isTbd && !$0.isCompleted && !$0.isNextUp }
    }

    // MARK: - Recurring Tasks (all incomplete, ignoring isVisibleInBacklog)
    private var recurringTasks: [PlanItem] {
        allRecurringItems.filter { !$0.isCompleted && !$0.isNextUp }
    }

    // MARK: - TBD Tasks (unvollständig)
    private var tbdTasks: [PlanItem] {
        planItems.filter { $0.isTbd && !$0.isCompleted && !$0.isNextUp }
    }

    private var tbdCount: Int {
        tbdTasks.count
    }

    // MARK: - Category Grouping
    private var tasksByCategory: [(category: String, tasks: [PlanItem])] {
        let categories = ["deep_work", "shallow_work", "meetings", "maintenance", "creative", "strategic"]
        return categories.compactMap { category in
            let filtered = planItems.filter { $0.taskType == category && !$0.isCompleted && !$0.isNextUp }
            guard !filtered.isEmpty else { return nil }
            return (category: category.localizedCategory, tasks: filtered)
        }
    }

    // MARK: - Duration Grouping
    private var tasksByDuration: [(bucket: String, tasks: [PlanItem])] {
        let buckets: [(String, ClosedRange<Int>)] = [
            ("< 15 Min", 0...14),
            ("15-30 Min", 15...29),
            ("30-60 Min", 30...59),
            ("> 60 Min", 60...999)
        ]
        return buckets.compactMap { (label, range) in
            let filtered = planItems.filter {
                !$0.isCompleted && !$0.isNextUp && range.contains($0.effectiveDuration)
            }
            guard !filtered.isEmpty else { return nil }
            return (bucket: label, tasks: filtered)
        }
    }

    // MARK: - Due Date Grouping
    private var tasksByDueDate: [(section: String, tasks: [PlanItem])] {
        let calendar = Calendar.current
        let today = Date()

        var grouped: [(String, [PlanItem])] = []

        let todayTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDateInToday(due)
        }
        if !todayTasks.isEmpty { grouped.append(("Heute", todayTasks)) }

        let tomorrowTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDateInTomorrow(due)
        }
        if !tomorrowTasks.isEmpty { grouped.append(("Morgen", tomorrowTasks)) }

        let weekTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            return calendar.isDate(due, equalTo: today, toGranularity: .weekOfYear) &&
                   !calendar.isDateInToday(due) && !calendar.isDateInTomorrow(due)
        }
        if !weekTasks.isEmpty { grouped.append(("Diese Woche", weekTasks)) }

        let laterTasks = planItems.filter {
            guard let due = $0.dueDate, !$0.isCompleted, !$0.isNextUp else { return false }
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today) else { return false }
            return due > nextWeek
        }
        if !laterTasks.isEmpty { grouped.append(("Später", laterTasks)) }

        let noDueDateTasks = planItems.filter { $0.dueDate == nil && !$0.isCompleted && !$0.isNextUp }
        if !noDueDateTasks.isEmpty { grouped.append(("Ohne Fälligkeitsdatum", noDueDateTasks)) }

        return grouped
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
                    VStack(spacing: 16) {
                        // Next Up Section
                        NextUpSection(
                            tasks: nextUpTasks,
                            onRemoveFromNextUp: { taskID in
                                if let item = planItems.first(where: { $0.id == taskID }) {
                                    updateNextUp(for: item, isNextUp: false)
                                }
                            },
                            onEditTask: { task in
                                taskToEditDirectly = task
                            },
                            onDeleteTask: { task in
                                deleteTask(task)
                            }
                        )

                        // Main content based on view mode
                        switch selectedMode {
                        case .list:
                            listView
                        case .eisenhowerMatrix:
                            eisenhowerMatrixView
                        case .category:
                            categoryView
                        case .duration:
                            durationView
                        case .dueDate:
                            dueDateView
                        case .tbd:
                            tbdView
                        case .completed:
                            completedView
                        case .recurring:
                            recurringView
                        case .smartPriority:
                            smartPriorityView
                        }
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
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay in
                        if editSeriesMode {
                            updateRecurringSeries(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)
                            editSeriesMode = false
                        } else {
                            updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)
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
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay in
                        updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)
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
        }
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

    private func updateTask(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: task.id, title: title, importance: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)

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

    private func updateRecurringSeries(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil) {
        guard let groupID = task.recurrenceGroupID else { return }
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateRecurringSeries(groupID: groupID, title: title, importance: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay)

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

    // MARK: - View Mode Switcher (Swift Liquid Glass)
    /// All view modes (smartPriority always available — deterministic scoring)
    private var availableViewModes: [ViewMode] {
        ViewMode.allCases
    }

    private var viewModeSwitcher: some View {
        Menu {
            ForEach(availableViewModes) { mode in
                Button {
                    withAnimation(.smooth) {
                        selectedMode = mode
                    }
                } label: {
                    // TBD zeigt Badge mit Anzahl
                    if mode == .tbd && tbdCount > 0 {
                        Label("\(mode.rawValue) (\(tbdCount))", systemImage: mode.icon)
                    } else {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                // TBD im Toggle zeigt Badge
                if selectedMode == .tbd && tbdCount > 0 {
                    Text("\(selectedMode.rawValue) (\(tbdCount))")
                        .font(.headline)
                } else {
                    Text(selectedMode.rawValue)
                        .font(.headline)
                }
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

    // MARK: - List View
    // Using List for swipe actions support (swipe right = Next Up, swipe left = Edit)
    private var listView: some View {
        List {
            ForEach(backlogTasks) { item in
                BacklogRow(
                    item: item,
                    onComplete: { completeTask(item) },
                    onDurationTap: { selectedItemForDuration = item },
                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                    onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { selectedItemForCategory = item },
                    onEditTap: { taskToEditDirectly = item },
                    onDeleteTap: { deleteTask(item) },
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

    // MARK: - Eisenhower Matrix View
    private var eisenhowerMatrixView: some View {
        ScrollView {
            VStack(spacing: 16) {
                QuadrantCard(
                    title: "Do First",
                    subtitle: "Dringend + Wichtig",
                    color: .red,
                    icon: "exclamationmark.3",
                    tasks: doFirstTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) },
                    onComplete: { item in completeTask(item) },
                    onImportanceCycle: { item, newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { item, newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { item in selectedItemForCategory = item },
                    onEditTap: { item in taskToEditDirectly = item },
                    onDeleteTap: { item in deleteTask(item) },
                    onTitleSave: { item, newTitle in saveTitleEdit(for: item, title: newTitle) }
                )

                QuadrantCard(
                    title: "Schedule",
                    subtitle: "Nicht dringend + Wichtig",
                    color: .yellow,
                    icon: "calendar",
                    tasks: scheduleTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) },
                    onComplete: { item in completeTask(item) },
                    onImportanceCycle: { item, newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { item, newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { item in selectedItemForCategory = item },
                    onEditTap: { item in taskToEditDirectly = item },
                    onDeleteTap: { item in deleteTask(item) },
                    onTitleSave: { item, newTitle in saveTitleEdit(for: item, title: newTitle) }
                )

                QuadrantCard(
                    title: "Delegate",
                    subtitle: "Dringend + Weniger wichtig",
                    color: .orange,
                    icon: "person.2",
                    tasks: delegateTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) },
                    onComplete: { item in completeTask(item) },
                    onImportanceCycle: { item, newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { item, newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { item in selectedItemForCategory = item },
                    onEditTap: { item in taskToEditDirectly = item },
                    onDeleteTap: { item in deleteTask(item) },
                    onTitleSave: { item, newTitle in saveTitleEdit(for: item, title: newTitle) }
                )

                QuadrantCard(
                    title: "Eliminate",
                    subtitle: "Nicht dringend + Weniger wichtig",
                    color: .green,
                    icon: "trash",
                    tasks: eliminateTasks,
                    onDurationTap: { item in selectedItemForDuration = item },
                    onAddToNextUp: { item in updateNextUp(for: item, isNextUp: true) },
                    onComplete: { item in completeTask(item) },
                    onImportanceCycle: { item, newImportance in updateImportance(for: item, importance: newImportance) },
                    onUrgencyToggle: { item, newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                    onCategoryTap: { item in selectedItemForCategory = item },
                    onEditTap: { item in taskToEditDirectly = item },
                    onDeleteTap: { item in deleteTask(item) },
                    onTitleSave: { item, newTitle in saveTitleEdit(for: item, title: newTitle) }
                )
            }
            .padding()
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Category View
    private var categoryView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tasksByCategory, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.category)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(group.tasks) { item in
                                BacklogRow(
                                    item: item,
                                    onComplete: { completeTask(item) },
                                    onDurationTap: { selectedItemForDuration = item },
                                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                                    onTap: { taskToEdit = item },
                                    onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                                    onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                                    onCategoryTap: { selectedItemForCategory = item },
                                    onEditTap: { taskToEditDirectly = item },
                                    onDeleteTap: { deleteTask(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Duration View
    private var durationView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tasksByDuration, id: \.bucket) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.bucket)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(group.tasks) { item in
                                BacklogRow(
                                    item: item,
                                    onComplete: { completeTask(item) },
                                    onDurationTap: { selectedItemForDuration = item },
                                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                                    onTap: { taskToEdit = item },
                                    onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                                    onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                                    onCategoryTap: { selectedItemForCategory = item },
                                    onEditTap: { taskToEditDirectly = item },
                                    onDeleteTap: { deleteTask(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Due Date View
    private var dueDateView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tasksByDueDate, id: \.section) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.section)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(group.tasks) { item in
                                BacklogRow(
                                    item: item,
                                    onComplete: { completeTask(item) },
                                    onDurationTap: { selectedItemForDuration = item },
                                    onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                                    onTap: { taskToEdit = item },
                                    onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                                    onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                                    onCategoryTap: { selectedItemForCategory = item },
                                    onEditTap: { taskToEditDirectly = item },
                                    onDeleteTap: { deleteTask(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - TBD View (unvollständige Tasks)
    private var tbdView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tbdTasks) { item in
                    BacklogRow(
                        item: item,
                        onComplete: { completeTask(item) },
                        onDurationTap: { selectedItemForDuration = item },
                        onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                        onTap: { taskToEdit = item },
                        onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                        onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                        onCategoryTap: { selectedItemForCategory = item },
                        onEditTap: { taskToEditDirectly = item },
                        onDeleteTap: { deleteTask(item) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Recurring View (wiederkehrende Tasks)
    private var recurringView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(recurringTasks) { item in
                    BacklogRow(
                        item: item,
                        onComplete: { completeTask(item) },
                        onDurationTap: { selectedItemForDuration = item },
                        onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                        onTap: { taskToEdit = item },
                        onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                        onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                        onCategoryTap: { selectedItemForCategory = item },
                        onEditTap: { handleEditTap(item) },
                        onDeleteTap: { deleteTask(item) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Completed View (erledigte Tasks der letzten 7 Tage)
    private var completedView: some View {
        ScrollView {
            if completedTasks.isEmpty {
                let emptyState = ViewMode.completed.emptyStateMessage
                ContentUnavailableView(
                    emptyState.title,
                    systemImage: "checkmark.circle",
                    description: Text(emptyState.description)
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(completedTasks) { item in
                        CompletedTaskRow(
                            item: item,
                            onUncomplete: { uncompleteTask(item) },
                            onDelete: { deleteTask(item) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Smart Priority View (sorted by priority score, grouped by tier)
    private var smartPriorityView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
                    let tierTasks = backlogTasks
                        .filter { $0.priorityTier == tier }
                        .sorted { $0.priorityScore > $1.priorityScore }
                    if !tierTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
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
                            .padding(.horizontal, 16)

                            LazyVStack(spacing: 8) {
                                ForEach(tierTasks) { item in
                                    BacklogRow(
                                        item: item,
                                        onComplete: { completeTask(item) },
                                        onDurationTap: { selectedItemForDuration = item },
                                        onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                                        onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                                        onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                                        onCategoryTap: { selectedItemForCategory = item },
                                        onEditTap: { taskToEditDirectly = item },
                                        onDeleteTap: { deleteTask(item) },
                                        onTitleSave: { newTitle in
                                            saveTitleEdit(for: item, title: newTitle)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
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

// MARK: - String Extension for Category Localization
private extension String {
    var localizedCategory: String {
        switch self {
        case "deep_work": return "Deep Work"
        case "shallow_work": return "Shallow Work"
        case "meetings": return "Meetings"
        case "maintenance": return "Maintenance"
        case "creative": return "Creative"
        case "strategic": return "Strategic"
        case "income": return "Geld verdienen"
        case "recharge": return "Energie aufladen"
        case "learning": return "Lernen"
        case "giving_back": return "Weitergeben"
        default: return self.capitalized
        }
    }
}

// MARK: - Quadrant Card

struct QuadrantCard: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let tasks: [PlanItem]
    let onDurationTap: (PlanItem) -> Void
    let onAddToNextUp: (PlanItem) -> Void
    var onComplete: ((PlanItem) -> Void)?
    var onImportanceCycle: ((PlanItem, Int) -> Void)?
    var onUrgencyToggle: ((PlanItem, String?) -> Void)?
    var onCategoryTap: ((PlanItem) -> Void)?
    var onEditTap: ((PlanItem) -> Void)?
    var onDeleteTap: ((PlanItem) -> Void)?
    var onTitleSave: ((PlanItem, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.title2.bold())
                    .foregroundStyle(color)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if tasks.isEmpty {
                Text("Keine Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(tasks.prefix(5)) { task in
                    BacklogRow(
                        item: task,
                        onComplete: onComplete.map { callback in { callback(task) } },
                        onDurationTap: { onDurationTap(task) },
                        onAddToNextUp: { onAddToNextUp(task) },
                        onImportanceCycle: onImportanceCycle.map { callback in { newImportance in callback(task, newImportance) } },
                        onUrgencyToggle: onUrgencyToggle.map { callback in { newUrgency in callback(task, newUrgency) } },
                        onCategoryTap: onCategoryTap.map { callback in { callback(task) } },
                        onEditTap: onEditTap.map { callback in { callback(task) } },
                        onDeleteTap: onDeleteTap.map { callback in { callback(task) } },
                        onTitleSave: onTitleSave.map { callback in { newTitle in callback(task, newTitle) } }
                    )
                    .padding(.horizontal, 8)
                    .contextMenu {
                        Button {
                            onAddToNextUp(task)
                        } label: {
                            Label("Next Up", systemImage: "arrow.up.circle.fill")
                        }

                        if let editCallback = onEditTap {
                            Button {
                                editCallback(task)
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                        }

                        Divider()

                        if let deleteCallback = onDeleteTap {
                            Button(role: .destructive) {
                                deleteCallback(task)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                if tasks.count > 5 {
                    Text("+ \(tasks.count - 5) weitere")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}
