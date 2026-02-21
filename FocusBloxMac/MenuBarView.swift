//
//  MenuBarView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import Combine

/// Timer formatting for Menu Bar label and popover
enum MenuBarTimerFormatter {
    /// Format seconds as mm:ss (e.g. 863 -> "14:23")
    static func format(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

/// Menu Bar popover content showing current focus state and quick actions
struct MenuBarView: View {
    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && $0.isNextUp },
           sort: \LocalTask.nextUpSortOrder)
    private var nextUpTasks: [LocalTask]

    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp },
           sort: \LocalTask.createdAt, order: .reverse)
    private var backlogTasks: [LocalTask]

    @Query private var allTasks: [LocalTask]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.eventKitRepository) private var eventKitRepo

    // Existing state
    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    @State private var isNextUp = false

    // FocusBlock state
    @State private var activeBlock: FocusBlock?
    @State private var currentTime = Date()
    @State private var taskStartTime: Date?
    @State private var lastTaskID: String?

    // Timer: 1s when active block, 60s polling otherwise
    private let activeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let pollingTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Focus Section (NEW - above header)
            focusSection
                .accessibilityIdentifier("menubar_focusSection")

            Divider()

            // Header
            header

            Divider()

            // Quick Add
            quickAddSection

            Divider()

            // Next Up Tasks
            nextUpSection

            if !backlogTasks.isEmpty {
                Divider()
                backlogPreview
            }

            Divider()

            // Footer Actions
            footerActions
        }
        .padding()
        .frame(width: 300)
        .onAppear { loadFocusBlock() }
        .onReceive(activeTimer) { time in
            guard activeBlock != nil else { return }
            currentTime = time
        }
        .onReceive(pollingTimer) { _ in
            guard activeBlock == nil else { return }
            loadFocusBlock()
        }
    }

    // MARK: - Focus Section

    @ViewBuilder
    private var focusSection: some View {
        if let block = activeBlock {
            activeFocusSection(block: block)
        } else {
            idleFocusSection
        }
    }

    private var idleFocusSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.secondary)
            Text("Kein aktiver Focus Block")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("menubar_idleIndicator")
        }
    }

    private func activeFocusSection(block: FocusBlock) -> some View {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first
        let completedCount = block.completedTaskIDs.count
        let totalCount = block.taskIDs.count
        let blockProgress = min(1.0, currentTime.timeIntervalSince(block.startDate) / block.endDate.timeIntervalSince(block.startDate))

        return VStack(alignment: .leading, spacing: 8) {
            // Block name + remaining time
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(block.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("menubar_blockName")
                Spacer()
                Text(blockRemainingText(block: block))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar + task count
            HStack(spacing: 8) {
                ProgressView(value: max(0, blockProgress))
                    .accessibilityIdentifier("menubar_blockProgress")
                Text("\(completedCount)/\(totalCount) Tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menubar_taskCount")
            }

            // Current task
            if let task = currentTask {
                currentTaskRow(task: task, block: block)
            }
        }
    }

    private func currentTaskRow(task: LocalTask, block: FocusBlock) -> some View {
        // Track task start
        let _ = trackTaskStartIfNeeded(taskID: task.id)

        let taskDurations = tasksForBlock(block).map { (id: $0.id, durationMinutes: $0.estimatedDuration ?? 15) }
        let plannedEnd = TimerCalculator.plannedTaskEndDate(
            blockStartDate: block.startDate,
            blockEndDate: block.endDate,
            taskDurations: taskDurations,
            currentTaskID: task.id
        )
        let remainingSec = TimerCalculator.remainingSeconds(until: plannedEnd, now: currentTime)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text(task.title)
                    .font(.callout)
                    .lineLimit(1)
                    .accessibilityIdentifier("menubar_currentTaskName")
                Spacer()
                Text(MenuBarTimerFormatter.format(seconds: remainingSec))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(remainingSec < 60 ? .red : .primary)
                    .accessibilityIdentifier("menubar_taskTimer")
            }

            if let duration = task.estimatedDuration {
                Text("\(duration) min geschaetzt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    markTaskComplete(taskID: task.id, block: block)
                } label: {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.green)
                .accessibilityIdentifier("menubar_completeTask")

                Button {
                    skipTask(taskID: task.id, block: block)
                } label: {
                    Label("Weiter", systemImage: "forward.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("menubar_skipTask")

                Spacer()
            }
        }
    }

    private func blockRemainingText(block: FocusBlock) -> String {
        let remaining = block.endDate.timeIntervalSince(currentTime)
        let seconds = max(0, Int(remaining))
        return MenuBarTimerFormatter.format(seconds: seconds)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "cube.fill")
                .foregroundStyle(.blue)
            Text("FocusBlox")
                .font(.headline)
            Spacer()
            Text("\(nextUpTasks.count + backlogTasks.count) Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Add

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isAddingTask {
                HStack {
                    TextField("New Task", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTask()
                        }

                    Button(action: { isNextUp.toggle() }) {
                        Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .foregroundStyle(isNextUp ? .blue : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Next Up")
                    .accessibilityIdentifier("qc_nextUpButton")

                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(newTaskTitle.isEmpty)

                    Button(action: { isAddingTask = false }) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button(action: { isAddingTask = true }) {
                    Label("Quick Add Task", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Next Up Section

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Up")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if nextUpTasks.isEmpty {
                Text("No tasks staged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                ForEach(nextUpTasks.prefix(3), id: \.uuid) { task in
                    MenuBarTaskRow(task: task) {
                        toggleComplete(task)
                    }
                }

                if nextUpTasks.count > 3 {
                    Text("+\(nextUpTasks.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Backlog Preview

    private var backlogPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(backlogTasks.prefix(2), id: \.uuid) { task in
                MenuBarTaskRow(task: task) {
                    toggleComplete(task)
                }
            }

            if backlogTasks.count > 2 {
                Text("+\(backlogTasks.count - 2) more in backlog")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer Actions

    private var footerActions: some View {
        HStack {
            Button("Open FocusBlox") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "FocusBlox" || $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    // MARK: - Data Loading

    private func loadFocusBlock() {
        Task {
            let hasAccess = try? await eventKitRepo.requestAccess()
            guard hasAccess == true else { return }
            let blocks = try? eventKitRepo.fetchFocusBlocks(for: Date())
            activeBlock = blocks?.first { $0.isActive }
        }
    }

    // MARK: - Task Helpers

    private func tasksForBlock(_ block: FocusBlock) -> [LocalTask] {
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
        }
    }

    private func trackTaskStartIfNeeded(taskID: String) {
        if lastTaskID != taskID {
            lastTaskID = taskID
            taskStartTime = Date()
        }
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let title = newTaskTitle
        let shouldMarkNextUp = isNextUp
        newTaskTitle = ""
        isAddingTask = false
        isNextUp = false

        Task {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let task = try? await taskSource.createTask(title: title, taskType: "")
            if shouldMarkNextUp, let task {
                task.isNextUp = true
                task.nextUpSortOrder = Int.max
                try? modelContext.save()
            }
        }
    }

    private func toggleComplete(_ task: LocalTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
            task.assignedFocusBlockID = nil
            task.isNextUp = false
        } else {
            task.completedAt = nil
        }
    }

    private func markTaskComplete(taskID: String, block: FocusBlock) {
        Task {
            _ = try? FocusBlockActionService.completeTask(
                taskID: taskID,
                block: block,
                taskStartTime: taskStartTime,
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            taskStartTime = nil
            loadFocusBlock()
        }
    }

    private func skipTask(taskID: String, block: FocusBlock) {
        Task {
            _ = try? FocusBlockActionService.skipTask(
                taskID: taskID,
                block: block,
                taskStartTime: taskStartTime,
                eventKitRepo: eventKitRepo
            )
            taskStartTime = nil
            loadFocusBlock()
        }
    }
}

// MARK: - Menu Bar Task Row

struct MenuBarTaskRow: View {
    let task: LocalTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.borderless)

            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.isCompleted)

            Spacer()

            if let duration = task.estimatedDuration {
                Text("\(duration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if task.isTbd {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .font(.callout)
    }
}

#Preview {
    MenuBarView()
}
