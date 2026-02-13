import SwiftUI

struct SprintReviewSheet: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let initialCompletedTaskIDs: [String]
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var eventKitRepo = EventKitRepository()

    // Local state for editing
    @State private var localCompletedIDs: Set<String> = []
    @State private var hasChanges = false

    init(block: FocusBlock, tasks: [PlanItem], completedTaskIDs: [String], onDismiss: @escaping () -> Void) {
        self.block = block
        self.tasks = tasks
        self.initialCompletedTaskIDs = completedTaskIDs
        self.onDismiss = onDismiss
        self._localCompletedIDs = State(initialValue: Set(completedTaskIDs))
    }

    private var completedTasks: [PlanItem] {
        tasks.filter { localCompletedIDs.contains($0.id) }
    }

    private var incompleteTasks: [PlanItem] {
        tasks.filter { !localCompletedIDs.contains($0.id) }
    }

    private var completionPercentage: Int {
        guard !tasks.isEmpty else { return 100 }
        return Int((Double(completedTasks.count) / Double(tasks.count)) * 100)
    }

    /// Get actual time spent on a task (in seconds), or nil if not tracked
    private func actualTime(for taskID: String) -> Int? {
        block.taskTimes[taskID]
    }

    /// Format seconds as "X min" or "X:SS" for display
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with stats
                    statsHeader

                    // Completed tasks section
                    if !completedTasks.isEmpty {
                        completedTasksSection
                    }

                    // Incomplete tasks section
                    if !incompleteTasks.isEmpty {
                        incompleteTasksSection
                    }

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Sprint Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: 16) {
            // Completion ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
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
            .frame(width: 120, height: 120)

            // Block info
            VStack(spacing: 4) {
                Text(block.title)
                    .font(.headline)

                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 24) {
                StatItem(
                    value: "\(completedTasks.count)",
                    label: "Erledigt",
                    color: .green
                )

                StatItem(
                    value: "\(incompleteTasks.count)",
                    label: "Offen",
                    color: incompleteTasks.isEmpty ? .secondary : .orange
                )

                StatItem(
                    value: "\(totalDuration)m",
                    label: "geplant",
                    color: .blue
                )

                StatItem(
                    value: "\(totalActualMinutes)m",
                    label: "gebraucht",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    /// Total actual time spent (in minutes)
    private var totalActualMinutes: Int {
        let totalSeconds = block.taskTimes.values.reduce(0, +)
        return totalSeconds / 60
    }

    // MARK: - Completed Tasks Section

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Erledigt", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                ForEach(completedTasks) { task in
                    InteractiveReviewTaskRow(
                        task: task,
                        isCompleted: true,
                        plannedMinutes: task.effectiveDuration,
                        actualSeconds: actualTime(for: task.id),
                        onToggle: { toggleTaskCompletion(task.id) }
                    )
                }
            }
        }
    }

    // MARK: - Incomplete Tasks Section

    private var incompleteTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nicht geschafft", systemImage: "circle")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("Tippe auf ○ um Status zu ändern")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(incompleteTasks) { task in
                    InteractiveReviewTaskRow(
                        task: task,
                        isCompleted: false,
                        plannedMinutes: task.effectiveDuration,
                        actualSeconds: actualTime(for: task.id),
                        onToggle: { toggleTaskCompletion(task.id) }
                    )
                }
            }
        }
    }

    // MARK: - Toggle Task Completion

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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save changes button (only if changes were made)
            if hasChanges {
                Button {
                    saveChanges()
                } label: {
                    Label("Änderungen speichern", systemImage: "checkmark.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if !incompleteTasks.isEmpty {
                Button {
                    moveIncompleteTasks()
                } label: {
                    Label("Offene Tasks ins Backlog", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Button {
                if hasChanges {
                    saveChanges()
                }
                dismiss()
                onDismiss()
            } label: {
                Text("Sprint Review beenden")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.top)
    }

    // MARK: - Save Changes

    private func saveChanges() {
        Task {
            do {
                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: block.taskIDs,
                    completedTaskIDs: Array(localCompletedIDs),
                    taskTimes: block.taskTimes
                )
                hasChanges = false
            } catch {
                // Silently fail - user can retry
            }
        }
    }

    // MARK: - Helper Functions

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private var totalDuration: Int {
        tasks.reduce(0) { $0 + $1.effectiveDuration }
    }

    private func moveIncompleteTasks() {
        // Remove incomplete tasks from block (they go back to backlog automatically)
        Task {
            do {
                let remainingTaskIDs = block.taskIDs.filter { taskID in
                    localCompletedIDs.contains(taskID)
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: remainingTaskIDs,
                    completedTaskIDs: Array(localCompletedIDs),
                    taskTimes: block.taskTimes
                )

                dismiss()
                onDismiss()
            } catch {
                // Silently fail - user can retry
            }
        }
    }
}

// MARK: - Review Task Row (Legacy)

struct ReviewTaskRow: View {
    let task: PlanItem
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? .green : .secondary)

            Text(task.title)
                .font(.subheadline)
                .strikethrough(isCompleted, color: .secondary)
                .foregroundStyle(isCompleted ? .secondary : .primary)

            Spacer()

            Text("\(task.effectiveDuration) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Interactive Review Task Row

struct InteractiveReviewTaskRow: View {
    let task: PlanItem
    let isCompleted: Bool
    let plannedMinutes: Int
    let actualSeconds: Int?
    let onToggle: () -> Void

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
            // Toggle button
            Button {
                onToggle()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("taskStatusToggle")
            .accessibilityLabel(isCompleted ? "Als unerledigt markieren" : "Als erledigt markieren")

            // Task title
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                // Time info
                HStack(spacing: 8) {
                    // Planned time
                    Text("\(plannedMinutes) min geplant")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    if let actual = actualMinutes {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // Actual time
                        Text("\(actual) min gebraucht")
                            .font(.caption2)
                            .foregroundStyle(.purple)

                        // Difference indicator
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
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isCompleted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("reviewTaskRow_\(task.id)")
    }
}
