import SwiftUI

/// Sheet showing tasks within a FocusBlock
/// Allows viewing, reordering, and removing tasks from the block
struct FocusBlockTasksSheet: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let nextUpTasks: [PlanItem]
    let onReorder: ([String]) -> Void
    let onRemoveTask: (String) -> Void
    let onAssignTask: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var taskOrder: [PlanItem] = []

    var body: some View {
        NavigationStack {
            taskListView
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

    private var taskListView: some View {
        List {
            // MARK: - Assigned Tasks Section
            if taskOrder.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Keine Tasks im Block")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                Section {
                    ForEach(taskOrder) { task in
                        BlockTaskRow(task: task)
                            .accessibilityIdentifier("blockTask_\(task.id)")
                    }
                    .onMove(perform: moveTask)
                    .onDelete(perform: deleteTask)
                }
            }

            // MARK: - Next Up Section
            if !nextUpTasks.isEmpty {
                Section {
                    ForEach(nextUpTasks) { task in
                        SheetNextUpRow(task: task) {
                            onAssignTask(task.id)
                        }
                        .accessibilityIdentifier("nextUpTask_\(task.id)")
                    }
                } header: {
                    Text("Next Up (\(nextUpTasks.count))")
                        .accessibilityIdentifier("nextUpSectionHeader")
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.plain)
        #endif
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

// MARK: - Next Up Task Row

/// Row for a Next Up task in the FocusBlockTasksSheet
/// Tap the arrow-up button to assign the task to the current block
struct SheetNextUpRow: View {
    let task: PlanItem
    let onAssign: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(2)

                Label("\(task.effectiveDuration) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Assign button
            Button {
                onAssign()
            } label: {
                Image(systemName: "arrow.up.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("assignNextUpTask_\(task.id)")
            .accessibilityLabel("Task zum Block hinzufügen")
        }
        .padding(.vertical, 4)
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
        nextUpTasks: [],
        onReorder: { _ in },
        onRemoveTask: { _ in },
        onAssignTask: { _ in }
    )
}
