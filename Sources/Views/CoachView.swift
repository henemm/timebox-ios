import SwiftData
import SwiftUI

/// Coach Tab — Emotionale Tages-Timeline
/// Zeigt alle 3 Tages-Phasen als scrollbaren Fluss:
/// Morning (Intention) → Daytime (Status + erledigte Tasks) → Evening (Reflexion + Stats)
struct CoachView: View {
    @AppStorage("morningEndHour") private var morningEndHour = 10
    @AppStorage("eveningStartHour") private var eveningStartHour = 18
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext
    @Environment(DeferredCompletionController.self) private var deferredCompletion

    // Morning data
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var nextUpTasks: [PlanItem] = []
    @State private var freeSlots: [TimeSlot] = []
    @State private var morningSuggestions: [NextUpSuggestion] = []

    // Daytime data
    @State private var completedTasks: [PlanItem] = []
    @State private var allTasks: [PlanItem] = []

    // Evening data
    @State private var unfinishedTasks: [PlanItem] = []
    @State private var timelineSegments: [DayTimelineSegment] = []

    // Review data
    @State private var todayBlocks: [FocusBlock] = []

    // Weekly stats data (letzte 7 Tage)
    @State private var weekBlocks: [FocusBlock] = []
    @State private var weekCalendarEvents: [CalendarEvent] = []
    @State private var weekCompletedTasks: [PlanItem] = []
    private let statsCalculator = ReviewStatsCalculator()

    @State private var isLoading = false
    @State private var isPermissionDenied = false
    @State private var refreshID = UUID()
    @State private var behavioralProfile: BehavioralProfile?
    @State private var limitationWarningDismissed = false
    @State private var eveningReflectionText: String = ""
    @State private var activeDrawer: DayPhase?
    @State private var dismissedTaskIDs: Set<String> = []
    @State private var selectedTasksPerSlot: [UUID: Set<String>] = [:]
    @State private var aiReasonTexts: [String: String] = [:]  // [taskID: reason]
    @State private var slotCandidates: [UUID: [NextUpSuggestion]] = [:]

    // Task interaction state (Bug #248)
    @State private var completeFeedback = false
    @State private var errorMessage: String?
    @State private var taskToEditDirectly: PlanItem?
    @State private var selectedItemForDuration: PlanItem?
    @State private var selectedItemForCategory: PlanItem?

