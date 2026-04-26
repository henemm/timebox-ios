//
//  MenuBarView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import Combine

/// Timer formatting for Menu Bar label and popover
enum MenuBarTimerFormatter {
    /// Format seconds as mm:ss (e.g. 863 -> "14:23")
    static func format(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

// MARK: - MenuBar Backlog Grouping (Bug #290)

/// Pure-function grouping of `LocalTask` for the MenuBar popover.
/// Splits a flat task list into Heute / Überfällig / Dringend buckets and
/// applies a global limit. The result drives the popover's section rendering.
///
/// Section semantics (mirrors BacklogView tiers, condensed for popover):
/// - **heute**: every active `isNextUp` task, sorted by priorityScore desc
/// - **ueberfaellig**: due before today AND not nextUp (incl. overdue
///   .doNow tasks — they belong here, not in dringend, to avoid duplicates)
/// - **dringend**: priorityTier == .doNow, NOT nextUp, NOT overdue
///
/// Fill order is Heute → Ueberfaellig → Dringend. Once `limit` is reached
/// later sections are dropped. `abgeschnittenCount` reports how many BACKLOG
/// items (Ueberfaellig + Dringend, NOT Heute) didn't fit.
struct MenuBarBacklogGrouping {
    struct Result {
        let heute: [LocalTask]
        let ueberfaellig: [LocalTask]
        let dringend: [LocalTask]
        /// Number of backlog tasks (Ueberfaellig + Dringend) NOT shown.
        /// Heute-Tasks are intentionally excluded from this count.
        let abgeschnittenCount: Int
    }

    static func group(tasks: [LocalTask], limit: Int = 9, now: Date = Date()) -> Result {
        let startOfToday = Calendar.current.startOfDay(for: now)

        let active = tasks.filter { !$0.isCompleted }

        // Heute: every active nextUp task
        let heuteAll = active
            .filter { $0.isNextUp }
            .sorted { $0.priorityScore > $1.priorityScore }

        // Ueberfaellig: due < startOfToday, NOT nextUp
        let ueberfaelligAll = active.filter { task in
            guard let due = task.dueDate else { return false }
            return due < startOfToday && !task.isNextUp
        }.sorted { $0.priorityScore > $1.priorityScore }

        // Dringend: tier .doNow, NOT nextUp, NOT overdue
        let dringendAll = active.filter { task in
            guard task.priorityTier == .doNow, !task.isNextUp else { return false }
            if let due = task.dueDate, due < startOfToday { return false }
            return true
        }.sorted { $0.priorityScore > $1.priorityScore }

        // Fill order: Heute → Ueberfaellig → Dringend, capped at `limit` total
        var remaining = max(0, limit)
        let heute = Array(heuteAll.prefix(remaining))
        remaining -= heute.count
        let ueberfaellig = Array(ueberfaelligAll.prefix(remaining))
        remaining -= ueberfaellig.count
        let dringend = Array(dringendAll.prefix(remaining))

        // Abgeschnitten = backlog total minus backlog shown.
        // Heute-Tasks are NOT counted (per Henning's spec).
        let backlogTotal = ueberfaelligAll.count + dringendAll.count
        let backlogShown = ueberfaellig.count + dringend.count
        let abgeschnitten = max(0, backlogTotal - backlogShown)

        return Result(
            heute: heute,
            ueberfaellig: ueberfaellig,
            dringend: dringend,
            abgeschnittenCount: abgeschnitten
        )
    }
}

/// Menu Bar popover content showing current focus state and quick actions
struct MenuBarView: View {
    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && $0.isNextUp },
           sort: \LocalTask.nextUpSortOrder)
    private var nextUpTasks: [LocalTask]

