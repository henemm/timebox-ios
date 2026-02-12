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
    @Query
    private var allTasks: [LocalTask]

    @State private var activeBlock: FocusBlock?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSprintReview = false
    @State private var reviewDismissed = false

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
                        reviewDismissed = true
                        Task {
                            if block.isPast {
                                returnIncompleteTasksToNextUp(block: block)
                            }
                            await loadData()
                        }
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
            // Aktiven Block bevorzugen, sonst letzten abgelaufenen fuer Review
            activeBlock = blocks.first { $0.isActive }
                ?? blocks.filter { $0.isPast }.last
            if activeBlock?.isPast == true && !reviewDismissed {
                showSprintReview = true
            }
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

                // Auch LocalTask.isCompleted in SwiftData setzen (fuer Review Tab)
                let fetchDescriptor = FetchDescriptor<LocalTask>()
                if let localTasks = try? modelContext.fetch(fetchDescriptor),
                   let localTask = localTasks.first(where: { $0.id == taskID }) {
                    localTask.isCompleted = true
                    try? modelContext.save()
                }
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
        if block.isPast && !showSprintReview && !reviewDismissed {
            showSprintReview = true
        }
    }

    /// Unerledigte Tasks nach Sprint Review zurueck in Next Up
    private func returnIncompleteTasksToNextUp(block: FocusBlock) {
        let incompleteTasks = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }
        guard !incompleteTasks.isEmpty else { return }

        let fetchDescriptor = FetchDescriptor<LocalTask>()
        guard let localTasks = try? modelContext.fetch(fetchDescriptor) else { return }

        for taskID in incompleteTasks {
            if let task = localTasks.first(where: { $0.id == taskID }) {
                task.isNextUp = true
            }
        }
        try? modelContext.save()
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

// MARK: - Sprint Review Sheet (Full Interactive - iOS Parity)

struct MacSprintReviewSheet: View {
    let block: FocusBlock
    let tasks: [LocalTask]
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let eventKitRepo = EventKitRepository()

    // Local state for interactive editing
    @State private var localCompletedIDs: Set<String> = []
    @State private var hasChanges = false

    init(block: FocusBlock, tasks: [LocalTask], onDismiss: @escaping () -> Void) {
        self.block = block
        self.tasks = tasks
        self.onDismiss = onDismiss
        self._localCompletedIDs = State(initialValue: Set(block.completedTaskIDs))
    }

    private var completedTasks: [LocalTask] {
        tasks.filter { localCompletedIDs.contains($0.id) }
    }

    private var incompleteTasks: [LocalTask] {
        tasks.filter { !localCompletedIDs.contains($0.id) }
    }

    private var completionPercentage: Int {
        guard !tasks.isEmpty else { return 100 }
        return Int((Double(completedTasks.count) / Double(tasks.count)) * 100)
    }

    private var totalPlannedMinutes: Int {
        tasks.compactMap(\.estimatedDuration).reduce(0, +)
    }

    private var totalActualMinutes: Int {
        block.taskTimes.values.reduce(0, +) / 60
    }

    private func actualTime(for taskID: String) -> Int? {
        block.taskTimes[taskID]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with completion ring
            statsHeader

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Completed tasks
                    if !completedTasks.isEmpty {
                        completedTasksSection
                    }

                    // Incomplete tasks
                    if !incompleteTasks.isEmpty {
                        incompleteTasksSection
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            // Action buttons
            actionButtons
        }
        .padding(24)
        .frame(width: 520, height: 650)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: 16) {
            // Completion ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(completionPercentage)%")
                        .font(.title.weight(.bold))
                    Text("geschafft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            Text("Sprint Review")
                .font(.title.weight(.bold))

            Text(block.title)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(timeRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Stats row
            HStack(spacing: 32) {
                MacStatItem(value: "\(completedTasks.count)", label: "Erledigt", color: .green)
                MacStatItem(value: "\(incompleteTasks.count)", label: "Offen", color: incompleteTasks.isEmpty ? .secondary : .orange)
                MacStatItem(value: "\(totalPlannedMinutes)m", label: "geplant", color: .blue)
                MacStatItem(value: "\(totalActualMinutes)m", label: "gebraucht", color: .purple)
            }
        }
    }

    // MARK: - Completed Tasks Section

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Erledigt", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            ForEach(completedTasks, id: \.uuid) { task in
                MacReviewTaskRow(
                    task: task,
                    isCompleted: true,
                    actualSeconds: actualTime(for: task.id),
                    onToggle: { toggleTaskCompletion(task.id) }
                )
            }
        }
    }

    // MARK: - Incomplete Tasks Section

    private var incompleteTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nicht geschafft", systemImage: "circle")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("Klicke auf ○ um Status zu ändern")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(incompleteTasks, id: \.uuid) { task in
                MacReviewTaskRow(
                    task: task,
                    isCompleted: false,
                    actualSeconds: actualTime(for: task.id),
                    onToggle: { toggleTaskCompletion(task.id) }
                )
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if hasChanges {
                Button {
                    saveChanges()
                } label: {
                    Label("Änderungen speichern", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            }

            if !incompleteTasks.isEmpty {
                Button {
                    moveIncompleteTasks()
                } label: {
                    Label("Offene Tasks ins Backlog", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }

            Button {
                if hasChanges { saveChanges() }
                onDismiss()
                dismiss()
            } label: {
                Text("Sprint Review beenden")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("sprintReviewDismiss")
        }
    }

    // MARK: - Actions

    private func toggleTaskCompletion(_ taskID: String) {
        withAnimation(.spring(duration: 0.3)) {
            if localCompletedIDs.contains(taskID) {
                localCompletedIDs.remove(taskID)
            } else {
                localCompletedIDs.insert(taskID)
            }
            hasChanges = true
        }
    }

    private func saveChanges() {
        Task {
            try? eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: block.taskIDs,
                completedTaskIDs: Array(localCompletedIDs),
                taskTimes: block.taskTimes
            )
            hasChanges = false
        }
    }

    private func moveIncompleteTasks() {
        Task {
            let remainingTaskIDs = block.taskIDs.filter { localCompletedIDs.contains($0) }
            try? eventKitRepo.updateFocusBlock(
                eventID: block.id,
                taskIDs: remainingTaskIDs,
                completedTaskIDs: Array(localCompletedIDs),
                taskTimes: block.taskTimes
            )
            onDismiss()
            dismiss()
        }
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }
}

// MARK: - Mac Stat Item

struct MacStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Mac Review Task Row (Interactive)

private struct MacReviewTaskRow: View {
    let task: LocalTask
    let isCompleted: Bool
    let actualSeconds: Int?
    let onToggle: () -> Void

    private var plannedMinutes: Int {
        task.estimatedDuration ?? 15
    }

    private var actualMinutes: Int? {
        guard let seconds = actualSeconds else { return nil }
        return seconds / 60
    }

    private var timeDifference: Int? {
        guard let actual = actualMinutes else { return nil }
        return actual - plannedMinutes
    }

    private var timeDifferenceColor: Color {
        guard let diff = timeDifference else { return .secondary }
        if diff <= 0 { return .green }
        if diff <= 5 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("taskStatusToggle")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(plannedMinutes) min geplant")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    if let actual = actualMinutes {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(actual) min gebraucht")
                            .font(.caption2)
                            .foregroundStyle(.purple)

                        if let diff = timeDifference, diff != 0 {
                            Text(diff > 0 ? "+\(diff)" : "\(diff)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(timeDifferenceColor)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isCompleted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    MacFocusView()
        .frame(width: 800, height: 600)
}
