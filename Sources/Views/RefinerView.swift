import SwiftUI
import SwiftData

struct RefinerView: View {
    @Query(
        filter: #Predicate<LocalTask> { $0.lifecycleStatus == "raw" && !$0.isCompleted },
        sort: \LocalTask.createdAt,
        order: .reverse
    ) private var rawTasks: [LocalTask]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if rawTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("Refiner")
            .toolbar {
                if !rawTasks.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Alle bestätigen") {
                            confirmAll()
                        }
                        .accessibilityIdentifier("refiner_confirmAllButton")
                    }
                }
            }
        }
    }

    private var taskList: some View {
        List {
            ForEach(rawTasks) { task in
                RefinerTaskCard(task: task)
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("refiner_taskList")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Alles veredelt")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("refiner_emptyState")
            Text("Neue Tasks aus dem Quick Dump erscheinen hier zur Prüfung.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func confirmAll() {
        for task in rawTasks {
            task.confirmSuggestions()
        }
        try? modelContext.save()
    }
}
