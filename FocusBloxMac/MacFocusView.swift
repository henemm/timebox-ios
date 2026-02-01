//
//  MacFocusView.swift
//  FocusBloxMac
//
//  Focus View - Live Timer during Focus Block
//

import SwiftUI
import SwiftData
import Combine

/// Focus View showing current active Focus Block with timer and task management
struct MacFocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted })
    private var allTasks: [LocalTask]

    @State private var activeBlock: FocusBlock?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSprintReview = false

    // Timer state
    @State private var currentTime = Date()
    @State private var taskStartTime: Date?
    @State private var lastTaskID: String?

    private let eventKitRepo = EventKitRepository()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Lade Focus Block...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Fehler",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let block = activeBlock {
                activeFocusContent(block: block)
            } else {
                noActiveBlockContent
            }
        }
        .navigationTitle("Focus")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Aktualisieren")
            }
        }
        .task {
            await loadData()
        }
        .onReceive(timer) { time in
            currentTime = time
            checkBlockEnd()
        }
        .sheet(isPresented: $showSprintReview) {
            if let block = activeBlock {
                MacSprintReviewSheet(
                    block: block,
                    tasks: tasksForBlock(block),
                    onDismiss: {
                        Task { await loadData() }
                    }
                )
            }
        }
    }

    // MARK: - Active Focus Content

    private func activeFocusContent(block: FocusBlock) -> some View {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first
        let upcomingTasks = Array(remainingTasks.dropFirst())

        return HSplitView {
            // Left: Main Focus Area
            VStack(spacing: 0) {
                // Progress header
                progressHeader(block: block)

                Spacer()

                // Current task
                if let task = currentTask {
                    currentTaskView(task: task, block: block)
                } else {
                    allTasksCompletedView(block: block)
                }

                Spacer()
            }
            .frame(minWidth: 400)

            // Right: Task Queue
            taskQueueSection(
                currentTask: currentTask,
                upcomingTasks: upcomingTasks,
                completedTasks: tasks.filter { block.completedTaskIDs.contains($0.id) }
            )
            .frame(minWidth: 250, maxWidth: 350)
        }
    }

    // MARK: - Progress Header

    private func progressHeader(block: FocusBlock) -> some View {
        let progress = calculateProgress(block: block)
        let remainingMinutes = calculateRemainingMinutes(block: block)

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.title2.weight(.semibold))
                    Text(timeRangeText(block: block))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status badge
                if block.isPast {
                    Text("Beendet")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                } else {
                    Text("Aktiv")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress >= 1 ? .orange : .blue)
                        .frame(width: geometry.size.width * min(progress, 1), height: 8)
                }
            }
            .frame(height: 8)

            // Stats
            HStack {
                if remainingMinutes > 0 {
                    Text("\(remainingMinutes) min verbleibend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Block beendet")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text("\(tasksForBlock(block).filter { block.completedTaskIDs.contains($0.id) }.count)/\(block.taskIDs.count) Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Current Task View

    private func currentTaskView(task: LocalTask, block: FocusBlock) -> some View {
        let taskProgress = calculateTaskProgress(task: task)
        let remainingTaskMinutes = calculateRemainingTaskMinutes(task: task)
        let isOverdue = remainingTaskMinutes <= 0

        return VStack(spacing: 24) {
            Text(isOverdue ? "Zeit abgelaufen" : "Aktueller Task")
                .font(.headline)
                .foregroundStyle(isOverdue ? .red : .secondary)

            // Task progress ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: min(taskProgress, 1))
                    .stroke(
                        isOverdue ? .red : (taskProgress >= 1 ? .orange : .blue),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: taskProgress)

                VStack(spacing: 4) {
                    if remainingTaskMinutes > 0 {
                        Text("\(remainingTaskMinutes)")
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        Text("min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Overdue")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }

            Text(task.title)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let duration = task.estimatedDuration {
                Text("\(duration) min geschätzt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Action buttons
            HStack(spacing: 20) {
                Button {
                    skipTask(taskID: task.id, block: block)
                } label: {
                    Label("Überspringen", systemImage: "forward.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.large)
                .accessibilityIdentifier("taskSkipButton")

                Button {
                    markTaskComplete(taskID: task.id, block: block)
                } label: {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .accessibilityIdentifier("taskCompleteButton")
            }
        }
        .padding()
        .onAppear {
            trackTaskStart(taskID: task.id)
        }
        .onChange(of: task.id) { _, newID in
            trackTaskStart(taskID: newID)
        }
    }

    // MARK: - All Tasks Completed View

    private func allTasksCompletedView(block: FocusBlock) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Alle Tasks erledigt!")
                .font(.title.weight(.semibold))

            Text("Starte das Sprint Review")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showSprintReview = true
            } label: {
                Text("Sprint Review starten")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Task Queue Section

    private func taskQueueSection(currentTask: LocalTask?, upcomingTasks: [LocalTask], completedTasks: [LocalTask]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Task Queue")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Current
                    if let task = currentTask {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aktuell")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TaskQueueRow(task: task, status: .current)
                        }
                    }

                    // Upcoming
                    if !upcomingTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Als Nächstes")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(upcomingTasks, id: \.uuid) { task in
                                TaskQueueRow(task: task, status: .upcoming)
                            }
                        }
                    }

                    // Completed
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Erledigt")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(completedTasks, id: \.uuid) { task in
                                TaskQueueRow(task: task, status: .completed)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - No Active Block Content

    private var noActiveBlockContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("Kein aktiver Focus Block")
                .font(.title.weight(.semibold))

            Text("Focus Blocks werden automatisch aktiv,\nwenn ihre Startzeit erreicht ist")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadData() }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Kein Zugriff auf Kalender"
                isLoading = false
                return
            }

            let blocks = try eventKitRepo.fetchFocusBlocks(for: Date())
            activeBlock = blocks.first { $0.isActive }
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

    private func trackTaskStart(taskID: String) {
        if lastTaskID != taskID {
            lastTaskID = taskID
            taskStartTime = Date()
        }
    }

    // MARK: - Task Actions

    private func markTaskComplete(taskID: String, block: FocusBlock) {
        Task {
            do {
                var updatedCompletedIDs = block.completedTaskIDs
                if !updatedCompletedIDs.contains(taskID) {
                    updatedCompletedIDs.append(taskID)
                }

                var updatedTaskTimes = block.taskTimes
                if let startTime = taskStartTime {
                    let secondsSpent = Int(Date().timeIntervalSince(startTime))
                    updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: block.taskIDs,
                    completedTaskIDs: updatedCompletedIDs,
                    taskTimes: updatedTaskTimes
                )

                taskStartTime = nil
                await loadData()
            } catch {
                errorMessage = "Task konnte nicht als erledigt markiert werden."
            }
        }
    }

    private func skipTask(taskID: String, block: FocusBlock) {
        Task {
            do {
                let remainingTaskIDs = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
                let isOnlyRemainingTask = remainingTaskIDs.count == 1 && remainingTaskIDs.first == taskID

                var updatedTaskTimes = block.taskTimes
                if let startTime = taskStartTime {
                    let secondsSpent = Int(Date().timeIntervalSince(startTime))
                    updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
                }

                if isOnlyRemainingTask {
                    var updatedCompletedIDs = block.completedTaskIDs
                    updatedCompletedIDs.append(taskID)

                    try eventKitRepo.updateFocusBlock(
                        eventID: block.id,
                        taskIDs: block.taskIDs,
                        completedTaskIDs: updatedCompletedIDs,
                        taskTimes: updatedTaskTimes
                    )
                } else {
                    var updatedTaskIDs = block.taskIDs
                    if let index = updatedTaskIDs.firstIndex(of: taskID) {
                        updatedTaskIDs.remove(at: index)
                        updatedTaskIDs.append(taskID)
                    }

                    try eventKitRepo.updateFocusBlock(
                        eventID: block.id,
                        taskIDs: updatedTaskIDs,
                        completedTaskIDs: block.completedTaskIDs,
                        taskTimes: updatedTaskTimes
                    )
                }

                taskStartTime = nil
                lastTaskID = nil
                await loadData()
            } catch {
                errorMessage = "Task konnte nicht übersprungen werden."
            }
        }
    }

    // MARK: - Progress Calculations

    private func calculateProgress(block: FocusBlock) -> Double {
        let totalDuration = block.endDate.timeIntervalSince(block.startDate)
        let elapsed = currentTime.timeIntervalSince(block.startDate)
        return elapsed / totalDuration
    }

    private func calculateRemainingMinutes(block: FocusBlock) -> Int {
        let remaining = block.endDate.timeIntervalSince(currentTime)
        return max(0, Int(remaining / 60))
    }

    private func calculateTaskProgress(task: LocalTask) -> Double {
        guard let startTime = taskStartTime, let duration = task.estimatedDuration else { return 0 }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(duration * 60)
        return elapsed / estimated
    }

    private func calculateRemainingTaskMinutes(task: LocalTask) -> Int {
        guard let startTime = taskStartTime else { return task.estimatedDuration ?? 15 }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double((task.estimatedDuration ?? 15) * 60)
        let remaining = estimated - elapsed
        return max(0, Int(remaining / 60))
    }

    private func timeRangeText(block: FocusBlock) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private func checkBlockEnd() {
        guard let block = activeBlock else { return }
        if block.isPast && !showSprintReview {
            showSprintReview = true
        }
    }
}

// MARK: - Task Queue Row

struct TaskQueueRow: View {
    let task: LocalTask
    let status: TaskStatus

    enum TaskStatus {
        case current, upcoming, completed
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)
                .strikethrough(status == .completed)
                .foregroundStyle(status == .completed ? .secondary : .primary)

            Spacer()

            if let duration = task.estimatedDuration {
                Text("\(duration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(status == .current ? statusColor.opacity(0.1) : Color.clear)
        )
    }

    private var statusIcon: String {
        switch status {
        case .current: return "play.circle.fill"
        case .upcoming: return "circle"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .current: return .blue
        case .upcoming: return .secondary
        case .completed: return .green
        }
    }
}

// MARK: - Sprint Review Sheet (Placeholder)

struct MacSprintReviewSheet: View {
    let block: FocusBlock
    let tasks: [LocalTask]
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var completedCount: Int {
        tasks.filter { block.completedTaskIDs.contains($0.id) }.count
    }

    private var totalMinutes: Int {
        tasks.filter { block.completedTaskIDs.contains($0.id) }
            .compactMap(\.estimatedDuration)
            .reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Image(systemName: "flag.checkered")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Sprint Review")
                .font(.largeTitle.weight(.bold))

            Text(block.title)
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            // Stats
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(completedCount)/\(tasks.count)")
                        .font(.title.monospacedDigit().weight(.bold))
                    Text("Tasks erledigt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Text("\(totalMinutes)")
                        .font(.title.monospacedDigit().weight(.bold))
                    Text("Minuten gearbeitet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Task list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks, id: \.uuid) { task in
                    HStack {
                        Image(systemName: block.completedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(block.completedTaskIDs.contains(task.id) ? .green : .red)

                        Text(task.title)
                            .lineLimit(1)

                        Spacer()

                        if let duration = task.estimatedDuration {
                            Text("\(duration) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Close button
            Button("Schließen") {
                onDismiss()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 500, height: 600)
    }
}

#Preview {
    MacFocusView()
        .frame(width: 800, height: 600)
}
