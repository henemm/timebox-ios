import SwiftUI
import SwiftData

struct TaskAssignmentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var selectedDate = Date()
    @State private var focusBlocks: [FocusBlock] = []
    @State private var unscheduledTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var assignmentFeedback = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Lade Daten...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Spacer()
                } else if focusBlocks.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Keine Focus Blocks",
                        systemImage: "rectangle.split.3x1",
                        description: Text("Erstelle zuerst Focus Blocks im \"Blöcke\" Tab")
                    )
                    Spacer()
                } else {
                    focusBlocksList

                    if !unscheduledTasks.isEmpty {
                        Divider()
                        taskBacklog
                    }
                }
            }
            .navigationTitle("Zuordnen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
            .withSettingsToolbar()
            .sensoryFeedback(.success, trigger: assignmentFeedback)
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedDate) {
            Task {
                await loadData()
            }
        }
    }

    // MARK: - Focus Blocks List

    private var focusBlocksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(focusBlocks) { block in
                    FocusBlockCard(
                        block: block,
                        tasks: tasksForBlock(block),
                        onDropTask: { taskID in
                            assignTaskToBlock(taskID: taskID, block: block)
                        },
                        onRemoveTask: { taskID in
                            removeTaskFromBlock(taskID: taskID, block: block)
                        }
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Task Backlog

    private var taskBacklog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unscheduledTasks) { task in
                        DraggableTaskChip(task: task)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Zugriff auf Kalender/Erinnerungen verweigert."
                isLoading = false
                return
            }

            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: selectedDate)

            let syncEngine = SyncEngine(eventKitRepo: eventKitRepo, modelContext: modelContext)
            unscheduledTasks = try await syncEngine.sync()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Task Assignment

    private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
        block.taskIDs.compactMap { taskID in
            unscheduledTasks.first { $0.id == taskID }
        }
    }

    private func assignTaskToBlock(taskID: String, block: FocusBlock) {
        Task {
            do {
                var updatedTaskIDs = block.taskIDs
                if !updatedTaskIDs.contains(taskID) {
                    updatedTaskIDs.append(taskID)
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: updatedTaskIDs,
                    completedTaskIDs: block.completedTaskIDs
                )

                await loadData()
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Task konnte nicht zugeordnet werden."
            }
        }
    }

    private func removeTaskFromBlock(taskID: String, block: FocusBlock) {
        Task {
            do {
                var updatedTaskIDs = block.taskIDs
                updatedTaskIDs.removeAll { $0 == taskID }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: updatedTaskIDs,
                    completedTaskIDs: block.completedTaskIDs
                )

                await loadData()
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Task konnte nicht entfernt werden."
            }
        }
    }
}

// MARK: - Focus Block Card

struct FocusBlockCard: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let onDropTask: (String) -> Void
    let onRemoveTask: (String) -> Void

    @State private var isTargeted = false

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private var totalDuration: Int {
        tasks.reduce(0) { $0 + $1.effectiveDuration }
    }

    private var remainingMinutes: Int {
        block.durationMinutes - totalDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.headline)
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Duration info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totalDuration) / \(block.durationMinutes) min")
                        .font(.caption.monospacedDigit())
                    if remainingMinutes > 0 {
                        Text("\(remainingMinutes) min frei")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if remainingMinutes < 0 {
                        Text("\(-remainingMinutes) min über")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Tasks in block
            if tasks.isEmpty {
                HStack {
                    Spacer()
                    Text("Tasks hierher ziehen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 6) {
                    ForEach(tasks) { task in
                        AssignedTaskRow(task: task) {
                            onRemoveTask(task.id)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? .blue.opacity(0.2) : .blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isTargeted ? .blue : .blue.opacity(0.3), lineWidth: isTargeted ? 2 : 1)
        )
        .dropDestination(for: PlanItemTransfer.self) { items, _ in
            guard let item = items.first else { return false }
            onDropTask(item.id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = targeted
            }
        }
    }
}

// MARK: - Assigned Task Row

struct AssignedTaskRow: View {
    let task: PlanItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text("\(task.effectiveDuration) min")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.background)
        )
    }
}

// MARK: - Draggable Task Chip

struct DraggableTaskChip: View {
    let task: PlanItem

    var body: some View {
        HStack(spacing: 6) {
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Text("\(task.effectiveDuration)m")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
        )
        .draggable(PlanItemTransfer(from: task))
    }
}
