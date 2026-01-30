import SwiftUI
import SwiftData

struct FocusLiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo: any EventKitRepositoryProtocol = FocusLiveView.createRepository()
    @State private var activeBlock: FocusBlock?

    /// Creates the appropriate repository based on launch mode
    /// Use -MockData launch argument to test Live Activity with mock data
    private static func createRepository() -> any EventKitRepositoryProtocol {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let isMockData = ProcessInfo.processInfo.arguments.contains("-MockData")
        let useMock = isUITesting || isMockData

        print("🔧 [FocusLiveView] createRepository: isUITesting=\(isUITesting), isMockData=\(isMockData)")

        if useMock {
            return createMockRepository()
        }
        print("🔧 [FocusLiveView] Using real EventKitRepository")
        return EventKitRepository()
    }

    /// Creates a mock repository with an active Focus Block for testing Live Activity
    private static func createMockRepository() -> MockEventKitRepository {
        let mock = MockEventKitRepository()
        mock.mockCalendarAuthStatus = .fullAccess
        mock.mockReminderAuthStatus = .fullAccess

        // Create an always-active Focus Block for testing Live Activity
        let calendar = Calendar.current
        let now = Date()
        let activeBlockStart = calendar.date(byAdding: .minute, value: -5, to: now)!
        let activeBlockEnd = calendar.date(byAdding: .minute, value: 25, to: now)!
        let activeBlock = FocusBlock(
            id: "mock-block-live-activity-test",
            title: "🎯 Focus Block Test",
            startDate: activeBlockStart,
            endDate: activeBlockEnd,
            taskIDs: [
                "AAAAAAAA-0000-0000-0000-000000000001",
                "AAAAAAAA-0000-0000-0000-000000000002",
                "AAAAAAAA-0000-0000-0000-000000000003"
            ],
            completedTaskIDs: []
        )
        mock.mockFocusBlocks = [activeBlock]
        print("🔧 [FocusLiveView] Using MOCK repository with active block: \(activeBlock.title)")
        print("🔧 [FocusLiveView] Block: \(activeBlockStart.formatted(date: .omitted, time: .shortened)) - \(activeBlockEnd.formatted(date: .omitted, time: .shortened))")
        return mock
    }
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSprintReview = false
    @State private var completionFeedback = false

    // Timer for progress updates
    @State private var currentTime = Date()
    @State private var taskStartTime: Date?
    @State private var lastTaskID: String?
    @State private var warningPlayed = false
    @State private var lastOverdueReminderTime: Date?
    @State private var skipFeedback = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let overdueReminderInterval: TimeInterval = 120 // 2 Minuten

    // Live Activity Manager
    @State private var liveActivityManager = LiveActivityManager()
    @State private var liveActivityStarted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Lade...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ContentUnavailableView(
                        "Fehler",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Spacer()
                } else if let block = activeBlock {
                    activeFocusContent(block: block)
                } else {
                    noActiveBlockContent
                }
            }
            .navigationTitle("Focus")
            .withSettingsToolbar()
            .sensoryFeedback(.success, trigger: completionFeedback)
            .sheet(isPresented: $showSprintReview) {
                if let block = activeBlock {
                    SprintReviewSheet(
                        block: block,
                        tasks: tasksForBlock(block),
                        completedTaskIDs: block.completedTaskIDs,
                        onDismiss: {
                            Task {
                                await loadData()
                            }
                        }
                    )
                }
            }
        }
        .task {
            await loadData()
        }
        .onReceive(timer) { time in
            currentTime = time
            checkBlockEnd()
            checkTaskOverdue()
        }
        .onChange(of: activeBlock?.id) { oldValue, newValue in
            // Start or end Live Activity when block changes
            print("🔔 [FocusLiveView] onChange activeBlock: old=\(oldValue ?? "nil") new=\(newValue ?? "nil")")
            if let block = activeBlock, block.isActive {
                print("🔔 [FocusLiveView] Starting Live Activity for block: \(block.title)")
                startLiveActivity(for: block)
            } else {
                print("🔔 [FocusLiveView] Ending Live Activity (no active block)")
                liveActivityManager.endActivity()
                liveActivityStarted = false
            }
        }
    }

    // MARK: - Live Activity Management

    private func startLiveActivity(for block: FocusBlock) {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first

        // Calculate task end date for task-specific countdown
        let taskEndDate = calculateTaskEndDate(for: currentTask)

        Task {
            do {
                try await liveActivityManager.startActivity(
                    for: block,
                    currentTask: currentTask?.title,
                    taskEndDate: taskEndDate
                )
                liveActivityStarted = true
            } catch {
                // Live Activity couldn't be started - not critical
                liveActivityStarted = false
            }
        }
    }

    private func updateLiveActivity(for block: FocusBlock) {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first

        // Calculate task end date for task-specific countdown
        let taskEndDate = calculateTaskEndDate(for: currentTask)

        liveActivityManager.updateActivity(
            currentTask: currentTask?.title,
            completedCount: block.completedTaskIDs.count,
            taskEndDate: taskEndDate
        )
    }

    /// Calculate when the current task should end based on task start time and duration
    private func calculateTaskEndDate(for task: PlanItem?) -> Date? {
        guard let task = task else { return nil }

        // Use taskStartTime if available, otherwise use current time
        let startTime = taskStartTime ?? Date()
        return startTime.addingTimeInterval(Double(task.effectiveDuration * 60))
    }

    // MARK: - Active Focus Content

    private func activeFocusContent(block: FocusBlock) -> some View {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first
        let upcomingTasks = Array(remainingTasks.dropFirst())

        return VStack(spacing: 0) {
            // Progress header
            progressHeader(block: block)

            Spacer()

            // Current task (prominent)
            if let task = currentTask {
                currentTaskView(task: task, block: block)
            } else {
                allTasksCompletedView(block: block)
            }

            Spacer()

            // Upcoming tasks queue OR "No more tasks" hint
            if !upcomingTasks.isEmpty {
                upcomingTasksView(tasks: upcomingTasks)
            } else if currentTask != nil {
                // Bug 16 Fix: Show hint when no upcoming tasks
                noMoreTasksHint
            }
        }
    }

    // MARK: - No More Tasks Hint (Bug 16)

    private var noMoreTasksHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
            Text("Keine weiteren Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("noMoreTasksHint")
    }

    // MARK: - Progress Header

    private func progressHeader(block: FocusBlock) -> some View {
        let progress = calculateProgress(block: block)
        let remainingMinutes = calculateRemainingMinutes(block: block)

        return VStack(spacing: 8) {
            // Time info
            HStack {
                Text(block.title)
                    .font(.headline)

                // Live Activity status indicator (show when block is active)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(liveActivityStarted ? .blue : .secondary)
                    .accessibilityIdentifier("liveActivityBadge")

                Spacer()

                // Live Activity status text
                Text(liveActivityStarted ? "Live" : "Aktiv")
                    .font(.caption2)
                    .foregroundStyle(liveActivityStarted ? .blue : .secondary)
                    .accessibilityIdentifier("liveActivityStatus")

                Text(timeRangeText(block: block))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

            // Remaining time
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
        .background(.ultraThinMaterial)
    }

    // MARK: - Current Task View

    private func currentTaskView(task: PlanItem, block: FocusBlock) -> some View {
        let taskProgress = calculateTaskProgress(task: task)
        let remainingTaskMinutes = calculateRemainingTaskMinutes(task: task)
        let isOverdue = remainingTaskMinutes <= 0

        return VStack(spacing: 24) {
            Text(isOverdue ? "⏰ Zeit abgelaufen" : "Aktueller Task")
                .font(.subheadline)
                .foregroundStyle(isOverdue ? .red : .secondary)
                .accessibilityIdentifier("currentTaskLabel")

            // Task progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Progress circle - red when overdue
                Circle()
                    .trim(from: 0, to: min(taskProgress, 1))
                    .stroke(
                        isOverdue ? .red : (taskProgress >= 1 ? .orange : .blue),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: taskProgress)

                // Time display in center
                VStack(spacing: 2) {
                    if remainingTaskMinutes > 0 {
                        Text("\(remainingTaskMinutes)")
                            .font(.title.monospacedDigit().weight(.bold))
                        Text("min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("🔥")
                            .font(.title)
                        Text("Overdue")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Text(task.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("\(task.effectiveDuration) min geschätzt")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Action buttons
            HStack(spacing: 16) {
                // Skip button (Nicht erledigt)
                Button {
                    skipTask(taskID: task.id, block: block)
                } label: {
                    Label("Überspringen", systemImage: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.orange, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskSkipButton")

                // Complete button (Erledigt)
                Button {
                    markTaskComplete(taskID: task.id, block: block)
                } label: {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.green, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskCompleteButton")
            }
        }
        .padding()
        .accessibilityIdentifier("currentTaskView")
        .sensoryFeedback(.warning, trigger: skipFeedback)
        .onAppear {
            trackTaskStart(taskID: task.id)
        }
        .onChange(of: task.id) { _, newID in
            trackTaskStart(taskID: newID)
        }
    }

    // MARK: - All Tasks Completed View

    private func allTasksCompletedView(block: FocusBlock) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Alle Tasks erledigt!")
                .font(.title2.weight(.semibold))

            Text("Warte auf Block-Ende oder starte Sprint Review")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showSprintReview = true
            } label: {
                Text("Sprint Review starten")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Upcoming Tasks View

    private func upcomingTasksView(tasks: [PlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Als Nächstes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 6) {
                ForEach(tasks) { task in
                    UpcomingTaskChip(task: task)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - No Active Block Content

    private var noActiveBlockContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Kein aktiver Focus Block")
                .font(.title2.weight(.semibold))

            Text("Focus Blocks werden automatisch aktiv, wenn ihre Startzeit erreicht ist")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await loadData()
                }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    // MARK: - Helper Functions

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        print("📥 [FocusLiveView] loadData: starting...")

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            print("📥 [FocusLiveView] loadData: hasAccess=\(hasAccess)")
            guard hasAccess else {
                errorMessage = "Zugriff verweigert."
                isLoading = false
                return
            }

            let blocks = try eventKitRepo.fetchFocusBlocks(for: Date())
            print("📥 [FocusLiveView] loadData: found \(blocks.count) blocks")
            for block in blocks {
                print("📥 [FocusLiveView] block: \(block.title), isActive=\(block.isActive)")
            }
            activeBlock = blocks.first { $0.isActive }
            print("📥 [FocusLiveView] activeBlock=\(activeBlock?.title ?? "nil")")

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            allTasks = try await syncEngine.sync()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func tasksForBlock(_ block: FocusBlock) -> [PlanItem] {
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
        }
    }

    private func markTaskComplete(taskID: String, block: FocusBlock) {
        // Cancel notification for completed task
        NotificationService.cancelTaskNotification(taskID: taskID)

        Task {
            do {
                var updatedCompletedIDs = block.completedTaskIDs
                if !updatedCompletedIDs.contains(taskID) {
                    updatedCompletedIDs.append(taskID)
                }

                // Calculate time spent on this task
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

                taskStartTime = nil  // Reset for next task
                completionFeedback.toggle()
                lastOverdueReminderTime = nil  // Reset overdue reminder
                await loadData()

                // Update Live Activity with new task
                if let updatedBlock = activeBlock {
                    updateLiveActivity(for: updatedBlock)
                }
            } catch {
                errorMessage = "Task konnte nicht als erledigt markiert werden."
            }
        }
    }

    /// Skip task without marking as complete - moves to next task in queue
    /// Bug 15 Fix: If all tasks have been skipped once, end the block instead of looping
    private func skipTask(taskID: String, block: FocusBlock) {
        // Cancel notification for skipped task
        NotificationService.cancelTaskNotification(taskID: taskID)

        Task {
            do {
                // Get remaining (non-completed) task IDs
                let remainingTaskIDs = block.taskIDs.filter { !block.completedTaskIDs.contains($0) }

                // Bug 15 Fix: If this is the only remaining task, mark as completed to end block
                // Skipping the only task would cause it to reappear (infinite loop)
                let isOnlyRemainingTask = remainingTaskIDs.count == 1 && remainingTaskIDs.first == taskID

                // Preserve partial time spent on skipped task
                var updatedTaskTimes = block.taskTimes
                if let startTime = taskStartTime {
                    let secondsSpent = Int(Date().timeIntervalSince(startTime))
                    updatedTaskTimes[taskID] = (updatedTaskTimes[taskID] ?? 0) + secondsSpent
                }

                if isOnlyRemainingTask {
                    // Bug 15 Fix: Only 1 task remaining → mark as completed to end block
                    // This triggers allTasksCompletedView instead of looping
                    var updatedCompletedIDs = block.completedTaskIDs
                    updatedCompletedIDs.append(taskID)

                    try eventKitRepo.updateFocusBlock(
                        eventID: block.id,
                        taskIDs: block.taskIDs,
                        completedTaskIDs: updatedCompletedIDs,
                        taskTimes: updatedTaskTimes
                    )
                } else {
                    // Original logic: Move task to end of queue
                    var updatedTaskIDs = block.taskIDs
                    if let index = updatedTaskIDs.firstIndex(of: taskID) {
                        updatedTaskIDs.remove(at: index)
                        updatedTaskIDs.append(taskID)  // Move to end
                    }

                    try eventKitRepo.updateFocusBlock(
                        eventID: block.id,
                        taskIDs: updatedTaskIDs,
                        completedTaskIDs: block.completedTaskIDs,
                        taskTimes: updatedTaskTimes
                    )
                }

                skipFeedback.toggle()
                lastOverdueReminderTime = nil  // Reset overdue reminder
                taskStartTime = nil  // Reset task timer for next task
                lastTaskID = nil
                await loadData()

                // Update Live Activity with new task
                if let updatedBlock = activeBlock {
                    updateLiveActivity(for: updatedBlock)
                }
            } catch {
                errorMessage = "Task konnte nicht übersprungen werden."
            }
        }
    }

    private func calculateProgress(block: FocusBlock) -> Double {
        let totalDuration = block.endDate.timeIntervalSince(block.startDate)
        let elapsed = currentTime.timeIntervalSince(block.startDate)
        return elapsed / totalDuration
    }

    private func calculateRemainingMinutes(block: FocusBlock) -> Int {
        let remaining = block.endDate.timeIntervalSince(currentTime)
        return max(0, Int(remaining / 60))
    }

    private func timeRangeText(block: FocusBlock) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private func checkBlockEnd() {
        guard let block = activeBlock else { return }

        let progress = calculateProgress(block: block)
        let warningThreshold = AppSettings.shared.warningTiming.percentComplete

        // Check for warning (only once per block, when threshold reached)
        if progress >= warningThreshold && !warningPlayed && !block.isPast {
            SoundService.playWarning()
            warningPlayed = true
        }

        // If block just ended, play sound and show sprint review
        if block.isPast && !showSprintReview {
            SoundService.playEndGong()
            showSprintReview = true
            warningPlayed = false  // Reset for next block

            // End Live Activity
            liveActivityManager.endActivity()
            liveActivityStarted = false
        }
    }

    /// Check if current task is overdue and play reminder every 2 minutes
    private func checkTaskOverdue() {
        guard let block = activeBlock else { return }
        guard !block.isPast else { return }  // Don't remind if block is over

        // Get current task
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        guard let currentTask = remainingTasks.first else { return }

        // Check if task is overdue
        let remainingMinutes = calculateRemainingTaskMinutes(task: currentTask)
        guard remainingMinutes <= 0 else {
            lastOverdueReminderTime = nil  // Reset if not overdue anymore
            return
        }

        // Play reminder every 2 minutes
        let now = Date()
        if let lastReminder = lastOverdueReminderTime {
            if now.timeIntervalSince(lastReminder) >= overdueReminderInterval {
                SoundService.playWarning()
                lastOverdueReminderTime = now
            }
        } else {
            // First overdue - play immediately
            SoundService.playWarning()
            lastOverdueReminderTime = now
        }
    }

    // MARK: - Task Progress Tracking

    private func trackTaskStart(taskID: String) {
        if lastTaskID != taskID {
            // Cancel previous task notification
            if let previousTaskID = lastTaskID {
                NotificationService.cancelTaskNotification(taskID: previousTaskID)
            }

            lastTaskID = taskID
            taskStartTime = Date()

            // Schedule notification for new task
            if let block = activeBlock {
                let tasks = tasksForBlock(block)
                if let task = tasks.first(where: { $0.id == taskID }) {
                    NotificationService.scheduleTaskOverdueNotification(
                        taskID: taskID,
                        taskTitle: task.title,
                        durationMinutes: task.effectiveDuration
                    )
                }
            }
        }
    }

    private func calculateTaskProgress(task: PlanItem) -> Double {
        guard let startTime = taskStartTime else { return 0 }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(task.effectiveDuration * 60)
        return elapsed / estimated
    }

    private func calculateRemainingTaskMinutes(task: PlanItem) -> Int {
        guard let startTime = taskStartTime else { return task.effectiveDuration }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(task.effectiveDuration * 60)
        let remaining = estimated - elapsed
        return max(0, Int(remaining / 60))
    }
}

// MARK: - Upcoming Task Chip

struct UpcomingTaskChip: View {
    let task: PlanItem

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.secondary)
                .frame(width: 6, height: 6)

            Text(task.title)
                .font(.caption)
                .lineLimit(1)

            Text("\(task.effectiveDuration)m")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
