//
//  MacAssignView.swift
//  FocusBloxMac
//
//  Task Assignment View - Assign Next Up tasks to Focus Blocks
//

import SwiftUI
import SwiftData

/// Assign View showing Focus Blocks with their tasks and Next Up tasks for assignment
struct MacAssignView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<LocalTask> { $0.isNextUp && !$0.isCompleted },
           sort: \LocalTask.nextUpSortOrder)
    private var nextUpTasks: [LocalTask]

    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted })
    private var allTasks: [LocalTask]

    @Binding var selectedDate: Date
    @Binding var highlightedBlockID: String?

    @State private var focusBlocks: [FocusBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var assignmentFeedback = false

    private let eventKitRepo = EventKitRepository()

    var body: some View {
        HSplitView {
            // Left: Focus Blocks with assigned tasks
            focusBlocksSection
                .frame(minWidth: 400)

            // Right: Next Up Tasks (available for assignment)
            nextUpSection
                .frame(minWidth: 250, maxWidth: 350, maxHeight: .infinity)
        }
        .navigationTitle("Zuweisen")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                MacDateNavigator(selectedDate: $selectedDate)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadFocusBlocks() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Aktualisieren")
            }
        }
        .task {
            await loadFocusBlocks()
        }
        .onChange(of: selectedDate) {
            Task { await loadFocusBlocks() }
        }
        .sensoryFeedback(.success, trigger: assignmentFeedback)
    }

    // MARK: - Focus Blocks Section

    @ViewBuilder
    private var focusBlocksSection: some View {
        if isLoading {
            ProgressView("Lade Focus Blocks...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ContentUnavailableView(
                "Fehler",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if focusBlocks.isEmpty {
            ContentUnavailableView(
                "Keine Focus Blocks",
                systemImage: "rectangle.split.3x1",
                description: Text("Erstelle Focus Blocks in der Planen-Ansicht")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(focusBlocks) { block in
                            MacFocusBlockCard(
                                block: block,
                                tasks: tasksForBlock(block),
                                onDropTask: { taskID in
                                    Task { await assignTaskToBlock(taskID: taskID, block: block) }
                                },
                                onRemoveTask: { taskID in
                                    Task { await removeTaskFromBlock(taskID: taskID, block: block) }
                                },
                                onReorderTasks: { newOrder in
                                    Task { await reorderTasksInBlock(newOrder: newOrder, block: block) }
                                }
                            )
                            .id(block.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: highlightedBlockID) { _, newValue in
                    if let blockID = newValue {
                        withAnimation(.smooth) {
                            proxy.scrollTo(blockID, anchor: .top)
                        }
                        // Reset after scroll
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            highlightedBlockID = nil
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Next Up Section

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Next Up", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                Spacer()
                Text("\(nextUpTasks.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding()

            Divider()

            // Task List
            if nextUpTasks.isEmpty {
                ContentUnavailableView(
                    "Keine Tasks",
                    systemImage: "tray",
                    description: Text("Markiere Tasks als Next Up im Backlog")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(nextUpTasks, id: \.uuid) { task in
                            MacDraggableTaskRow(task: task)
                                .draggable(MacTaskTransfer(from: task))
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Info Footer
            Text("Tasks in einen Focus Block ziehen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Data Loading

    private func loadFocusBlocks() async {
        isLoading = true
        errorMessage = nil

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Kein Zugriff auf Kalender"
                isLoading = false
                return
            }

            // Nur zukuenftige und aktive Bloecke anzeigen (keine abgelaufenen)
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: selectedDate)
                .filter { !$0.isPast }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Task Helpers

    private func tasksForBlock(_ block: FocusBlock) -> [LocalTask] {
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
        }
    }

    // MARK: - Assignment Actions

    private func assignTaskToBlock(taskID: String, block: FocusBlock) async {
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
            if let task = allTasks.first(where: { $0.id == taskID }) {
                task.isNextUp = false
                try? modelContext.save()
            }

            await loadFocusBlocks()
            assignmentFeedback.toggle()
        } catch {
            errorMessage = "Fehler beim Zuweisen: \(error.localizedDescription)"
        }
    }

    private func removeTaskFromBlock(taskID: String, block: FocusBlock) async {
        do {
            var updatedTaskIDs = block.taskIDs
            updatedTaskIDs.removeAll { $0 == taskID }

            try eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: updatedTaskIDs,
                completedTaskIDs: block.completedTaskIDs,
                taskTimes: block.taskTimes
            )

            // Restore to Next Up after removal
            if let task = allTasks.first(where: { $0.id == taskID }) {
                task.isNextUp = true
                try? modelContext.save()
            }

            await loadFocusBlocks()
            assignmentFeedback.toggle()
        } catch {
            errorMessage = "Fehler beim Entfernen: \(error.localizedDescription)"
        }
    }

    private func reorderTasksInBlock(newOrder: [String], block: FocusBlock) async {
        do {
            try eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: newOrder,
                completedTaskIDs: block.completedTaskIDs,
                taskTimes: block.taskTimes
            )

            await loadFocusBlocks()
        } catch {
            errorMessage = "Fehler beim Umsortieren: \(error.localizedDescription)"
        }
    }
}

// MARK: - Focus Block Card (for Assign View)

struct MacFocusBlockCard: View {
    let block: FocusBlock
    let tasks: [LocalTask]
    let onDropTask: (String) -> Void
    let onRemoveTask: (String) -> Void
    let onReorderTasks: ([String]) -> Void

    @State private var isDropTargeted = false
    @State private var orderedTasks: [LocalTask] = []

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private var totalDuration: Int {
        tasks.compactMap(\.estimatedDuration).reduce(0, +)
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

            Divider()

            // Tasks in block
            if orderedTasks.isEmpty {
                HStack {
                    Spacer()
                    Text("Tasks hierher ziehen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                List {
                    ForEach(orderedTasks, id: \.uuid) { task in
                        MacTaskInBlockRow(task: task) {
                            onRemoveTask(task.id)
                        }
                    }
                    .onMove(perform: moveTask)
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(orderedTasks.count * 50))
                .scrollDisabled(true)
            }
        }
        .onAppear {
            orderedTasks = tasks
        }
        .onChange(of: tasks) {
            orderedTasks = tasks
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTargeted ? .blue.opacity(0.2) : .blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDropTargeted ? .blue : .blue.opacity(0.3), lineWidth: isDropTargeted ? 2 : 1)
        )
        .dropDestination(for: MacTaskTransfer.self) { items, _ in
            guard let item = items.first else { return false }
            onDropTask(item.id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = targeted
            }
        }
        .accessibilityIdentifier("focusBlockCard_\(block.id)")
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        orderedTasks.move(fromOffsets: source, toOffset: destination)
        let newOrder = orderedTasks.map { $0.id }
        onReorderTasks(newOrder)
    }
}

// MARK: - Task In Block Row

struct MacTaskInBlockRow: View {
    let task: LocalTask
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if let duration = task.estimatedDuration {
                Text("\(duration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("removeTaskButton_\(task.id)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .accessibilityIdentifier("taskInBlock_\(task.id)")
    }
}

// MARK: - Draggable Task Row (Next Up List)

struct MacDraggableTaskRow: View {
    let task: LocalTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let duration = task.estimatedDuration {
                        Label("\(duration) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !task.taskType.isEmpty {
                        CategoryBadge(taskType: task.taskType)
                    }
                }
            }

            Spacer()

            if task.isTbd {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MacAssignView(
        selectedDate: .constant(Date()),
        highlightedBlockID: .constant(nil)
    )
    .frame(width: 800, height: 600)
}
