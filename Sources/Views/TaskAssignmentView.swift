import SwiftUI
import SwiftData

struct TaskAssignmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var selectedDate = Date()
    @State private var focusBlocks: [FocusBlock] = []
    @State private var unscheduledTasks: [PlanItem] = []
    @State private var allTasks: [PlanItem] = []  // All tasks for block display
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var assignmentFeedback = false
    @State private var blockToEdit: FocusBlock?

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
                        description: Text("Create Focus Blocks in the Blox tab first")
                    )
                    Spacer()
                } else {
                    // Bug 14 Fix: Unified ScrollView for Focus Blocks + Next Up
                    ScrollView {
                        VStack(spacing: 16) {
                            focusBlocksSection

                            if !unscheduledTasks.isEmpty {
                                taskBacklogSection
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .accessibilityIdentifier("assignTabScrollView")
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Assign")
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
            .sheet(item: $blockToEdit) { block in
                EditFocusBlockSheet(
                    block: block,
                    onSave: { start, end in
                        updateBlock(block, startDate: start, endDate: end)
                    },
                    onDelete: {
                        deleteBlock(block)
                    }
                )
            }
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

    // MARK: - Focus Blocks Section (unified in parent ScrollView)

    private var focusBlocksSection: some View {
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
                    },
                    onReorderTasks: { newTaskIDs in
                        reorderTasksInBlock(block: block, newTaskIDs: newTaskIDs)
                    },
                    onEditBlock: {
                        blockToEdit = block
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Task Backlog Section (unified in parent ScrollView)

    private var taskBacklogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                Text("Next Up")
                    .font(.headline)
                Spacer()
                Text("\(unscheduledTasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.blue.opacity(0.15)))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Vertical list instead of horizontal scroll
            VStack(spacing: 6) {
                ForEach(unscheduledTasks) { task in
                    DraggableTaskRow(
                        task: task,
                        availableBlocks: focusBlocks,
                        onAssignToBlock: { taskID, block in
                            assignTaskToBlock(taskID: taskID, block: block)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
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

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let syncedTasks = try await syncEngine.sync()
            // Store all tasks for block display
            allTasks = syncedTasks.filter { !$0.isCompleted }
            // Only show Next Up tasks in the backlog section
            unscheduledTasks = syncedTasks.filter { $0.isNextUp && !$0.isCompleted }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Task Assignment

    private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
        // Search in allTasks (not just unscheduledTasks) to find assigned tasks
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
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
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: block.taskTimes
                )

                // Remove from Next Up after assignment
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.updateNextUp(itemID: taskID, isNextUp: false)

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
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: block.taskTimes
                )

                // Restore to Next Up after removal from block
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.updateNextUp(itemID: taskID, isNextUp: true)

                await loadData()
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Task konnte nicht entfernt werden."
            }
        }
    }

    private func reorderTasksInBlock(block: FocusBlock, newTaskIDs: [String]) {
        Task {
            do {
                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: newTaskIDs,
                    completedTaskIDs: block.completedTaskIDs,
                    taskTimes: block.taskTimes
                )

                await loadData()
                assignmentFeedback.toggle()
            } catch {
                errorMessage = "Reihenfolge konnte nicht geändert werden."
            }
        }
    }

    private func updateBlock(_ block: FocusBlock, startDate: Date, endDate: Date) {
        Task {
            do {
                try eventKitRepo.updateFocusBlockTime(eventID: block.id, startDate: startDate, endDate: endDate)

                // Reschedule notification with new start time
                NotificationService.cancelFocusBlockNotification(blockID: block.id)
                NotificationService.scheduleFocusBlockStartNotification(
                    blockID: block.id,
                    blockTitle: block.title,
                    startDate: startDate
                )

                await loadData()
            } catch {
                errorMessage = "Block konnte nicht aktualisiert werden."
            }
        }
    }

    private func deleteBlock(_ block: FocusBlock) {
        Task {
            do {
                try eventKitRepo.deleteFocusBlock(eventID: block.id)
                NotificationService.cancelFocusBlockNotification(blockID: block.id)
                await loadData()
            } catch {
                errorMessage = "Block konnte nicht gelöscht werden."
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
    let onReorderTasks: ([String]) -> Void
    let onEditBlock: () -> Void

    @State private var isTargeted = false
    @State private var orderedTaskIDs: [String] = []

    private var orderedTasks: [PlanItem] {
        orderedTaskIDs.compactMap { id in tasks.first { $0.id == id } }
    }

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
            // Header - tappable to edit block
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

                // Edit button
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEditBlock()
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
                // Use VStack with dropDestination for intra-block reordering
                // Preserves accessibility identifiers (List with editMode absorbs them)
                VStack(spacing: 6) {
                    ForEach(orderedTasks) { task in
                        TaskRowInBlock(task: task) {
                            onRemoveTask(task.id)
                        }
                        .dropDestination(for: PlanItemTransfer.self) { items, _ in
                            guard let draggedItem = items.first else { return false }
                            reorderTask(draggedID: draggedItem.id, targetID: task.id)
                            return true
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(tasks.count * 50), 300))
                .onAppear {
                    orderedTaskIDs = tasks.map { $0.id }
                }
                .onChange(of: tasks.map { $0.id }) { _, newTaskIDs in
                    orderedTaskIDs = newTaskIDs
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
        .accessibilityIdentifier("focusBlockCard_\(block.id)")
    }

    // MARK: - Reorder Logic

    private func reorderTask(draggedID: String, targetID: String) {
        guard draggedID != targetID else { return }
        guard orderedTaskIDs.contains(draggedID) else { return }

        var newOrder = orderedTaskIDs
        newOrder.removeAll { $0 == draggedID }

        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex)
        }

        orderedTaskIDs = newOrder
        onReorderTasks(newOrder)
    }
}

// MARK: - Task Row In Block (for Focus Blocks with Drag&Drop)

struct TaskRowInBlock: View {
    let task: PlanItem
    let onRemove: () -> Void

    var body: some View {
        // Outer container for accessibility identifier
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Drag handle for reordering
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("dragHandle_\(task.id)")

                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityIdentifier("taskTitle_\(task.id)")

                Spacer()

                Text("\(task.effectiveDuration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button { onRemove() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("removeTaskButton_\(task.id)")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.background)
        )
        .draggable(PlanItemTransfer(from: task))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("taskInBlock_\(task.id)")
    }
}

// MARK: - Assigned Task Row (kept for compatibility)

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

// MARK: - Draggable Task Row (Vertical Layout)

struct DraggableTaskRow: View {
    let task: PlanItem
    let availableBlocks: [FocusBlock]
    let onAssignToBlock: (String, FocusBlock) -> Void

    @State private var showBlockSelection = false

    private func timeString(_ block: FocusBlock) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: block.startDate)
    }

    private func handleMoveUp() {
        switch availableBlocks.count {
        case 0: break  // Button disabled
        case 1: onAssignToBlock(task.id, availableBlocks[0])
        default: showBlockSelection = true
        }
    }

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
                handleMoveUp()
            } label: {
                Image(systemName: "arrow.up.circle")
                    .font(.title3)
                    .foregroundStyle(availableBlocks.isEmpty ? .gray : .blue)
            }
            .buttonStyle(.plain)
            .disabled(availableBlocks.isEmpty)
            .accessibilityIdentifier("moveUpButton")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        )
        .draggable(PlanItemTransfer(from: task))
        .confirmationDialog("Block auswählen", isPresented: $showBlockSelection) {
            ForEach(availableBlocks) { block in
                Button("\(block.title) (\(timeString(block)))") {
                    onAssignToBlock(task.id, block)
                }
            }
        }
    }
}

// MARK: - Draggable Task Chip (kept for compatibility)

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
