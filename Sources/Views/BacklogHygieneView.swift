import SwiftUI
import SwiftData

struct BacklogHygieneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Snapshot of stale tasks at presentation time — immune to parent re-renders
    @State private var tasks: [PlanItem]

    init(staleTasks: [PlanItem]) {
        _tasks = State(initialValue: staleTasks)
    }

    enum HygieneAction {
        case parked, deleted, kept, split
    }

    @State private var currentIndex = 0
    @State private var actions: [HygieneAction] = []
    @State private var showSummary = false
    @State private var keepHintVisible = false
    @State private var showSplitSheet = false

    private var currentTask: PlanItem? {
        guard currentIndex < tasks.count else { return nil }
        return tasks[currentIndex]
    }

    private var parkedCount: Int { actions.filter { $0 == .parked }.count }
    private var deletedCount: Int { actions.filter { $0 == .deleted }.count }
    private var keptCount: Int { actions.filter { $0 == .kept }.count }
    private var splitCount: Int { actions.filter { $0 == .split }.count }

    var body: some View {
        NavigationStack {
            Group {
                if showSummary {
                    summaryView
                } else if let task = currentTask {
                    cardView(for: task)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Backlog aufräumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(for task: PlanItem) -> some View {
        VStack(spacing: 24) {
            Text("Task \(currentIndex + 1) von \(tasks.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("hygieneTitle")

            VStack(spacing: 12) {
                Text(task.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("hygieneTaskTitle")

                VStack(spacing: 4) {
                    Text(ageText(for: task))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("hygieneTaskAge")

                    if task.rescheduleCount > 0 {
                        Text("\(task.rescheduleCount)× verschoben")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("hygieneTaskRescheduleCount")
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        parkTask(task)
                    } label: {
                        Label("Parken", systemImage: "pause.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .accessibilityIdentifier("hygieneParkButton")

                    Button(role: .destructive) {
                        deleteTask(task)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("hygieneDeleteButton")
                }

                HStack(spacing: 12) {
                    Button {
                        keepTask()
                    } label: {
                        Label("Behalten", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .accessibilityIdentifier("hygieneKeepButton")

                    if TaskSplitService.isAvailable {
                        Button {
                            showSplitSheet = true
                        } label: {
                            Label("Aufteilen", systemImage: "scissors")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .accessibilityIdentifier("hygieneSplitButton")
                    }
                }
            }

            if keepHintVisible {
                Text("Wird in \(AppSettings.shared.backlogStaleAgeDays) Tagen wieder vorgeschlagen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .accessibilityIdentifier("hygieneKeepHint")
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSplitSheet, onDismiss: splitCompleted) {
            if let currentTask {
                TaskSplitView(planItem: currentTask)
            }
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Backlog aufgeräumt!")
                .font(.title2.weight(.semibold))

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("hygieneSummary")

            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Alles aufgeräumt!")
                .font(.title3)

            Text("Keine Tasks zum Aufräumen gefunden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func parkTask(_ task: PlanItem) {
        if let localTask = findLocalTask(id: task.id) {
            localTask.isParked = true
            localTask.modifiedAt = Date()
            try? modelContext.save()
        }
        actions.append(.parked)
        advanceOrFinish()
    }

    private func deleteTask(_ task: PlanItem) {
        if let localTask = findLocalTask(id: task.id) {
            modelContext.delete(localTask)
            try? modelContext.save()
        }
        actions.append(.deleted)
        advanceOrFinish()
    }

    private func keepTask() {
        actions.append(.kept)
        withAnimation(.smooth) {
            keepHintVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.smooth) {
                keepHintVisible = false
            }
            advanceOrFinish()
        }
    }

    private func splitCompleted() {
        actions.append(.split)
        advanceOrFinish()
    }

    private func advanceOrFinish() {
        if currentIndex + 1 < tasks.count {
            withAnimation(.smooth) {
                currentIndex += 1
            }
        } else {
            withAnimation(.smooth) {
                showSummary = true
            }
        }
    }

    private func findLocalTask(id: String) -> LocalTask? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Helpers

    private var summaryText: String {
        var parts: [String] = []
        if parkedCount > 0 { parts.append("\(parkedCount) geparkt") }
        if deletedCount > 0 { parts.append("\(deletedCount) gelöscht") }
        if keptCount > 0 { parts.append("\(keptCount) behalten") }
        if splitCount > 0 { parts.append("\(splitCount) aufgeteilt") }
        return parts.joined(separator: " · ")
    }

    private func ageText(for task: PlanItem) -> String {
        let days = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        if days == 0 {
            return "Heute erstellt"
        } else if days == 1 {
            return "Gestern erstellt"
        } else {
            return "Erstellt vor \(days) Tagen"
        }
    }
}