    private var currentPhase: DayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        return DayPhase.from(hour: hour, morningEnd: morningEndHour, eveningStart: eveningStartHour)
    }

    private var totalCompleted: Int { completedTasks.count }

    private var totalPlanned: Int {
        todayBlocks.reduce(0) { $0 + $1.taskIDs.count }
    }

    private var completionPercentage: Int {
        guard totalPlanned > 0 else { return 0 }
        return Int((Double(totalCompleted) / Double(totalPlanned)) * 100)
    }

    // MARK: - Category Stats (Computed)

    private var todayCalendarEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        return calendarEvents.filter {
            $0.startDate >= startOfToday && $0.startDate < endOfToday
        }
    }

    private var dailyCategoryStats: [CategoryStat] {
        var taskStats: [String: Int] = [:]
        for task in completedTasks {
            taskStats[task.taskType, default: 0] += task.effectiveDuration
        }
        let combined = statsCalculator.computeCategoryMinutes(
            taskMinutesByCategory: taskStats, calendarEvents: todayCalendarEvents
        )
        return TaskCategory.allCases.compactMap { config in
            guard let minutes = combined[config.rawValue], minutes > 0 else { return nil }
            return CategoryStat(config: config, minutes: minutes)
        }.sorted { $0.minutes > $1.minutes }
    }

    private var dailyTotalMinutes: Int {
        dailyCategoryStats.reduce(0) { $0 + $1.minutes }
    }

    private var weeklyCategoryStats: [CategoryStat] {
        var taskStats: [String: Int] = [:]
        for task in weekCompletedTasks {
            taskStats[task.taskType, default: 0] += task.effectiveDuration
        }
        let combined = statsCalculator.computeCategoryMinutes(
            taskMinutesByCategory: taskStats, calendarEvents: weekCalendarEvents
        )
        return TaskCategory.allCases.compactMap { config in
            guard let minutes = combined[config.rawValue], minutes > 0 else { return nil }
            return CategoryStat(config: config, minutes: minutes)
        }.sorted { $0.minutes > $1.minutes }
    }

    private var weeklyTotalMinutes: Int {
        weeklyCategoryStats.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            drawer(phase: .morning, title: "Guten Morgen", icon: "sunrise.fill", color: .orange) {
                morningContent
            }
            drawer(phase: .daytime, title: "Dein Tag", icon: "sun.max.fill", color: .blue) {
                daytimeContent
            }
            drawer(phase: .evening, title: "Tagesrückblick", icon: "moon.stars.fill", color: .purple) {
                eveningContent
            }
            Spacer()
        }
        .accessibilityIdentifier("coachView")
        .task(id: refreshID) {
            await loadAllData()
        }
        .onAppear {
            loadPersistedDismissals()
            refreshID = UUID()
            // --open-drawer morning/daytime/evening: bestimmten Drawer öffnen (für Screenshots)
            if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "--open-drawer"),
               idx + 1 < ProcessInfo.processInfo.arguments.count {
                switch ProcessInfo.processInfo.arguments[idx + 1] {
                case "morning": activeDrawer = .morning
                case "daytime": activeDrawer = .daytime
                case "evening": activeDrawer = .evening
                default: activeDrawer = currentPhase
                }
            } else if activeDrawer == nil {
                activeDrawer = currentPhase
            }
        }
        .sensoryFeedback(.success, trigger: completeFeedback)
        .sheet(item: $taskToEditDirectly) { task in
            TaskFormSheet(
                task: task,
                onSave: { title, priority, duration, tags, urgency, taskType, dueDate, description, recurrencePattern, recurrenceWeekdays, recurrenceMonthDay, recurrenceInterval in
                    do {
                        let taskSource = LocalTaskSource(modelContext: modelContext)
                        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                        try syncEngine.updateTask(
                            itemID: task.id, title: title, importance: priority,
                            duration: duration, tags: tags, urgency: urgency,
                            taskType: taskType, dueDate: dueDate, description: description,
                            recurrencePattern: recurrencePattern,
                            recurrenceWeekdays: recurrenceWeekdays,
                            recurrenceMonthDay: recurrenceMonthDay,
                            recurrenceInterval: recurrenceInterval
                        )
                        Task { await loadAllData() }
                        NotificationCenter.default.post(name: .taskDataChanged, object: nil)
                    } catch {
                        errorMessage = "Task konnte nicht gespeichert werden."
                    }
                },
                onDelete: { deleteTask(task) }
            )
        }
        .sheet(item: $selectedItemForDuration) { item in
            DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
                updateDuration(for: item, minutes: newDuration)
            }
        }
        .sheet(item: $selectedItemForCategory) { item in
            CategoryPicker(currentCategory: item.taskType) { newCategory in
                updateCategory(for: item, category: newCategory)
            }
        }
        .alert("Fehler", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Drawer Component

    @ViewBuilder
    private func drawer<Content: View>(
        phase: DayPhase,
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let isOpen = activeDrawer == phase
        let isActive = currentPhase == phase

        VStack(spacing: 0) {
            // Header — immer sichtbar, tappbar
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    activeDrawer = isOpen ? nil : phase
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.title3)
                    Text(title)
                        .font(.headline)
                    if isActive {
                        Text("Jetzt")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.2), in: Capsule())
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(isActive ? color.opacity(0.06) : .clear)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("coachDrawer_\(title)")

            Divider()

            // Content — nur wenn offen
            if isOpen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        content()
                    }
                    .padding()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxHeight: isOpen ? .infinity : nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(phase == .morning ? "coachMorningSection" :
                                 phase == .daytime ? "coachDaytimeSection" : "coachEveningSection")
    }

    // MARK: - Morning Content

    private var morningTopTasks: [PlanItem] {
        allTasks
            .filter {
                !$0.isCompleted && $0.isActionable && !$0.isNextUp &&
                !$0.isScheduled && $0.assignedFocusBlockID == nil &&
                !dismissedTaskIDs.contains($0.id)
            }
            .sorted { $0.priorityScore > $1.priorityScore }
            .prefix(5)
            .map { $0 }
    }

    @ViewBuilder
    private var morningContent: some View {
        if isLoading {
            ProgressView()
        } else if morningTopTasks.isEmpty && freeSlots.isEmpty {
            coachText("Alles geplant — guter Start! Du weißt was heute zählt.")
        } else {
            if !freeSlots.isEmpty && !slotCandidates.isEmpty {
                morningSlotSection
            }

            if !morningTopTasks.isEmpty {
                let clusterResult = NextUpSuggestionService.tagClusterGroups(from: morningTopTasks)

                // Tag-Cluster zuerst (wenn vorhanden, max 1)
                if let cluster = clusterResult.clusters.first {
                    let clusterCoachText = NextUpSuggestionService.tagClusterCoachText(
                        tag: cluster.tag, count: cluster.tasks.count
                    )
                    coachTaskSection(
                        title: "#\(cluster.tag)",
                        titleIcon: "tag.fill",
                        titleColor: .blue,
                        tasks: cluster.tasks,
                        coachOverrideText: clusterCoachText,
                        showReason: false,
                        showActions: true
                    )
                }

                // Restliche Tasks mit Reason-Gruppierung
                if !clusterResult.remaining.isEmpty {
                    let groups = groupTasksByReason(clusterResult.remaining)
                    if groups.count > 1 || !clusterResult.clusters.isEmpty {
                        coachHeadline(morningCoachingText(for: clusterResult.remaining))
                    }
                    coachTaskSection(
                        title: "Vorschläge für heute",
                        titleIcon: "lightbulb.fill",
                        titleColor: .orange,
                        tasks: clusterResult.remaining,
                        showReason: true,
                        showActions: true
                    )
                }
            }
        }
    }

    private func morningCoachingText(for tasks: [PlanItem]) -> String {
        let groups = groupTasksByReason(tasks)
        let count = tasks.count
        let groupCount = groups.count

        // Überblick über alle Gruppen — nicht den Inhalt einer Gruppe wiederholen
        if groupCount == 1 {
            return "" // Wird nicht angezeigt (groups.count <= 1)
        }

        let groupNames = groups.compactMap {
            NextUpSuggestionService.ReasonCategory(rawValue: $0.category)
        }.map { cat -> String in
            switch cat {
            case .deadline: return "Deadlines"
            case .stuck: return "aufgeschobene Aufgaben"
            case .important: return "Wichtiges"
            case .priority: return "Prioritäten"
            case .category, .backlog: return "offene Tasks"
            }
        }

        let summary = groupNames.joined(separator: ", ")
        return "\(count) Vorschläge für heute — \(summary). Schau dir an, was am besten in deinen Tag passt."
    }

    private func addToToday(_ task: PlanItem) {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
        try? syncEngine.updateNextUp(itemID: task.id, isNextUp: true)
        NextUpSuggestionService.invalidateCache()
        refreshID = UUID()
    }

    // MARK: - Morning Slot Section (Feature #206)

    private var morningSlotSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Freie Lücken", systemImage: "clock.badge.questionmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(freeSlots) { slot in
                if let candidates = slotCandidates[slot.id], !candidates.isEmpty {
                    slotCard(slot: slot, candidates: candidates)
                }
            }
        }
        .accessibilityIdentifier("coachMorningSlotsSection")
    }

    @ViewBuilder
    private func slotCard(slot: TimeSlot, candidates: [NextUpSuggestion]) -> some View {
        let selected = selectedTasksPerSlot[slot.id] ?? []
        let totalMinutes = candidates
            .filter { selected.contains($0.id) }
            .compactMap(\.planItem.estimatedDuration)
            .reduce(0, +)
        let exceedsSlot = totalMinutes > slot.durationMinutes

        VStack(alignment: .leading, spacing: 10) {
            // Header: Time + Duration
            HStack {
                Text(slot.startDate, style: .time)
                    .font(.subheadline.weight(.medium))
                Text("—")
                    .foregroundStyle(.tertiary)
                Text("\(slot.durationMinutes) Min frei")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Task candidates with toggles
            ForEach(candidates) { suggestion in
                let isSelected = selected.contains(suggestion.id)
                Button {
                    withAnimation(.smooth) {
                        var current = selectedTasksPerSlot[slot.id] ?? []
                        if isSelected {
                            current.remove(suggestion.id)
                        } else {
                            current.insert(suggestion.id)
                        }
                        selectedTasksPerSlot[slot.id] = current
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.blue : Color.gray.opacity(0.4))
                            .imageScale(.medium)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.planItem.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            if let duration = suggestion.planItem.estimatedDuration {
                                Text("\(duration) Min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("slotTaskToggle_\(suggestion.id)")
            }

            // Duration warning
            if exceedsSlot {
                Label("Tasks dauern länger als die Lücke (\(totalMinutes) Min)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("slotDurationWarning")
            }

            // Create block button
            if !selected.isEmpty {
                Button {
                    createBlockForSlot(slot: slot, taskIDs: Array(selected))
                } label: {
                    Label("Block erstellen", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .accessibilityIdentifier("createBlockButton_\(slot.id)")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func createBlockForSlot(slot: TimeSlot, taskIDs: [String]) {
        Task {
            do {
                let blockID = try eventKitRepo.createFocusBlock(
                    startDate: slot.startDate, endDate: slot.endDate
                )
                try eventKitRepo.updateFocusBlock(
                    eventID: blockID, taskIDs: taskIDs,
                    completedTaskIDs: [], taskTimes: [:]
                )

                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                for taskID in taskIDs {
                    try syncEngine.updateAssignedFocusBlock(itemID: taskID, focusBlockID: blockID)
                }

                withAnimation(.smooth) {
                    freeSlots.removeAll { $0.id == slot.id }
                    selectedTasksPerSlot.removeValue(forKey: slot.id)
                    slotCandidates.removeValue(forKey: slot.id)
                }
            } catch {
                // Silently fail — block creation is non-critical
            }
        }
    }

    // MARK: - Daytime Content

    /// Tasks die heute geplant sind (NextUp)
    private var todayPlannedTasks: [PlanItem] {
        allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }
    }

    @ViewBuilder
    private var daytimeContent: some View {
        if isLoading {
            ProgressView()
        } else {
            // Coaching-Text — Hero
            coachHeadline(SuccessStoryService.daytimeMotivation(
                completedCount: completedTasks.count,
                totalPlanned: todayPlannedTasks.count + completedTasks.count
            ))
            .accessibilityIdentifier("coachDaytimeMotivation")

            // Heute geplante Tasks
            if !todayPlannedTasks.isEmpty {
                coachTaskSection(
                    title: "Heute geplant",
                    titleIcon: "calendar",
                    titleColor: .blue,
                    tasks: todayPlannedTasks,
                    showReason: true,
                    showActions: false
                )
            }

            // Erledigte Tasks
            if !completedTasks.isEmpty {
                coachTaskSection(
                    title: "Erledigt",
                    titleIcon: "checkmark.circle.fill",
                    titleColor: .green,
                    tasks: completedTasks,
                    showReason: false,
                    showActions: false,
                    completed: true
                )
            }

            // Vorschläge
            if !morningTopTasks.isEmpty {
                coachTaskSection(
                    title: "Vorschläge",
                    titleIcon: "lightbulb.fill",
                    titleColor: .orange,
                    tasks: Array(morningTopTasks.prefix(3)),
                    showReason: true,
                    showActions: true
                )
            }

            // CTA wenn komplett leer
            if todayPlannedTasks.isEmpty && completedTasks.isEmpty && morningTopTasks.isEmpty {
                coachEmptyState(icon: "sparkles", color: .blue, text: "Noch nichts geplant — starte mit den Vorschlägen!")
                Button {
                    activeDrawer = .morning
                } label: {
                    Label("Vorschläge ansehen", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("coachDaytimeCTA")
            }
        }
    }

    // MARK: - Evening Content

    @ViewBuilder
    private var eveningContent: some View {
        if isLoading {
            ProgressView()
        } else {
            // Reflexionstext — Hero
            coachHeadline(eveningReflectionText)
                .accessibilityIdentifier("eveningReflectionText")

            // Completion Ring
            if totalPlanned > 0 {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.secondary.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                            .stroke(
                                completionPercentage == 100 ? .green : .blue,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: completionPercentage)
                        Text("\(completionPercentage)%")
                            .font(.headline.weight(.bold))
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalCompleted) von \(totalPlanned) geplanten Tasks")
                            .font(.subheadline.weight(.medium))
                        if todayBlocks.count > 0 {
                            Text("\(todayBlocks.count) Focus Blocks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("coachCompletionRing")
            }

            // Erledigte Tasks
            if !completedTasks.isEmpty {
                coachTaskSection(
                    title: "Erledigt",
                    titleIcon: "checkmark.circle.fill",
                    titleColor: .green,
                    tasks: completedTasks,
                    showReason: false,
                    showActions: false,
                    completed: true
                )
            }

            // Offen geblieben
            if !unfinishedTasks.isEmpty {
                coachTaskSection(
                    title: "Offen geblieben",
                    titleIcon: "arrow.uturn.right.circle",
                    titleColor: .orange,
                    tasks: unfinishedTasks,
                    showReason: false,
                    showActions: false
                )
            }

            // Kategorie-Statistik heute
            eveningDailyCategorySection

            // Kategorie-Statistik letzte 7 Tage
            eveningWeeklyCategorySection

            // Planungsgenauigkeit
            eveningPlanningAccuracySection
        }
    }

    // MARK: - Evening Stats Sections

    @ViewBuilder
    private var eveningDailyCategorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zeit pro Kategorie — Heute")
                .font(.headline)

            if dailyCategoryStats.isEmpty {
                Text("Keine Daten vorhanden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(dailyCategoryStats) { stat in
                        CategoryBar(stat: stat, totalMinutes: dailyTotalMinutes)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachDailyCategoryStats")
    }

    @ViewBuilder
    private var eveningWeeklyCategorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zeit pro Kategorie — Letzte 7 Tage")
                .font(.headline)

            if weeklyCategoryStats.isEmpty {
                Text("Keine Daten vorhanden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(weeklyCategoryStats) { stat in
                        CategoryBar(stat: stat, totalMinutes: weeklyTotalMinutes)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachWeeklyCategoryStats")
    }

    @ViewBuilder
    private var eveningPlanningAccuracySection: some View {
        let stats = statsCalculator.computePlanningAccuracy(blocks: weekBlocks, allTasks: allTasks)

        VStack(alignment: .leading, spacing: 16) {
            Text("Planungsgenauigkeit")
                .font(.headline)

            if stats.trackedTaskCount > 0 {
                HStack {
                    Image(systemName: stats.averageDeviation < -0.05 ? "hare" : stats.averageDeviation > 0.05 ? "tortoise" : "checkmark.seal")
                        .foregroundStyle(stats.averageDeviation < -0.05 ? .green : stats.averageDeviation > 0.05 ? .orange : .blue)
                    Text("Durchschnitt: \(stats.averageDeviationFormatted)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(stats.trackedTaskCount) Tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    AccuracyPill(count: stats.fasterCount, label: "Schneller", color: .green, icon: "arrow.up.circle.fill")
                    AccuracyPill(count: stats.onTimeCount, label: "Im Plan", color: .blue, icon: "checkmark.circle.fill")
                    AccuracyPill(count: stats.slowerCount, label: "Langsamer", color: .orange, icon: "arrow.down.circle.fill")
                }
            }

            if stats.rescheduledTaskCount > 0 {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.purple)
                    Text("\(stats.rescheduledTaskCount) Tasks umgeplant")
                        .font(.subheadline)
                    Spacer()
                    Text("\(stats.totalReschedules)x total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !stats.hasData {
                Text("Noch keine Focus Blocks mit Zeiterfassung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachPlanningAccuracy")
    }

    private var nextUpcomingBlock: FocusBlock? {
        let now = Date()
        return todayBlocks
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    // MARK: - Shared Section Components

    /// Zusammenfassung — nur bei mehreren Gruppen, visuell dominant
    private func coachHeadline(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Gruppen-Coaching-Text — Detail pro Gruppe
    private func coachText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coachEmptyState(icon: String, color: Color, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func coachTaskSection(
        title: String,
        titleIcon: String,
        titleColor: Color,
        tasks: [PlanItem],
        coachOverrideText: String? = nil,
        showReason: Bool,
        showActions: Bool,
        completed: Bool = false
    ) -> some View {
        // Section Header
        HStack(spacing: 6) {
            Image(systemName: titleIcon)
                .foregroundStyle(titleColor)
                .font(.subheadline)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(tasks.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(titleColor.opacity(0.15), in: Capsule())
        }
        .padding(.top, 8)

        if let overrideText = coachOverrideText {
            // Tag-Cluster: einzelner Coach-Text + Tasks
            coachText(overrideText)
            ForEach(tasks) { task in
                taskWithActions(task, showActions: showActions, completed: completed)
            }
        } else if showReason {
            // Gruppiert: Coaching-Text als Card → Tasks darunter
            let groups = groupTasksByReason(tasks)
            ForEach(groups, id: \.category) { group in
                // Coach redet
                coachText(group.text)

                // Tasks als Beleg
                ForEach(group.tasks) { task in
                    taskWithActions(task, showActions: showActions, completed: completed)
                }
            }
        } else {
            // Ungegruppiert: nur Tasks
            ForEach(tasks) { task in
                taskWithActions(task, showActions: showActions, completed: completed)
            }
        }
    }

    private struct ReasonGroup {
        let category: String
        let text: String
        var tasks: [PlanItem]
    }

    private func groupTasksByReason(_ tasks: [PlanItem]) -> [ReasonGroup] {
        var groups: [ReasonGroup] = []
        for task in tasks {
            let cat = NextUpSuggestionService.reasonCategory(for: task)
            if let idx = groups.firstIndex(where: { $0.category == cat.rawValue }) {
                groups[idx].tasks.append(task)
            } else {
                groups.append(ReasonGroup(category: cat.rawValue, text: "", tasks: [task]))
            }
        }
        // Gruppen-Texte generieren mit allen Tasks der Gruppe
        return groups.map { group in
            let cat = NextUpSuggestionService.ReasonCategory(rawValue: group.category) ?? .backlog
            let text = NextUpSuggestionService.groupReasonText(category: cat, tasks: group.tasks)
            return ReasonGroup(category: group.category, text: text, tasks: group.tasks)
        }
    }

    @ViewBuilder
    private func taskWithActions(_ task: PlanItem, showActions: Bool, completed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BacklogRow(
                item: task,
                onComplete: { completeTask(task) },
                onCancelCompletion: { cancelCompletion(task) },
                onDurationTap: { selectedItemForDuration = task },
                onImportanceCycle: { newImportance in updateImportance(for: task, importance: newImportance) },
                onUrgencyToggle: { newUrgency in updateUrgency(for: task, urgency: newUrgency) },
                onCategoryTap: { selectedItemForCategory = task },
                onEditTap: { taskToEditDirectly = task },
                onDeleteTap: { deleteTask(task) },
                onStartFocusSprint: { startFocusSprint(for: task) },
                onTitleSave: { newTitle in saveTitleEdit(for: task, title: newTitle) },
                isCompletionPending: completed || deferredCompletion.isPending(task.id)
            )
            .contextMenu {
                if !task.isNextUp {
                    Button {
                        addToToday(task)
                    } label: {
                        Label("Für heute einplanen", systemImage: "calendar.circle.fill")
                    }
                }
                Button {
                    startFocusSprint(for: task)
                } label: {
                    Label("Focus Sprint", systemImage: "bolt.fill")
                }
                Divider()
                Button {
                    taskToEditDirectly = task
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }

            // AI-Begründung (Feature #234)
            if showActions, let reason = aiReasonTexts[task.id] {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .transition(.opacity)
            }

            if showActions {
                HStack(spacing: 12) {
                    Button {
                        addToToday(task)
                    } label: {
                        Label("Für heute einplanen", systemImage: "calendar.badge.plus")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        dismissTask(task.id)
                    } label: {
                        Label("Ausblenden", systemImage: "eye.slash")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .padding(.leading, 34)
            }
        }
    }

    // MARK: - Dismissal Persistence (Bug #226)

    /// Dismissals werden tagesbasiert in UserDefaults gespeichert.
    /// Tasks kommen frühestens nach 3 Tagen wieder.
    private func dismissTask(_ taskID: String) {
        dismissedTaskIDs.insert(taskID)
        var stored = Self.loadDismissals()
        stored[taskID] = Date()
        Self.saveDismissals(stored)
    }

    private func loadPersistedDismissals() {
        let stored = Self.loadDismissals()
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        dismissedTaskIDs = Set(stored.filter { $0.value > cutoff }.map(\.key))
    }

    private static let dismissalsKey = "coachDismissedSuggestions"

    private static func loadDismissals() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: dismissalsKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func saveDismissals(_ dismissals: [String: Date]) {
        // Alte Einträge (>7 Tage) bereinigen
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cleaned = dismissals.filter { $0.value > cutoff }
        if let data = try? JSONEncoder().encode(cleaned) {
            UserDefaults.standard.set(data, forKey: dismissalsKey)
        }
    }

    // MARK: - Task Interactions (Bug #248)

    private func completeTask(_ item: PlanItem) {
        completeFeedback.toggle()
        deferredCompletion.scheduleCompletion(id: item.id) { [modelContext] in
            do {
                let taskSource = LocalTaskSource(modelContext: modelContext)
                let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                try syncEngine.completeTask(itemID: item.id)
                await loadAllData()
            } catch {
                errorMessage = "Task konnte nicht als erledigt markiert werden."
            }
        }
        NotificationCenter.default.post(name: .taskDataChanged, object: nil)
    }

    private func cancelCompletion(_ item: PlanItem) {
        deferredCompletion.cancelCompletion(id: item.id)
    }

    private func deleteTask(_ task: PlanItem) {
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            try syncEngine.deleteTask(itemID: task.id)
            Task { await loadAllData() }
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Task konnte nicht gelöscht werden."
        }
    }

    private func updateImportance(for item: PlanItem, importance: Int?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.importance = importance
            task.modifiedAt = Date()
            try modelContext.save()
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Wichtigkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateUrgency(for item: PlanItem, urgency: String?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.urgency = urgency
            task.modifiedAt = Date()
            try modelContext.save()
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Dringlichkeit konnte nicht aktualisiert werden."
        }
    }

    private func updateDuration(for item: PlanItem, minutes: Int?) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.estimatedDuration = minutes
            task.modifiedAt = Date()
            try modelContext.save()
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Dauer konnte nicht aktualisiert werden."
        }
    }

    private func updateCategory(for item: PlanItem, category: String) {
        do {
            guard let itemUUID = UUID(uuidString: item.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let task = try modelContext.fetch(descriptor).first else { return }
            task.taskType = category
            task.modifiedAt = Date()
            try modelContext.save()
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Kategorie konnte nicht aktualisiert werden."
        }
    }

    private func startFocusSprint(for item: PlanItem) {
        do {
            let result = try FocusBlockActionService.startImmediate(
                taskID: item.id,
                eventKitRepo: eventKitRepo,
                modelContext: modelContext
            )
            switch result {
            case .started:
                NotificationCenter.default.post(name: .focusSprintStarted, object: nil)
            case .blockedByActiveBlock:
                errorMessage = "Focus Sprint blockiert — es läuft bereits ein Block."
            }
        } catch {
            errorMessage = "Focus Sprint konnte nicht gestartet werden."
        }
    }

    private func saveTitleEdit(for task: PlanItem, title: String) {
        do {
            guard let itemUUID = UUID(uuidString: task.id) else { return }
            let descriptor = FetchDescriptor<LocalTask>(predicate: #Predicate { $0.uuid == itemUUID })
            guard let localTask = try modelContext.fetch(descriptor).first else { return }
            localTask.title = title
            localTask.modifiedAt = Date()
            try modelContext.save()
            Task { await loadAllData() }
            NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        } catch {
            errorMessage = "Titel konnte nicht gespeichert werden."
        }
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Task-Daten laden (unabhängig von EventKit)
        do {
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            allTasks = try await syncEngine.sync()
            let recentlyCompleted = try await syncEngine.syncCompletedTasks(days: 7)

            nextUpTasks = allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }

            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

            completedTasks = recentlyCompleted.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= today
            }

            weekCompletedTasks = recentlyCompleted.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= sevenDaysAgo
            }

            unfinishedTasks = allTasks.filter {
                !$0.isCompleted &&
                ($0.isNextUp || ($0.isScheduled && Calendar.current.isDateInToday($0.scheduledDate!)))
            }
        } catch {
            // Task-Daten nicht verfügbar — Sections zeigen leeren Zustand
        }

        // Kalender-Daten laden (braucht EventKit-Zugriff)
        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                isPermissionDenied = true
                return
            }

            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: Date())
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: Date())
            todayBlocks = focusBlocks.filter { calendar.isDate($0.startDate, inSameDayAs: today) }

            // Wochen-Daten für Stats (letzte 7 Tage)
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            var allWeekBlocks: [FocusBlock] = []
            var allWeekEvents: [CalendarEvent] = []
            var currentDate = sevenDaysAgo
            while currentDate < today {
                let dayBlocks = try eventKitRepo.fetchFocusBlocks(for: currentDate)
                allWeekBlocks.append(contentsOf: dayBlocks)
                let dayEvents = try eventKitRepo.fetchCalendarEvents(for: currentDate)
                allWeekEvents.append(contentsOf: dayEvents)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? today
            }
            // Heute dazurechnen (bereits geladen)
            allWeekBlocks.append(contentsOf: todayBlocks)
            allWeekEvents.append(contentsOf: calendarEvents)
            weekBlocks = allWeekBlocks
            weekCalendarEvents = allWeekEvents

            let scheduledPairs = allTasks
                .filter { $0.isScheduled }
                .map { (
                    start: $0.scheduledDate!,
                    end: $0.scheduledDate!.addingTimeInterval(
                        Double($0.scheduledDuration ?? $0.estimatedDuration ?? 30) * 60
                    )
                ) }
            freeSlots = GapFinder(
                events: calendarEvents, focusBlocks: focusBlocks,
                scheduledTasks: scheduledPairs, date: Date()
            ).findFreeSlots(minMinutes: 30, maxMinutes: 60)

            let profile = BehavioralProfileService.profile(
                tasks: try await LocalTaskSource(modelContext: modelContext).fetchIncompleteTasks(),
                focusBlocks: focusBlocks,
                calendarEvents: calendarEvents
            )
            behavioralProfile = profile
            morningSuggestions = NextUpSuggestionService.suggestions(
                items: allTasks, slots: freeSlots,
                profile: profile, calendarEvents: calendarEvents
            )
            slotCandidates = NextUpSuggestionService.candidatesPerSlot(
                items: allTasks, slots: freeSlots,
                profile: profile, calendarEvents: calendarEvents,
                now: Date(), maxPerSlot: 3
            )

            timelineSegments = DayView.buildEveningSegments(
                events: calendarEvents, completed: completedTasks, unfinished: unfinishedTasks
            )
        } catch {
            // Silently fail — sections show empty state
        }

        // Evening reflection generieren
        eveningReflectionText = await SuccessStoryService.generate(
            completedTasks: completedTasks,
            focusBlocks: focusBlocks
        )

        // AI-Begründungen für Vorschläge laden (async, non-blocking)
        await loadAIReasons()
    }

    private func loadAIReasons() async {
        let tasksToExplain = morningTopTasks
        guard !tasksToExplain.isEmpty else { return }

        for task in tasksToExplain {
            let slot = morningSuggestions.first { $0.planItem.id == task.id }?.slot
            let reason = await AICoachReasonService.reason(
                for: task, slot: slot, profile: behavioralProfile, allItems: allTasks
            )
            aiReasonTexts[task.id] = reason
        }
    }
}

// MARK: - Tag-Cluster Grouping (#236)

extension NextUpSuggestionService {

    struct TagCluster {
        let tag: String
        let tasks: [PlanItem]
    }

    struct TagClusterResult {
        let clusters: [TagCluster]
        let remaining: [PlanItem]
    }

    /// Findet den größten Tag-Cluster (≥2 Tasks mit gleichem Tag).
    /// Maximal 1 Cluster. Bei Gleichstand: alphabetisch erster Tag.
    static func tagClusterGroups(from tasks: [PlanItem]) -> TagClusterResult {
        var tagTasks: [String: [PlanItem]] = [:]
        for task in tasks {
            for tag in task.tags {
                tagTasks[tag, default: []].append(task)
            }
        }

        let bestCluster = tagTasks
            .filter { $0.value.count >= 2 }
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count > rhs.value.count
                }
                return lhs.key < rhs.key
            }
            .first

        guard let best = bestCluster else {
            return TagClusterResult(clusters: [], remaining: tasks)
        }

        let clusterTaskIDs = Set(best.value.map(\.id))
        let remaining = tasks.filter { !clusterTaskIDs.contains($0.id) }

        return TagClusterResult(
            clusters: [TagCluster(tag: best.key, tasks: best.value)],
            remaining: remaining
        )
    }

    /// Coaching-Text für eine Tag-Gruppe.
    static func tagClusterCoachText(tag: String, count: Int) -> String {
        "\(count) Aufgaben mit #\(tag) — erledige sie in einem Rutsch"
    }
}