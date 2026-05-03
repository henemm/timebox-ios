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
    @Environment(DeferredSortController.self) private var deferredSort
    @Environment(DeferredCompletionController.self) private var deferredCompletion
    @AppStorage("backlogViewMode") private var selectedMode: ViewMode = .priority
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = false
    @AppStorage("remindersMarkCompleteOnImport") private var remindersMarkCompleteOnImport: Bool = true
    @State private var planItems: [PlanItem] = []
    @State private var allRecurringItems: [PlanItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var importStatusMessage: String?
    // RW 2.4b: isParkdeckExpanded entfernt — "Geparkt" ist immer offen
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
    @StateObject private var shakeUndoHandler = ShakeUndoHandler()
    @State private var showSettings = false
    @State private var focusSprintConflictTitle: String?
    @State private var focusSprintFeedback = false
    @State private var showHygieneSheet = false
    @State private var taskForDurationPicker: PlanItem?
    // Feature #293 — "Eigenes Datum" im Verschieben-Dialog
    @State private var showCustomDateSheet: Bool = false
    @State private var customDateTaskID: String? = nil
    @State private var customDate: Date = Date()

    // MARK: - Stale Tasks (Backlog Hygiene)
    private var staleTasks: [PlanItem] {
        BacklogHealthService.findStaleTasks(
            in: backlogTasks,
            staleAgeDays: AppSettings.shared.backlogStaleAgeDays,
            staleRescheduleCount: AppSettings.shared.backlogStaleRescheduleCount
        )
    }

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
        planItems.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && !$0.isBlocked && matchesSearch($0) }
            .sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
    }

    /// All non-completed backlog tasks (including blocked ones for grouping)
    private var allBacklogTasks: [PlanItem] {
        planItems.filter { !$0.isCompleted && !$0.isNextUp && $0.assignedFocusBlockID == nil && matchesSearch($0) }
    }

    private var backlogTasks: [PlanItem] {
        // Top-level only: exclude blocked tasks (they appear under their blocker)
        allBacklogTasks.topLevelTasks
    }

    /// Blocked tasks that depend on the given blocker task ID
    private func blockedTasks(for blockerID: String) -> [PlanItem] {
        allBacklogTasks.dependents(of: blockerID)
    }

    // MARK: - Recurring Tasks (only templates = series overview)
    private var recurringTasks: [PlanItem] {
        allRecurringItems.filter { $0.isTemplate && !$0.isCompleted && matchesSearch($0) }
    }

    // MARK: - Overdue Tasks (dueDate < today, sorted by priority score)
    private var overdueTasks: [PlanItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return backlogTasks.filter { item in
            guard let due = item.dueDate else { return false }
            return due < startOfToday
        }.sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
    }

    // MARK: - Tier-basierte Sektionen (RW 2.4b)

    /// Tasks für eine bestimmte Tier-Gruppe, exklusive Überfällige und Geparkte
    private func tasksForTierGroup(_ tiers: [TaskPriorityScoringService.PriorityTier]) -> [PlanItem] {
        let overdueIDs = Set(overdueTasks.map(\.id))
        return backlogTasks
            .filter { !$0.isInParkdeck && !overdueIDs.contains($0.id) && tiers.contains(effectivePriorityTier(for: $0)) }
            .sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
    }

    private var dringendTasks: [PlanItem] { tasksForTierGroup([.doNow]) }
    private var baldTasks: [PlanItem] { tasksForTierGroup([.planSoon]) }
    private var spaeterTasks: [PlanItem] { tasksForTierGroup([.eventually, .someday]) }

    // MARK: - Geparkt (nur manuell, RW 2.4b)
    private var geparktTasks: [PlanItem] {
        backlogTasks
            .filter { $0.isInParkdeck }
            .sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
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
                    Button {
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")

                    viewModeSwitcher

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityIdentifier("settingsButton")
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
            .sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
            .sensoryFeedback(.success, trigger: durationFeedback)
            .sensoryFeedback(.success, trigger: nextUpFeedback)
            .sensoryFeedback(.success, trigger: completeFeedback)
            .sensoryFeedback(.impact(weight: .medium), trigger: focusSprintFeedback)
            .alert("Aktiver Focus Block", isPresented: Binding(
                get: { focusSprintConflictTitle != nil },
                set: { if !$0 { focusSprintConflictTitle = nil } }
            )) {
                Button("OK") { focusSprintConflictTitle = nil }
            } message: {
                Text("Es läuft bereits ein Focus Block: \"\(focusSprintConflictTitle ?? "")\".\nBitte beende ihn zuerst.")
            }
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    let capturedItem = item
                    selectedItemForDuration = nil
                    updateDuration(for: capturedItem, minutes: newDuration)
                }
            }
            .sheet(item: $selectedItemForImportance) { item in
                ImportancePicker(currentImportance: item.importance) { newImportance in
                    let capturedItem = item
                    selectedItemForImportance = nil
                    updateImportance(for: capturedItem, importance: newImportance)
                }
            }
            .sheet(item: $selectedItemForCategory) { item in
                CategoryPicker(currentCategory: item.taskType) { newCategory in
                    let capturedItem = item
                    selectedItemForCategory = nil
                    updateCategory(for: capturedItem, category: newCategory)
                }
            }
            .sheet(item: $taskToEditDirectly) { task in
                editFormSheet(for: task)
            }
            .sheet(isPresented: $showCreateTask) {
                TaskFormSheet {
                    Task {
                        await loadTasks()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHygieneSheet) {
                BacklogHygieneView(staleTasks: staleTasks)
            }
            .sheet(isPresented: $showCustomDateSheet) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "",
                            selection: $customDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Eigenes Datum")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                showCustomDateSheet = false
                            }
                            .accessibilityIdentifier("customDateCancelButton")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Bestätigen") {
                                applyCustomDatePostpone()
                                showCustomDateSheet = false
                            }
                            .accessibilityIdentifier("customDateConfirmButton")
                        }
                    }
                }
                .accessibilityIdentifier("customDateSheet")
                .accessibilityElement(children: .contain)
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationActionDelegate.navigateToBacklogHygieneNotification)) { _ in
                showHygieneSheet = true
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
        #if canImport(UIKit)
        .onShake {
            shakeUndoHandler.requestShakeUndo()
        }
        #endif
        .confirmationDialog("Rückgängig machen?", isPresented: $shakeUndoHandler.showUndoConfirmation) {
            Button("Rückgängig machen") {
                shakeUndoHandler.confirmShakeUndo(in: modelContext)
                completeFeedback.toggle()
                Task { await loadTasks() }
            }
            Button("Abbrechen", role: .cancel) {
                shakeUndoHandler.cancelShakeUndo()
            }
        }
        .alert("Rückgängig", isPresented: $shakeUndoHandler.showUndoAlert) {
            Button("OK") { }
        } message: {
            Text(shakeUndoHandler.undoResultMessage)
        }
        .task(id: remindersSyncEnabled) {
            await loadTasks()
        }
        .onChange(of: cloudKitMonitor.remoteChangeCount) { oldVal, newVal in
            print("[CloudKit Debug] remoteChange onChange FIRED: \(oldVal) -> \(newVal)")
            guard deferredSort.pendingIDs.isEmpty else {
                print("[CloudKit Debug] Skipping refresh — deferred sort pending")
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                await refreshLocalTasks()
            }
        }
        .refreshable {
            await loadTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: LocalTaskSource.taskCreatedNotification)) { _ in
            Task { await loadTasks() }
        }
        .errorAlert(message: $errorMessage)
    }

    private func loadTasks() async {
        cloudKitMonitor.triggerSync()
        isLoading = true

        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            planItems = try await syncEngine.sync()
            planItems.populateDependentCounts()
            applyRecurringStacking()
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
            planItems.populateDependentCounts()
            applyRecurringStacking()
            allRecurringItems = try await syncEngine.syncRecurringTasks()

            // Enrich remote tasks (Watch, Share Extension, Siri) that arrived without attributes
            let enrichment = SmartTaskEnrichmentService(modelContext: modelContext)
            let enriched = await enrichment.enrichAllTbdTasks()
            if enriched > 0 {
                planItems = try await syncEngine.sync()
                planItems.populateDependentCounts()
            applyRecurringStacking()
            }

            print("[CloudKit Debug] refreshLocalTasks() DONE - new planItems: \(planItems.count), enriched: \(enriched)")
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

            // Freeze sort order and update PlanItem so badge shows new value immediately
            freezeSortOrder()
            if let itemUUID = UUID(uuidString: item.id) {
                let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
                if let task = try modelContext.fetch(descriptor).first,
                   let index = planItems.firstIndex(where: { $0.id == item.id }) {
                    planItems[index] = PlanItem(localTask: task)
                }
            }
            scheduleDeferredResort(for: item.id)
        } catch {
            errorMessage = "Dauer konnte nicht gespeichert werden."
        }
    }

    private func startFocusSprint(for item: PlanItem, duration: Int? = nil) {
        do {
            let result = try FocusBlockActionService.startImmediate(
                taskID: item.id,
                eventKitRepo: eventKitRepo,
                modelContext: modelContext,
                durationMinutes: duration
            )
            switch result {
            case .started:
                focusSprintFeedback.toggle()
                NotificationCenter.default.post(name: .focusSprintStarted, object: nil)
            case .blockedByActiveBlock(let title):
                focusSprintConflictTitle = title
            }
        } catch {
            errorMessage = "FocusBlox konnte nicht gestartet werden: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func editFormSheet(for task: PlanItem) -> some View {
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

    private func updateNextUp(for item: PlanItem, isNextUp: Bool) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateNextUp(itemID: item.id, isNextUp: isNextUp)
            nextUpFeedback.toggle()

            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Heute-Status konnte nicht geändert werden."
        }
    }

    private func updateTask(_ task: PlanItem, title: String, priority: Int?, duration: Int?, tags: [String], urgency: String?, taskType: String, dueDate: Date?, description: String?, recurrencePattern: String? = nil, recurrenceWeekdays: [Int]? = nil, recurrenceMonthDay: Int? = nil, recurrenceInterval: Int? = nil) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(itemID: task.id, title: title, importance: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description, recurrencePattern: recurrencePattern, recurrenceWeekdays: recurrenceWeekdays, recurrenceMonthDay: recurrenceMonthDay, recurrenceInterval: recurrenceInterval)

            Task {
                await SmartNotificationEngine.reconcile(
                    reason: .taskChanged,
                    context: modelContext,
                    eventKitRepo: eventKitRepo
                )
                await refreshLocalTasks()
            }
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
            // Freeze sort order BEFORE replacing PlanItem — badge updates but task stays in place
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
            // Freeze sort order BEFORE replacing PlanItem — badge updates but task stays in place
            freezeSortOrder()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
            scheduleDeferredResort(for: item.id)
        } catch {
            errorMessage = "Dringlichkeit konnte nicht aktualisiert werden."
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
            freezeSortOrder()
            if let index = planItems.firstIndex(where: { $0.id == item.id }) {
                planItems[index] = PlanItem(localTask: task)
            }
            scheduleDeferredResort(for: item.id)
        } catch {
            errorMessage = "Kategorie konnte nicht aktualisiert werden."
        }
    }

    private func updateDiscipline(for item: PlanItem, discipline: String?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateDiscipline(itemID: item.id, discipline: discipline)
            Task { await refreshLocalTasks() }
        } catch {
            errorMessage = "Disziplin konnte nicht geändert werden."
        }
    }

    // MARK: - Deferred Sort Helpers (delegate to shared DeferredSortController)

    private func effectivePriorityScore(for item: PlanItem) -> Int {
        let base = deferredSort.effectiveScore(id: item.id, liveScore: item.priorityScore)
        return base
    }

    private func effectivePriorityTier(for item: PlanItem) -> TaskPriorityScoringService.PriorityTier {
        TaskPriorityScoringService.PriorityTier.from(score: effectivePriorityScore(for: item))
    }

    private func freezeSortOrder() {
        // Freeze ALL visible tasks (backlog + nextUp), not just backlog
        let allVisible = backlogTasks + nextUpTasks
        deferredSort.freeze(scores: Dictionary(allVisible.map { ($0.id, effectivePriorityScore(for: $0)) }, uniquingKeysWith: { _, last in last }))
    }

    private func scheduleDeferredResort(for itemID: String) {
        deferredSort.scheduleDeferredResort(id: itemID) { [self] in
            await refreshLocalTasks()
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
            // Bug #209: Mark template so repair won't resurrect this deleted instance
            if let groupID = task.recurrenceGroupID,
               let pattern = task.recurrencePattern,
               pattern != "none",
               let template = RecurrenceService.findTemplate(groupID: groupID, in: modelContext) {
                template.lastSkippedDate = Date()
            }

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteTask(itemID: task.id)

            Task {
                await SmartNotificationEngine.reconcile(
                    reason: .taskChanged,
                    context: modelContext,
                    eventKitRepo: eventKitRepo
                )
                await loadTasks()
            }
        } catch {
            errorMessage = "Task konnte nicht gelöscht werden."
        }
    }

    private func releaseDependency(_ task: PlanItem) {
        do {
            guard let itemUUID = UUID(uuidString: task.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            if let localTask = try modelContext.fetch(descriptor).first {
                localTask.blockerTaskID = nil
                try modelContext.save()
            }
            Task { await loadTasks() }
        } catch {
            errorMessage = "Abhängigkeit konnte nicht entfernt werden."
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

    // MARK: - Postpone Context Menu (Bug 85-C)

    @ViewBuilder
    private func postponeMenu(for item: PlanItem) -> some View {
        Menu {
            Button {
                postponeTask(item, byDays: 1)
            } label: {
                Label("Morgen", systemImage: "sun.max")
            }
            Button {
                let target = LocalTask.nextSaturdayAt9()
                postponeTaskToDate(item, target)
            } label: {
                Label("Dieses Wochenende", systemImage: "calendar")
            }
            .accessibilityIdentifier("weekendMenuButton")
            Button {
                postponeTask(item, byDays: 7)
            } label: {
                Label("Nächste Woche", systemImage: "calendar.badge.plus")
            }
            Button {
                customDate = Calendar.current.date(
                    bySettingHour: 9, minute: 0, second: 0,
                    of: Date.now.addingTimeInterval(86400)
                ) ?? Date.now
                customDateTaskID = item.id
                showCustomDateSheet = true
            } label: {
                Label("Eigenes Datum...", systemImage: "calendar.badge.clock")
            }
            .accessibilityIdentifier("customDateMenuButton")
        } label: {
            Label("Verschieben", systemImage: "calendar.badge.clock")
        }
    }

    private func postponeTask(_ item: PlanItem, byDays days: Int) {
        guard let taskUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.uuid == taskUUID }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        _ = LocalTask.postpone(task, byDays: days, context: modelContext)
        Task {
            await SmartNotificationEngine.reconcile(
                reason: .taskChanged,
                context: modelContext,
                eventKitRepo: eventKitRepo
            )
            await loadTasks()
        }
    }

    // Feature #293 — "Eigenes Datum" Bestaetigen-Aktion
    private func applyCustomDatePostpone() {
        guard let id = customDateTaskID,
              let taskUUID = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.uuid == taskUUID }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        LocalTask.postpone(task, to: customDate, context: modelContext)
        customDateTaskID = nil
        Task {
            await SmartNotificationEngine.reconcile(
                reason: .taskChanged,
                context: modelContext,
                eventKitRepo: eventKitRepo
            )
            await loadTasks()
        }
    }

    // Wochenende-Quickpick — postpone direkt auf konkretes Date
    private func postponeTaskToDate(_ item: PlanItem, _ date: Date) {
        guard let taskUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { $0.uuid == taskUUID }
        )
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        LocalTask.postpone(task, to: date, context: modelContext)
        Task {
            await SmartNotificationEngine.reconcile(
                reason: .taskChanged,
                context: modelContext,
                eventKitRepo: eventKitRepo
            )
            await loadTasks()
        }
    }

    // MARK: - Parkdeck Actions (RW 2.4)

    private func parkTask(_ item: PlanItem) {
        guard let itemUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        task.isParked = true
        task.modifiedAt = Date()
        try? modelContext.save()
        Task { await loadTasks() }
    }

    private func activateTask(_ item: PlanItem) {
        guard let itemUUID = UUID(uuidString: item.id) else { return }
        let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
        guard let task = try? modelContext.fetch(descriptor).first else { return }
        task.isParked = false
        task.modifiedAt = Date()
        try? modelContext.save()
        Task { await loadTasks() }
    }

    private func completeTask(_ item: PlanItem) {
        completeFeedback.toggle()

        // For stacked recurring tasks: complete the oldest instance (earliest dueDate)
        let targetID: String
        if item.stackedInstanceCount > 1, let groupID = item.recurrenceGroupID {
            let siblings = planItems.filter {
                $0.recurrenceGroupID == groupID && !$0.isCompleted && !$0.isTemplate
            }
            targetID = siblings
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                .first?.id ?? item.id
        } else {
            targetID = item.id
        }

        deferredCompletion.scheduleCompletion(id: item.id) { [modelContext] in
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.completeTask(itemID: targetID)
                await loadTasks()
            } catch {
                errorMessage = "Task konnte nicht als erledigt markiert werden."
            }
        }
    }

    // MARK: - Cancel Completion (BUG-126)

    private func cancelCompletion(_ item: PlanItem) {
        deferredCompletion.cancelCompletion(id: item.id)
        freezeSortOrder()
        scheduleDeferredResort(for: item.id)
    }

    // MARK: - Recurring Stacking (RW_3.5)

    /// Wendet Stacking auf `planItems` an (siehe `RecurringStackingHelper.apply`).
    private func applyRecurringStacking() {
        planItems = RecurringStackingHelper.apply(to: planItems)
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
                    VStack(alignment: .leading, spacing: 8) {
                        BacklogRow(
                            item: item,
                            onComplete: { completeTask(item) },
                            onCancelCompletion: { cancelCompletion(item) },
                            onDurationTap: { selectedItemForDuration = item },
                            onAddToNextUp: { updateNextUp(for: item, isNextUp: false) },
                            onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                            onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                            onCategoryTap: { selectedItemForCategory = item },
                            onEditTap: { taskToEditDirectly = item },
                            onDeleteTap: { deleteTask(item) },
                            onStartFocusSprint: { taskForDurationPicker = item },
                            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
                            isPendingResort: deferredSort.isPending(item.id),
                            isCompletionPending: deferredCompletion.isPending(item.id)
                        )

                        if taskForDurationPicker?.id == item.id {
                            DurationPickerChips(
                                defaultDuration: item.estimatedDuration ?? 25
                            ) { duration in
                                taskForDurationPicker = nil
                                startFocusSprint(for: item, duration: duration)
                            }
                            .padding(.leading, 34)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.spring(duration: 0.3), value: taskForDurationPicker?.id)
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
                    .contextMenu {
                        Button {
                            taskToEditDirectly = item
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        if item.dueDate != nil {
                            postponeMenu(for: item)
                        }
                    } preview: {
                        TaskPreviewView(task: item)
                    }
                }
            } header: {
                HStack {
                    Label("Heute", systemImage: "calendar.circle.fill")
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
                .accessibilityIdentifier("nextUpSection")
            }
        }
    }

    // MARK: - Backlog Row with Swipe Actions (shared helper)
    @ViewBuilder
    private func backlogRowWithSwipe(_ item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BacklogRow(
                item: item,
                onComplete: { completeTask(item) },
                onCancelCompletion: { cancelCompletion(item) },
                onDurationTap: { selectedItemForDuration = item },
                onAddToNextUp: { updateNextUp(for: item, isNextUp: true) },
                onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
                onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
                onCategoryTap: { selectedItemForCategory = item },
                onEditTap: { handleEditTap(item) },
                onDeleteTap: { deleteTask(item) },
                onStartFocusSprint: { taskForDurationPicker = item },
                onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
                isPendingResort: deferredSort.isPending(item.id),
                isCompletionPending: deferredCompletion.isPending(item.id),
                effectiveScore: effectivePriorityScore(for: item)
            )

            if taskForDurationPicker?.id == item.id {
                DurationPickerChips(
                    defaultDuration: item.estimatedDuration ?? 25
                ) { duration in
                    taskForDurationPicker = nil
                    startFocusSprint(for: item, duration: duration)
                }
                .padding(.leading, 34)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: taskForDurationPicker?.id)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                updateNextUp(for: item, isNextUp: true)
            } label: {
                Label("Heute", systemImage: "calendar.circle.fill")
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
        .contextMenu {
            Button {
                handleEditTap(item)
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            if item.dueDate != nil {
                postponeMenu(for: item)
            }
        } preview: {
            TaskPreviewView(task: item)
        }
        // Render blocked dependents directly after this task
        ForEach(blockedTasks(for: item.id)) { blocked in
            blockedRow(blocked)
        }
    }

    // MARK: - Blocked Row (swipe: Edit + Delete + Freigeben)
    private func blockedRow(_ item: PlanItem) -> some View {
        BacklogRow(
            item: item,
            onDurationTap: { selectedItemForDuration = item },
            onImportanceCycle: { newImportance in updateImportance(for: item, importance: newImportance) },
            onUrgencyToggle: { newUrgency in updateUrgency(for: item, urgency: newUrgency) },
            onCategoryTap: { selectedItemForCategory = item },
            onEditTap: { handleEditTap(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
            isPendingResort: deferredSort.isPending(item.id),
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

            // Backlog Hygiene Banner
            if !staleTasks.isEmpty {
                Section {
                    Button {
                        showHygieneSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("\(staleTasks.count) Tasks liegen seit Wochen rum. Aufräumen?")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("hygieneCleanupBanner")
                }
            }

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

            // RW 2.4b: 3 Tier-Sektionen + Geparkt
            tierSection(title: "Dringend", tasks: dringendTasks, color: .red)
            tierSection(title: "Bald", tasks: baldTasks, color: .orange)
            tierSection(title: "Später", tasks: spaeterTasks, color: .yellow)

            // Geparkt (manuell, immer offen)
            if !geparktTasks.isEmpty {
                Section {
                    ForEach(geparktTasks) { item in
                        backlogRowWithSwipe(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    activateTask(item)
                                } label: {
                                    Label("Aktivieren", systemImage: "arrow.up.circle")
                                }
                                .tint(.blue)
                            }
                    }
                } header: {
                    HStack {
                        Text("Geparkt")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(geparktTasks.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("geparktSection")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("backlogTaskList")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 120)
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Tier Section Helper (RW 2.4b)
    @ViewBuilder
    private func tierSection(title: String, tasks: [PlanItem], color: Color) -> some View {
        if !tasks.isEmpty {
            Section {
                ForEach(tasks) { item in
                    backlogRowWithSwipe(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                parkTask(item)
                            } label: {
                                Label("Parken", systemImage: "car.fill")
                            }
                            .tint(.gray)
                        }
                }
            } header: {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(color)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(.caption)
                        .foregroundStyle(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
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
                    onCancelCompletion: { cancelCompletion(item) },
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
                    },
                    isPendingResort: deferredSort.isPending(item.id),
                    isCompletionPending: deferredCompletion.isPending(item.id)
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        updateNextUp(for: item, isNextUp: true)
                    } label: {
                        Label("Heute", systemImage: "calendar.circle.fill")
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
                ForEach(completedTasks.filter { matchesSearch($0) }) { item in
                    CompletedTaskRow(item: item)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteTask(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            uncompleteTask(item)
                        } label: {
                            Label("Wiederherstellen", systemImage: "arrow.uturn.backward.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteTask(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    } preview: {
                        TaskPreviewView(task: item)
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


