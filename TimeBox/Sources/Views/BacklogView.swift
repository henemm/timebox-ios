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
