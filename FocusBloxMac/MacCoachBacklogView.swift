//
//  MacCoachBacklogView.swift
//  FocusBloxMac
//
//  Coach-mode Backlog for macOS: Monster header + ranked tasks.
//  Replaces the normal backlog view when coachModeEnabled == true.
//

import SwiftUI
import SwiftData

struct MacCoachBacklogView: View {
    let tasks: [LocalTask]
    @Binding var selectedTasks: Set<UUID>
    var onImport: (() async -> Void)?

    @Environment(CloudKitSyncMonitor.self) private var cloudKitMonitor
    @Environment(DeferredSortController.self) private var deferredSort
    @AppStorage("selectedCoach") private var selectedCoach: String = ""
    @AppStorage("coachBacklogViewMode") private var selectedModeRaw: String = "Priorität"
    @AppStorage("remindersSyncEnabled") private var remindersSyncEnabled: Bool = true
    @State private var isSyncing = false

    private var selectedMode: CoachViewMode {
        CoachViewMode(rawValue: selectedModeRaw) ?? .priority
    }

    enum CoachViewMode: String, CaseIterable, Identifiable {
        case priority = "Priorität"
        case recent = "Zuletzt"
        case overdue = "Überfällig"
        case recurring = "Wiederkehrend"
        case completed = "Erledigt"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .priority: return "chart.bar.fill"
            case .recent: return "clock.arrow.circlepath"
            case .overdue: return "exclamationmark.circle"
            case .completed: return "checkmark.circle"
            case .recurring: return "arrow.triangle.2.circlepath"
            }
        }
    }

    // MARK: - Task Sections (via shared CoachBacklogViewModel + PlanItem bridge)

    private var planItems: [PlanItem] {
        tasks.filter { $0.modelContext != nil }.map { PlanItem(localTask: $0) }
    }

    private var nextUpTasks: [LocalTask] {
        let nextUpIDs = Set(CoachBacklogViewModel.nextUpTasks(from: planItems).map(\.id))
        return tasks.filter { nextUpIDs.contains($0.id) }
    }

    private var coachBoostedTasks: [LocalTask] {
        let boostIDs = Set(CoachBacklogViewModel.coachBoostedTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter { boostIDs.contains($0.id) }
    }

    private var remainingTasks: [LocalTask] {
        let remainingIDs = Set(CoachBacklogViewModel.remainingTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
        return tasks.filter { remainingIDs.contains($0.id) }
    }

    private var overdueTasks: [LocalTask] {
        let overdueIDs = Set(CoachBacklogViewModel.overdueTasks(from: planItems.filter {
            let remainIDs = Set(CoachBacklogViewModel.remainingTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
            return remainIDs.contains($0.id)
        }).map(\.id))
        return tasks.filter { overdueIDs.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: ViewMode-Switcher + Sync + Task Count
            HStack {
                viewModeSwitcher
                Spacer()

                syncStatusIndicator
                    .accessibilityIdentifier("coachSyncStatusIndicator")

                Button {
                    cloudKitMonitor.triggerSync()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("coachSyncButton")
                .help("CloudKit synchronisieren")

                if remindersSyncEnabled {
                    Button {
                        Task {
                            isSyncing = true
                            await onImport?()
                            isSyncing = false
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(isSyncing)
                    .accessibilityIdentifier("coachImportRemindersButton")
                    .help("Erinnerungen importieren")
                }

                Text("\(tasks.filter { !$0.isCompleted }.count) Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            taskList
        }
    }

    // MARK: - Task List (switches based on ViewMode)

    @ViewBuilder
    private var taskList: some View {
        switch selectedMode {
        case .priority:
            priorityView
        case .recent:
            recentView
        case .overdue:
            overdueView
        case .recurring:
            recurringView
        case .completed:
            completedView
        }
    }

    // MARK: - Priority View (Coach-Boost + Tiers)

    private var priorityView: some View {
        List(selection: $selectedTasks) {
            monsterHeader
                .listRowSeparator(.hidden)

            if !nextUpTasks.isEmpty {
                Section {
                    ForEach(nextUpTasks, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                        ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                            blockedRow(blocked).tag(blocked.uuid)
                        }
                    }
                } header: {
                    sectionHeader("Next Up", icon: "arrow.up.circle.fill", count: nextUpTasks.count, color: .green)
                }
                .accessibilityIdentifier("coachNextUpSection")
            }

            if !coachBoostedTasks.isEmpty, let sectionTitle = CoachBacklogViewModel.coachSectionTitle(for: selectedCoach) {
                Section {
                    ForEach(coachBoostedTasks, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                        ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                            blockedRow(blocked).tag(blocked.uuid)
                        }
                    }
                } header: {
                    sectionHeader(sectionTitle, count: coachBoostedTasks.count, color: .purple)
                }
                .accessibilityIdentifier("coachBoostSection")
            }

            if !overdueTasks.isEmpty {
                Section {
                    ForEach(overdueTasks, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                        ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                            blockedRow(blocked).tag(blocked.uuid)
                        }
                    }
                } header: {
                    sectionHeader("Überfällig", count: overdueTasks.count, color: .red)
                }
            }

            ForEach(TaskPriorityScoringService.PriorityTier.allCases, id: \.self) { tier in
                let overdueIDs = Set(overdueTasks.map(\.id))
                let remainPlanItems = planItems.filter {
                    let remainIDs = Set(CoachBacklogViewModel.remainingTasks(from: planItems, selectedCoach: selectedCoach).map(\.id))
                    return remainIDs.contains($0.id)
                }
                let tierPlanItems = CoachBacklogViewModel.tierTasks(from: remainPlanItems, tier: tier, excludeIDs: overdueIDs)
                let tierIDs = Set(tierPlanItems.map(\.id))
                let tierLocalTasks = tasks.filter { tierIDs.contains($0.id) }
                if !tierLocalTasks.isEmpty {
                    Section {
                        ForEach(tierLocalTasks, id: \.uuid) { task in
                            coachRow(task).tag(task.uuid)
                            ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                                blockedRow(blocked).tag(blocked.uuid)
                            }
                        }
                    } header: {
                        sectionHeader(tier.label, count: tierLocalTasks.count, color: tierColor(tier))
                    }
                }
            }
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Recent View

    private var recentView: some View {
        let recentIDs = CoachBacklogViewModel.recentTasks(from: planItems).map(\.id)
        let orderedTasks = recentIDs.compactMap { id in tasks.first { $0.id == id } }
        return List(selection: $selectedTasks) {
            monsterHeader.listRowSeparator(.hidden)
            Section {
                ForEach(orderedTasks, id: \.uuid) { task in
                    coachRow(task).tag(task.uuid)
                    ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                        blockedRow(blocked).tag(blocked.uuid)
                    }
                }
            } header: {
                Text("Zuletzt bearbeitet").font(.headline).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Overdue View

    private var overdueView: some View {
        let allOverdueIDs = Set(CoachBacklogViewModel.overdueTasks(from: planItems).map(\.id))
        let allOverdue = tasks.filter { allOverdueIDs.contains($0.id) }
        return List(selection: $selectedTasks) {
            monsterHeader.listRowSeparator(.hidden)
            if allOverdue.isEmpty {
                Text("Keine überfälligen Tasks").foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(allOverdue, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                        ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                            blockedRow(blocked).tag(blocked.uuid)
                        }
                    }
                } header: {
                    sectionHeader("Überfällig", count: allOverdue.count, color: .red)
                }
            }
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Recurring View

    private var recurringView: some View {
        let recurringIDs = Set(CoachBacklogViewModel.recurringTasks(from: planItems).map(\.id))
        let recurring = tasks.filter { recurringIDs.contains($0.id) }
        return List(selection: $selectedTasks) {
            monsterHeader.listRowSeparator(.hidden)
            if recurring.isEmpty {
                Text("Keine wiederkehrenden Tasks").foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(recurring, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                        ForEach(blockedTasks(for: task.id), id: \.uuid) { blocked in
                            blockedRow(blocked).tag(blocked.uuid)
                        }
                    }
                } header: {
                    Text("Wiederkehrend").font(.headline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Completed View

    private var completedView: some View {
        let completedIDs = Set(CoachBacklogViewModel.completedTasks(from: planItems).map(\.id))
        let completed = tasks.filter { completedIDs.contains($0.id) }
        return List(selection: $selectedTasks) {
            monsterHeader.listRowSeparator(.hidden)
            if completed.isEmpty {
                Text("Keine erledigten Tasks").foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(completed, id: \.uuid) { task in
                        coachRow(task).tag(task.uuid)
                    }
                } header: {
                    Text("Erledigt").font(.headline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("coachTaskList")
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, icon: String? = nil, count: Int, color: Color) -> some View {
        HStack {
            if let icon {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    // MARK: - ViewMode Switcher

    private var viewModeSwitcher: some View {
        Menu {
            ForEach(CoachViewMode.allCases) { mode in
                Button {
                    withAnimation(.smooth) { selectedModeRaw = mode.rawValue }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                Text(selectedMode.rawValue)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
        .accessibilityIdentifier("coachViewModeSwitcher")
    }

    // MARK: - Sync Status Indicator

    @ViewBuilder
    private var syncStatusIndicator: some View {
        if cloudKitMonitor.isSyncing || isSyncing {
            ProgressView()
                .scaleEffect(0.7)
        } else if cloudKitMonitor.hasSyncError {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
                .help(cloudKitMonitor.errorMessage ?? "Sync-Fehler")
        } else {
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
                .help(cloudKitMonitor.lastSuccessfulSync.map {
                    "Letzter Sync: \($0.formatted(date: .omitted, time: .shortened))"
                } ?? "CloudKit verbunden")
        }
    }

    // MARK: - Monster Header (shared component)

    private var monsterHeader: some View {
        MonsterIntentionHeader(selectedCoach: selectedCoach, imageHeight: 80)
    }

    // MARK: - Score Helpers (identisch zu ContentView.makeBacklogRow)

    private func dependentCount(for taskID: String) -> Int {
        tasks.filter { $0.blockerTaskID == taskID }.count
    }

    private func scoreFor(_ task: LocalTask) -> Int {
        let liveScore = TaskPriorityScoringService.calculateScore(
            importance: task.importance, urgency: task.urgency, dueDate: task.dueDate,
            createdAt: task.createdAt, rescheduleCount: task.rescheduleCount,
            estimatedDuration: task.estimatedDuration, taskType: task.taskType,
            isNextUp: task.isNextUp,
            dependentTaskCount: dependentCount(for: task.id)
        )
        return deferredSort.effectiveScore(id: task.id, liveScore: liveScore)
    }

    // MARK: - Blocked Task Helpers

    private func blockedTasks(for blockerID: String) -> [LocalTask] {
        tasks.filter { $0.blockerTaskID == blockerID }
    }

    private func blockedRow(_ task: LocalTask) -> some View {
        let discipline = Discipline.resolveOpen(
            manualDiscipline: task.manualDiscipline,
            rescheduleCount: task.rescheduleCount,
            importance: task.importance
        )
        let score = scoreFor(task)
        return MacBacklogRow(
            task: task,
            isBlocked: true,
            disciplineColor: discipline.color,
            dependentCount: dependentCount(for: task.id),
            effectiveScore: score,
            effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: score)
        )
        .contextMenu {
            Button {
                task.blockerTaskID = nil
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            } label: {
                Label("Freigeben", systemImage: "link.badge.plus")
            }
        }
    }

    // MARK: - Coach Row (with all callbacks)

    private func coachRow(_ task: LocalTask) -> some View {
        let discipline = Discipline.resolveOpen(
            manualDiscipline: task.manualDiscipline,
            rescheduleCount: task.rescheduleCount,
            importance: task.importance
        )
        let score = scoreFor(task)
        return MacBacklogRow(
            task: task,
            onToggleComplete: {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? Date() : nil
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            },
            onImportanceCycle: { newImportance in
                task.importance = newImportance
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            },
            onUrgencyToggle: { newUrgency in
                task.urgency = newUrgency
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            },
            onCategorySelect: { newCategory in
                task.taskType = newCategory
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            },
            onDurationSelect: { newDuration in
                task.estimatedDuration = newDuration
                task.modifiedAt = Date()
                try? task.modelContext?.save()
            },
            disciplineColor: discipline.color,
            dependentCount: dependentCount(for: task.id),
            effectiveScore: score,
            effectiveTier: TaskPriorityScoringService.PriorityTier.from(score: score)
        )
        .contextMenu {
            Section("Next Up") {
                Button {
                    task.isNextUp.toggle()
                    if task.isNextUp && task.nextUpSortOrder == nil {
                        task.nextUpSortOrder = Int.max
                    } else if !task.isNextUp {
                        task.nextUpSortOrder = nil
                    }
                    task.modifiedAt = Date()
                    try? task.modelContext?.save()
                } label: {
                    Label(task.isNextUp ? "Aus Next Up entfernen" : "Zu Next Up hinzufügen",
                          systemImage: task.isNextUp ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                }
            }
            if task.dueDate != nil {
                Section("Verschieben") {
                    Button {
                        if let ctx = task.modelContext { _ = LocalTask.postpone(task, byDays: 1, context: ctx) }
                    } label: {
                        Label("Morgen", systemImage: "sunrise")
                    }
                    Button {
                        if let ctx = task.modelContext { _ = LocalTask.postpone(task, byDays: 7, context: ctx) }
                    } label: {
                        Label("Nächste Woche", systemImage: "calendar.badge.plus")
                    }
                }
            }
            Section("Disziplin") {
                ForEach(Discipline.allCases, id: \.self) { d in
                    Button {
                        task.manualDiscipline = d.rawValue
                        task.modifiedAt = Date()
                        try? task.modelContext?.save()
                    } label: {
                        Label(d.displayName, systemImage: d.icon)
                    }
                    .tint(d.color)
                }
                if task.manualDiscipline != nil {
                    Divider()
                    Button {
                        task.manualDiscipline = nil
                        task.modifiedAt = Date()
                        try? task.modelContext?.save()
                    } label: {
                        Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                task.modelContext?.delete(task)
                try? task.modelContext?.save()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func tierColor(_ tier: TaskPriorityScoringService.PriorityTier) -> Color {
        switch tier {
        case .doNow: return .red
        case .planSoon: return .orange
        case .eventually: return .yellow
        case .someday: return .gray
        }
    }
}
