import SwiftUI

/// Sheet showing tasks within a FocusBlock
/// Allows viewing, reordering, removing, and assigning tasks
/// iOS: Sections stacked vertically (full-screen sheet)
/// macOS: Assigned tasks left, Next Up + Alle Tasks right (side by side)
struct FocusBlockTasksSheet: View {
    let block: FocusBlock
    let tasks: [PlanItem]
    let nextUpTasks: [PlanItem]
    let allTasks: [PlanItem]
    let onReorder: ([String]) -> Void
    let onRemoveTask: (String) -> Void
    let onAssignTask: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var taskOrder: [PlanItem] = []
    @State private var isAllTasksExpanded = false

    var body: some View {
        NavigationStack {
            sheetContent
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
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
        .accessibilityIdentifier("focusBlockTasksSheet")
        .onAppear {
            taskOrder = tasks
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            taskOrder = tasks
        }
    }

    // MARK: - Platform-Specific Layout

    @ViewBuilder
    private var sheetContent: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Left: Assigned Tasks
            List {
                assignedSection
            }
            .listStyle(.plain)
            .frame(minWidth: 250)

            Divider()

            // Right: Next Up + Alle Tasks
            List {
                nextUpSection
                allTasksSection
            }
            .listStyle(.plain)
            .frame(minWidth: 250)
        }
        #else
        List {
            assignedSection
            nextUpSection
            allTasksSection
        }
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Assigned Tasks Section

    @ViewBuilder
    private var assignedSection: some View {
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
    }

    // MARK: - Next Up Section (Always Visible)

    private var nextUpSection: some View {
        Section {
            if nextUpTasks.isEmpty {
                Text("Keine Next Up Tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(nextUpTasks) { task in
                    SheetNextUpRow(task: task) {
                        onAssignTask(task.id)
                    }
                    .accessibilityIdentifier("nextUpTask_\(task.id)")
                }
            }
        } header: {
            Text("Next Up (\(nextUpTasks.count))")
                .accessibilityIdentifier("nextUpSectionHeader")
        }
    }

    // MARK: - Alle Tasks Section (Expandable, sorted by priority)

    private var allTasksSortedByPriority: [PlanItem] {
        allTasks.sorted { $0.priorityScore > $1.priorityScore }
    }

    private var allTasksSection: some View {
        Section {
            // Expandable header (tappable)
            HStack {
                Image(systemName: isAllTasksExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text("Alle Tasks")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(allTasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.gray.opacity(0.15)))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isAllTasksExpanded.toggle()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("allTasksDisclosure")

            // Expanded content (sorted by priority score, highest first)
            if isAllTasksExpanded {
                ForEach(allTasksSortedByPriority) { task in
                    SheetNextUpRow(task: task, identifierPrefix: "assignAllTask") {
                        onAssignTask(task.id)
                    }
                    .accessibilityIdentifier("allTask_\(task.id)")
                }
            }
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

// MARK: - Assignable Task Row

/// Row for a task that can be assigned to the current block
/// Used in both Next Up and Alle Tasks sections
struct SheetNextUpRow: View {
    let task: PlanItem
    var identifierPrefix: String = "assignNextUpTask"
    let onAssign: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(2)

                // Priority badges (read-only, reusing shared components)
                HStack(spacing: 6) {
                    ImportanceBadge(importance: task.importance, taskId: task.id)
                    UrgencyBadge(urgency: task.urgency, taskId: task.id)
                    PriorityScoreBadge(score: task.priorityScore, tier: task.priorityTier, taskId: task.id)

                    Label("\(task.effectiveDuration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            .accessibilityIdentifier("\(identifierPrefix)_\(task.id)")
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
        allTasks: [],
        onReorder: { _ in },
        onRemoveTask: { _ in },
        onAssignTask: { _ in }
    )
}
