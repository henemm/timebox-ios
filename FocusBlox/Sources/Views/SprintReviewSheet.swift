import SwiftUI

struct SprintReviewSheet: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let completedTaskIDs: [String]
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var eventKitRepo = EventKitRepository()

    private var completedTasks: [PlanItem] {
        tasks.filter { completedTaskIDs.contains($0.id) }
    }

    private var incompleteTasks: [PlanItem] {
        tasks.filter { !completedTaskIDs.contains($0.id) }
    }

    private var completionPercentage: Int {
        guard !tasks.isEmpty else { return 100 }
        return Int((Double(completedTasks.count) / Double(tasks.count)) * 100)
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
            HStack(spacing: 32) {
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
                    label: "Geplant",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Completed Tasks Section

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Erledigt", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                ForEach(completedTasks) { task in
                    ReviewTaskRow(task: task, isCompleted: true)
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

            Text("Diese Tasks werden zurück ins Backlog gelegt")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(incompleteTasks) { task in
                    ReviewTaskRow(task: task, isCompleted: false)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
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
                    completedTaskIDs.contains(taskID)
                }

                try eventKitRepo.updateFocusBlock(
                    eventID: block.id,
                    taskIDs: remainingTaskIDs,
                    completedTaskIDs: completedTaskIDs
                )

                dismiss()
                onDismiss()
            } catch {
                // Silently fail - user can retry
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
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

// MARK: - Review Task Row

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
