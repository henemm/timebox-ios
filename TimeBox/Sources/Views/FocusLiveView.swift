import SwiftUI
import SwiftData

struct FocusLiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var activeBlock: FocusBlock?
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSprintReview = false
    @State private var completionFeedback = false

    // Timer for progress updates
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
            .navigationTitle("Fokus")
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
        }
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

            // Upcoming tasks queue
            if !upcomingTasks.isEmpty {
                upcomingTasksView(tasks: upcomingTasks)
            }
        }
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
                Spacer()
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
        VStack(spacing: 24) {
            Text("Aktueller Task")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(task.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("\(task.effectiveDuration) min")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                markTaskComplete(taskID: task.id, block: block)
            } label: {
                Label("Erledigt", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tasks) { task in
                        UpcomingTaskChip(task: task)
                    }
                }
                .padding(.horizontal)
            }
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

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                errorMessage = "Zugriff verweigert."
                isLoading = false
                return
            }

            let blocks = try eventKitRepo.fetchFocusBlocks(for: Date())
            activeBlock = blocks.first { $0.isActive }

            let syncEngine = SyncEngine(eventKitRepo: eventKitRepo, modelContext: modelContext)
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
        Task {
            do {
                var updatedCompletedIDs = block.completedTaskIDs
                if !updatedCompletedIDs.contains(taskID) {
                    updatedCompletedIDs.append(taskID)
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: block.taskIDs,
                    completedTaskIDs: updatedCompletedIDs
                )

                completionFeedback.toggle()
                await loadData()
            } catch {
                errorMessage = "Task konnte nicht als erledigt markiert werden."
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

        // If block just ended, show sprint review
        if block.isPast && !showSprintReview {
            showSprintReview = true
        }
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
