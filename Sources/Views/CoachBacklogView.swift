import SwiftUI
import SwiftData

/// Coach-mode Backlog: Monster header + ranked tasks (matching first, rest below).
/// Replaces BacklogView when coachModeEnabled == true.
struct CoachBacklogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @AppStorage("selectedCoach") private var selectedCoach: String = ""
    @State private var planItems: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateTask = false
    @State private var taskToEdit: PlanItem?
    @State private var searchText: String = ""

    // MARK: - Task Sections (via shared CoachBacklogViewModel)

    private var searchFilteredItems: [PlanItem] {
        guard !searchText.isEmpty else { return planItems }
        return planItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var relevantTasks: [PlanItem] {
        CoachBacklogViewModel.relevantTasks(from: searchFilteredItems, selectedCoach: selectedCoach)
    }

    private var nextUpTasks: [PlanItem] {
        CoachBacklogViewModel.nextUpTasks(from: searchFilteredItems)
    }

    private var otherTasks: [PlanItem] {
        CoachBacklogViewModel.otherTasks(from: searchFilteredItems, selectedCoach: selectedCoach)
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

            if !nextUpTasks.isEmpty {
                Section {
                    ForEach(nextUpTasks) { item in
                        coachRow(item)
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
                .accessibilityIdentifier("coachNextUpSection")
            }

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

    // MARK: - Monster Header (shared component)

    private var monsterHeader: some View {
        MonsterIntentionHeader(selectedCoach: selectedCoach, imageHeight: 100)
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
            onEditTap: { taskToEdit = item },
            onDeleteTap: { deleteTask(item) },
            onTitleSave: { newTitle in saveTitleEdit(for: item, title: newTitle) },
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
        }
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
}
