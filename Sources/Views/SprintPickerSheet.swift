import SwiftUI
import SwiftData

/// Sprint-Picker Sheet für Quick Action "Sprint starten"
/// Zeigt Next-Up Tasks — Antippen startet Focus Sprint direkt.
struct SprintPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<LocalTask> {
        $0.isNextUp && !$0.isCompleted && !$0.isTemplate
    }, sort: \LocalTask.sortOrder)
    private var nextUpTasks: [LocalTask]

    @State private var conflictTitle: String?

    var body: some View {
        NavigationStack {
            Group {
                if nextUpTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("Sprint starten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .alert("Sprint läuft bereits", isPresented: .init(
                get: { conflictTitle != nil },
                set: { if !$0 { conflictTitle = nil } }
            )) {
                Button("OK") { conflictTitle = nil }
            } message: {
                Text(conflictTitle ?? "")
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("sprintPickerSheet")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine Next-Up Tasks", systemImage: "tray")
        } description: {
            Text("Markiere Tasks im Backlog als Next Up")
        }
        .accessibilityIdentifier("sprintPickerEmpty")
    }

    private var taskList: some View {
        List(nextUpTasks) { task in
            let planItem = PlanItem(localTask: task)
            Button {
                startSprint(for: planItem)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.body)
                            .lineLimit(2)
                        if let duration = task.estimatedDuration {
                            Text("\(duration) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                }
            }
            .accessibilityIdentifier("sprintPickerRow_\(task.uuid.uuidString)")
        }
    }

    private func startSprint(for item: PlanItem) {
        do {
            let result = try FocusBlockActionService.startImmediate(
                taskID: item.id,
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            switch result {
            case .started:
                dismiss()
                NotificationCenter.default.post(name: .focusSprintStarted, object: nil)
            case .blockedByActiveBlock(let title):
                conflictTitle = title
            }
        } catch {
            conflictTitle = "Fehler: \(error.localizedDescription)"
        }
    }

    // MARK: - Static Filter (for Unit Tests)

    /// Filtert Next-Up Tasks aus dem ModelContext
    static func filterNextUpTasks(from context: ModelContext) -> [LocalTask] {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> {
                $0.isNextUp && !$0.isCompleted && !$0.isTemplate
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
