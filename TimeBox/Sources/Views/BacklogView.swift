import SwiftUI
import SwiftData

struct BacklogView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var planItems: [PlanItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var reorderTrigger = false
    @State private var selectedItemForDuration: PlanItem?
    @State private var durationFeedback = false
    @State private var showCreateTask = false

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
                    ContentUnavailableView(
                        "Keine Tasks",
                        systemImage: "checklist",
                        description: Text("Tippe auf + um einen neuen Task zu erstellen.")
                    )
                } else {
                    List {
                        ForEach(planItems) { item in
                            BacklogRow(item: item) {
                                selectedItemForDuration = item
                            }
                        }
                        .onMove(perform: moveItems)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadTasks()
                    }
                }
            }
            .navigationTitle("Backlog")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTaskButton")
                }
            }
            .withSettingsToolbar()
            .sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
            .sensoryFeedback(.success, trigger: durationFeedback)
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
            .sheet(isPresented: $showCreateTask) {
                CreateTaskView {
                    Task {
                        await loadTasks()
                    }
                }
            }
        }
        .task {
            await loadTasks()
        }
    }

    private func loadTasks() async {
        isLoading = true
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

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Dauer konnte nicht gespeichert werden."
        }
    }
}

// MARK: - Eisenhower Matrix View

struct EisenhowerMatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var planItems: [PlanItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var selectedItemForDuration: PlanItem?

    private var doFirstTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priority == 3 && !$0.isCompleted }
    }

    private var scheduleTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priority == 3 && !$0.isCompleted }
    }

    private var delegateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "urgent" && $0.priority < 3 && !$0.isCompleted }
    }

    private var eliminateTasks: [PlanItem] {
        planItems.filter { $0.urgency == "not_urgent" && $0.priority < 3 && !$0.isCompleted }
    }

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
                    ContentUnavailableView(
                        "Keine Tasks",
                        systemImage: "checklist",
                        description: Text("Erstelle Tasks im Backlog.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            QuadrantCard(
                                title: "Do First",
                                subtitle: "Dringend + Wichtig",
                                color: .red,
                                icon: "exclamationmark.3",
                                tasks: doFirstTasks,
                                onDurationTap: { item in
                                    selectedItemForDuration = item
                                }
                            )

                            QuadrantCard(
                                title: "Schedule",
                                subtitle: "Nicht dringend + Wichtig",
                                color: .yellow,
                                icon: "calendar",
                                tasks: scheduleTasks,
                                onDurationTap: { item in
                                    selectedItemForDuration = item
                                }
                            )

                            QuadrantCard(
                                title: "Delegate",
                                subtitle: "Dringend + Weniger wichtig",
                                color: .orange,
                                icon: "person.2",
                                tasks: delegateTasks,
                                onDurationTap: { item in
                                    selectedItemForDuration = item
                                }
                            )

                            QuadrantCard(
                                title: "Eliminate",
                                subtitle: "Nicht dringend + Weniger wichtig",
                                color: .green,
                                icon: "trash",
                                tasks: eliminateTasks,
                                onDurationTap: { item in
                                    selectedItemForDuration = item
                                }
                            )
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadTasks()
                    }
                }
            }
            .navigationTitle("Eisenhower Matrix")
            .sheet(item: $selectedItemForDuration) { item in
                DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                    updateDuration(for: item, minutes: newDuration)
                    selectedItemForDuration = nil
                }
            }
        }
        .task {
            await loadTasks()
        }
    }

    private func loadTasks() async {
        isLoading = true
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

    private func updateDuration(for item: PlanItem, minutes: Int?) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.updateDuration(itemID: item.id, minutes: minutes)

            Task {
                await loadTasks()
            }
        } catch {
            errorMessage = "Dauer konnte nicht gespeichert werden."
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
                    BacklogRow(item: task) {
                        onDurationTap(task)
                    }
                    .padding(.horizontal, 8)
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
