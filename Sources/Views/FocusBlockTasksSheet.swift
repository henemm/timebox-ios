import SwiftUI

/// Sheet showing tasks within a FocusBlock
/// Allows viewing, reordering, and removing tasks from the block
struct FocusBlockTasksSheet: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let onReorder: ([String]) -> Void
    let onRemoveTask: (String) -> Void
    let onAddTask: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var taskOrder: [PlanItem] = []

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Tasks im Block")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("focusBlockTasksSheet")
        .onAppear {
            taskOrder = tasks
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if taskOrder.isEmpty {
            emptyStateView
        } else {
            taskListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Keine Tasks im Block")
                .font(.headline)

            Text("Füge Tasks hinzu, um diesen Focus Block zu füllen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAddTask()
            } label: {
                Label("Task hinzufügen", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("addTaskToBlockButton")
        }
        .padding()
    }

    private var taskListView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(taskOrder) { task in
                    BlockTaskRow(task: task)
                        .accessibilityIdentifier("blockTask_\(task.id)")
                }
                .onMove(perform: moveTask)
                .onDelete(perform: deleteTask)
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.plain)
            #endif

            // Footer with Add Task button
            HStack {
                Button {
                    onAddTask()
                } label: {
                    Label("Task hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("addTaskToBlockButton")

                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        taskOrder.move(fromOffsets: source, toOffset: destination)
        onReorder(taskOrder.map { $0.id })
    }

    private func deleteTask(at offsets: IndexSet) {
        for index in offsets {
            onRemoveTask(taskOrder[index].id)
        }
        taskOrder.remove(atOffsets: offsets)
    }
}

// MARK: - Block Task Row

/// Row displaying a task within the FocusBlockTasksSheet
/// Uses simple display since drag is handled by List's onMove
struct BlockTaskRow: View {
    let task: PlanItem

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Duration
                    Label("\(task.effectiveDuration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Priority indicator
                    if let importance = task.importance {
                        priorityIndicator(importance: importance)
                    }
                }
            }

            Spacer()

            // Completion indicator
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func priorityIndicator(importance: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<min(importance, 3), id: \.self) { _ in
                Circle()
                    .fill(priorityColor(importance))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func priorityColor(_ importance: Int) -> Color {
        switch importance {
        case 1: return .gray
        case 2: return .orange
        case 3: return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    FocusBlockTasksSheet(
        block: FocusBlock(
            id: "preview-block",
            title: "Morning Focus",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: ["task1", "task2"]
        ),
        tasks: [],
        onReorder: { _ in },
        onRemoveTask: { _ in },
        onAddTask: {}
    )
}
