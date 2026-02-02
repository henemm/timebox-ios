//
//  MenuBarView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData

/// Menu Bar popover content showing current focus state and quick actions
struct MenuBarView: View {
    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && $0.isNextUp },
           sort: \LocalTask.nextUpSortOrder)
    private var nextUpTasks: [LocalTask]

    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp },
           sort: \LocalTask.createdAt, order: .reverse)
    private var backlogTasks: [LocalTask]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @State private var newTaskTitle = ""
    @State private var isAddingTask = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            header

            Divider()

            // Quick Add
            quickAddSection

            Divider()

            // Next Up Tasks
            nextUpSection

            if !backlogTasks.isEmpty {
                Divider()
                backlogPreview
            }

            Divider()

            // Footer Actions
            footerActions
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "cube.fill")
                .foregroundStyle(.blue)
            Text("FocusBlox")
                .font(.headline)
            Spacer()
            Text("\(nextUpTasks.count + backlogTasks.count) Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Add

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isAddingTask {
                HStack {
                    TextField("New Task", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTask()
                        }
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(newTaskTitle.isEmpty)

                    Button(action: { isAddingTask = false }) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button(action: { isAddingTask = true }) {
                    Label("Quick Add Task", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Next Up Section

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Up")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if nextUpTasks.isEmpty {
                Text("No tasks staged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                ForEach(nextUpTasks.prefix(3), id: \.uuid) { task in
                    MenuBarTaskRow(task: task) {
                        toggleComplete(task)
                    }
                }

                if nextUpTasks.count > 3 {
                    Text("+\(nextUpTasks.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Backlog Preview

    private var backlogPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(backlogTasks.prefix(2), id: \.uuid) { task in
                MenuBarTaskRow(task: task) {
                    toggleComplete(task)
                }
            }

            if backlogTasks.count > 2 {
                Text("+\(backlogTasks.count - 2) more in backlog")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer Actions

    private var footerActions: some View {
        HStack {
            Button("Open FocusBlox") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "FocusBlox" || $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let task = LocalTask(title: newTaskTitle)
        modelContext.insert(task)
        newTaskTitle = ""
        isAddingTask = false
    }

    private func toggleComplete(_ task: LocalTask) {
        task.isCompleted.toggle()
    }
}

// MARK: - Menu Bar Task Row

struct MenuBarTaskRow: View {
    let task: LocalTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.borderless)

            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.isCompleted)

            Spacer()

            if let duration = task.estimatedDuration {
                Text("\(duration)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if task.isTbd {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .font(.callout)
    }
}

#Preview {
    MenuBarView()
}
