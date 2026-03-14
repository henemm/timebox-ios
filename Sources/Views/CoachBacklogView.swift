import SwiftUI
import SwiftData

/// Coach-mode Backlog: Monster header + ranked tasks (matching first, rest below).
/// Replaces BacklogView when coachModeEnabled == true.
struct CoachBacklogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @AppStorage("intentionFilterOptions") private var intentionFilterOptions: String = ""
    @State private var planItems: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateTask = false
    @State private var taskToEdit: PlanItem?
    @State private var searchText: String = ""

    // MARK: - Intention

    private var activeIntentionFilters: [IntentionOption] {
        guard !intentionFilterOptions.isEmpty else { return [] }
        return intentionFilterOptions.split(separator: ",").compactMap {
            IntentionOption(rawValue: String($0))
        }
    }

    private var primaryIntention: IntentionOption? {
        activeIntentionFilters.first
    }

    private var intention: DailyIntention {
        DailyIntention.load()
    }

    // MARK: - Task Sections

    private var incompleteTasks: [PlanItem] {
        planItems.filter { !$0.isCompleted && !$0.isTemplate && matchesSearch($0) }
    }

    private var relevantTasks: [PlanItem] {
        let filters = activeIntentionFilters
        guard !filters.isEmpty, !filters.contains(.survival) else { return [] }
        return incompleteTasks.filter { IntentionOption.matchesFilter(activeOptions: filters, task: $0) }
    }

    private var otherTasks: [PlanItem] {
        let filters = activeIntentionFilters
        guard !filters.isEmpty, !filters.contains(.survival) else { return incompleteTasks }
        let relevantIDs = Set(relevantTasks.map(\.id))
        return incompleteTasks.filter { !relevantIDs.contains($0.id) }
    }

    private func matchesSearch(_ item: PlanItem) -> Bool {
        guard !searchText.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(searchText)
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
                TaskDetailSheet(
                    task: task,
                    onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, _, _, _, _ in
                        updateTask(task, title: title, priority: priority, duration: duration, tags: tags, urgency: urgency, taskType: taskType, dueDate: dueDate, description: description)
                    },
                    onDelete: { deleteTask(task) }
                )
            }
        }
        .searchable(text: $searchText, prompt: "Tasks durchsuchen")
        .task { await loadTasks() }
        .refreshable { await loadTasks() }
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            monsterHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !relevantTasks.isEmpty {
                Section {
                    ForEach(relevantTasks) { item in
                        coachRow(item)
                    }
                } header: {
                    Text("Dein Schwerpunkt")
                        .font(.headline)
                }
                .accessibilityIdentifier("coachRelevantSection")
            }

            Section {
                ForEach(otherTasks) { item in
                    coachRow(item)
                }
            } header: {
                if !relevantTasks.isEmpty {
                    Text("Weitere Tasks")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("coachOtherSection")
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Monster Header

    private var monsterHeader: some View {
        VStack(spacing: 8) {
            if let primary = primaryIntention {
                let discipline = primary.monsterDiscipline
                Image(discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .clipShape(Circle())

                Text(primary.label)
                    .font(.headline)
                    .foregroundStyle(discipline.color)
            } else if intention.isSet {
                let firstSelection = intention.selections.first
                let discipline = firstSelection?.monsterDiscipline ?? .ausdauer
                Image(discipline.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .clipShape(Circle())

                Text(firstSelection?.label ?? "")
                    .font(.headline)
                    .foregroundStyle(discipline.color)
            } else {
                Image(systemName: "sun.and.horizon")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Starte deinen Tag unter Mein Tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachMonsterHeader")
    }

    // MARK: - Coach Row (with Discipline Color)

    private func coachRow(_ item: PlanItem) -> some View {
        let discipline = Discipline.classifyOpen(
            rescheduleCount: item.rescheduleCount,
            importance: item.importance
        )
        return BacklogRow(
            item: item,
            onComplete: { completeTask(item) },
            onEditTap: { taskToEdit = item },
            onDeleteTap: { deleteTask(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
            disciplineColor: discipline.color
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
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
            Button { taskToEdit = item } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Menu("Kategorie") {
                ForEach(TaskCategory.allCases, id: \.rawValue) { category in
                    Button {
                        setCategoryForTask(item, category: category.rawValue)
                    } label: {
                        Label(category.displayName, systemImage: category.icon)
                    }
                }
            }
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
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.completeTask(itemID: item.id)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Task konnte nicht erledigt werden."
        }
    }

    private func deleteTask(_ task: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteTask(itemID: task.id)
            Task { await loadTasks() }
        } catch {
            errorMessage = "Task konnte nicht gelöscht werden."
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

    private func setCategoryForTask(_ item: PlanItem, category: String) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateTask(
                itemID: item.id, title: item.title, importance: item.importance,
                duration: item.estimatedDuration, tags: item.tags,
                urgency: item.urgency, taskType: category,
                dueDate: item.dueDate, description: item.taskDescription
            )
            Task { await loadTasks() }
        } catch {
            errorMessage = "Kategorie konnte nicht geändert werden."
        }
    }
}