    /// Bug #290: Backlog-Tasks ohne SwiftData-Sortierung — Sortierung & Tier-Gruppierung
    /// per Post-Fetch durch `MenuBarBacklogGrouping` (Score ist computed → kein @Query-Sort).
    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp })
    private var backlogTasks: [LocalTask]

    @Query private var allTasks: [LocalTask]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.eventKitRepository) private var eventKitRepo

    // Existing state
    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    @State private var isNextUp = false

    // FocusBlock state
    @State private var activeBlock: FocusBlock?
    @State private var currentTime = Date()
    @State private var taskStartTime: Date?
    @State private var lastTaskID: String?
    @State private var refreshCounter = 0

    // Timer: 1s when active block, 60s polling otherwise
    private let activeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let pollingTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Focus Section (NEW - above header)
            focusSection
                .accessibilityIdentifier("menubar_focusSection")

            Divider()

            // Header
            header

            Divider()

            // Quick Add
            quickAddSection

            Divider()

            // Next Up Tasks (HEUTE — unveraendert seit RW 2.4b)
            nextUpSection

            // Bug #290: Tier-Sektionen statt flacher backlog-Liste.
            // Heute-Tasks zeigt bereits `nextUpSection` an — `MenuBarBacklogGrouping`
            // wird hier ohne nextUp-Tasks aufgerufen, damit kein Doppel-Render.
            tierSections

            Divider()

            // Footer Actions
            footerActions
        }
        .padding()
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loadFocusBlock() }
        .onReceive(activeTimer) { time in
            guard activeBlock != nil else { return }
            currentTime = time
            // Fix timer deadlock: periodically reload block from EventKit
            // so completed tasks from other devices are picked up
            refreshCounter += 1
            if refreshCounter % 15 == 0 { loadFocusBlock() }
        }
        .onReceive(pollingTimer) { _ in
            guard activeBlock == nil else { return }
            loadFocusBlock()
        }
    }

    // MARK: - Focus Section

    @ViewBuilder
    private var focusSection: some View {
        if let block = activeBlock {
            activeFocusSection(block: block)
        } else {
            idleFocusSection
        }
    }

    private var idleFocusSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.secondary)
            Text("Kein aktiver Focus Block")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("menubar_idleIndicator")
        }
    }

    private func activeFocusSection(block: FocusBlock) -> some View {
        let tasks = tasksForBlock(block)
        let remainingTasks = tasks.filter { !block.completedTaskIDs.contains($0.id) }
        let currentTask = remainingTasks.first
        let completedCount = block.completedTaskIDs.count
        let totalCount = block.taskIDs.count
        let blockProgress = min(1.0, currentTime.timeIntervalSince(block.startDate) / block.endDate.timeIntervalSince(block.startDate))

        return VStack(alignment: .leading, spacing: 8) {
            // Block name + remaining time
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(block.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("menubar_blockName")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text(blockRemainingText(block: block))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar + task count
            HStack(spacing: 8) {
                ProgressView(value: max(0, blockProgress))
                    .accessibilityIdentifier("menubar_blockProgress")
                Text("\(completedCount)/\(totalCount) Tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menubar_taskCount")
            }

            // Current task
            if let task = currentTask {
                currentTaskRow(task: task, block: block)
            }
        }
    }

    private func currentTaskRow(task: LocalTask, block: FocusBlock) -> some View {
        // Track task start
        let _ = trackTaskStartIfNeeded(taskID: task.id)

        let taskDurations = tasksForBlock(block).map { (id: $0.id, durationMinutes: $0.estimatedDuration ?? 15) }
        let plannedEnd = TimerCalculator.plannedTaskEndDate(
            blockStartDate: block.startDate,
            blockEndDate: block.endDate,
            taskDurations: taskDurations,
            currentTaskID: task.id
        )
        let remainingSec = TimerCalculator.remainingSeconds(until: plannedEnd, now: currentTime)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text(task.title)
                    .font(.callout)
                    .lineLimit(1)
                    .accessibilityIdentifier("menubar_currentTaskName")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text(MenuBarTimerFormatter.format(seconds: remainingSec))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(remainingSec < 60 ? .red : .primary)
                    .accessibilityIdentifier("menubar_taskTimer")
            }

            if let duration = task.estimatedDuration {
                Text("\(duration) min geschaetzt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    markTaskComplete(taskID: task.id, block: block)
                } label: {
                    Label("Erledigt", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.green)
                .accessibilityIdentifier("menubar_completeTask")

                Button {
                    skipTask(taskID: task.id, block: block)
                } label: {
                    Label("Weiter", systemImage: "forward.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("menubar_skipTask")

                Spacer()
            }
        }
    }

    private func blockRemainingText(block: FocusBlock) -> String {
        let remaining = block.endDate.timeIntervalSince(currentTime)
        let seconds = max(0, Int(remaining))
        return MenuBarTimerFormatter.format(seconds: seconds)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 20, height: 20)
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

                    Button(action: { isNextUp.toggle() }) {
                        Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .foregroundStyle(isNextUp ? .blue : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Heute")
                    .accessibilityIdentifier("qc_nextUpButton")

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
            Text("Heute")
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

    // MARK: - Tier Sections (Bug #290)

    /// Combined Ueberfaellig + Dringend sections with global 9-task-limit.
    /// Heute is rendered separately via `nextUpSection` to avoid duplication.
    /// Bug #289 regression fix: filteredForMenuBarPopover() entfernt Templates,
    /// Future-Recurrence-Instanzen, raw-Tasks, FocusBlock-zugewiesene und blockierte
    /// Tasks — sonst erscheinen Duplikate die im Hauptfenster nicht sichtbar sind.
    @ViewBuilder
    private var tierSections: some View {
        let backlogOnly = backlogTasks.filteredForMenuBarPopover().filter { !$0.isNextUp }
        let grouping = MenuBarBacklogGrouping.group(tasks: backlogOnly)

        if !grouping.ueberfaellig.isEmpty || !grouping.dringend.isEmpty || grouping.abgeschnittenCount > 0 {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if !grouping.ueberfaellig.isEmpty {
                    tierSection(
                        title: "Überfällig",
                        accent: .red,
                        tasks: grouping.ueberfaellig,
                        identifier: "menubar_overdueSection"
                    )
                }
                if !grouping.dringend.isEmpty {
                    tierSection(
                        title: "Dringend",
                        accent: .orange,
                        tasks: grouping.dringend,
                        identifier: "menubar_dringendSection"
                    )
                }
                if grouping.abgeschnittenCount > 0 {
                    moreCounter(grouping.abgeschnittenCount)
                }
            }
        }
    }

    private func tierSection(
        title: String,
        accent: Color,
        tasks: [LocalTask],
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .textCase(.uppercase)

            ForEach(tasks, id: \.uuid) { task in
                MenuBarTaskRow(task: task) {
                    toggleComplete(task)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func moreCounter(_ count: Int) -> some View {
        Button {
            // Open main window AND switch to Backlog tab via Notification
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: {
                $0.title == "FocusBlox" || $0.identifier?.rawValue == "main"
            }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
            NotificationCenter.default.post(name: .navigateToBacklog, object: nil)
        } label: {
            Text("+\(count) weitere im Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("menubar_moreCounter")
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

    // MARK: - Data Loading

    private func loadFocusBlock() {
        Task {
            let hasAccess = try? await eventKitRepo.requestAccess()
            guard hasAccess == true else { return }
            let blocks = try? eventKitRepo.fetchFocusBlocks(for: Date())
            activeBlock = blocks?.first { $0.isActive }
        }
    }

    // MARK: - Task Helpers

    private func tasksForBlock(_ block: FocusBlock) -> [LocalTask] {
        block.taskIDs.compactMap { taskID in
            allTasks.first { $0.id == taskID }
        }
    }

    private func trackTaskStartIfNeeded(taskID: String) {
        if lastTaskID != taskID {
            lastTaskID = taskID
            taskStartTime = Date()
        }
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let title = newTaskTitle
        let shouldMarkNextUp = isNextUp
        newTaskTitle = ""
        isAddingTask = false
        isNextUp = false

        Task {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let task = try? await taskSource.createTask(title: title, taskType: "")
            if shouldMarkNextUp, let task {
                task.isNextUp = true
                task.nextUpSortOrder = Int.max
                try? modelContext.save()
            }
        }
    }

    private func toggleComplete(_ task: LocalTask) {
        if !task.isCompleted {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try? syncEngine.completeTask(itemID: task.id)
        } else {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try? syncEngine.uncompleteTask(itemID: task.id)
        }
    }

    private func markTaskComplete(taskID: String, block: FocusBlock) {
        Task {
            _ = try? FocusBlockActionService.completeTask(
                taskID: taskID,
                block: block,
                taskStartTime: taskStartTime,
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            taskStartTime = nil
            loadFocusBlock()
        }
    }

    private func skipTask(taskID: String, block: FocusBlock) {
        Task {
            _ = try? FocusBlockActionService.skipTask(
                taskID: taskID,
                block: block,
                taskStartTime: taskStartTime,
                eventKitRepo: eventKitRepo
            )
            taskStartTime = nil
            loadFocusBlock()
        }
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
                .frame(maxWidth: .infinity, alignment: .leading)

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

// MARK: - Notification (Bug #290)

extension Notification.Name {
    /// Posted when MenuBar "+M weitere"-Counter is tapped — switches main window to Backlog tab.
    static let navigateToBacklog = Notification.Name("NavigateToBacklog")
}

#Preview {
    MenuBarView()
}
