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

    @State private var isLoading = false
    @State private var isPermissionDenied = false
    @State private var refreshID = UUID()
    @State private var behavioralProfile: BehavioralProfile?
    @State private var limitationWarningDismissed = false
    @State private var eveningReflectionText: String = ""
    @State private var activeDrawer: DayPhase?
    @State private var dismissedTaskIDs: Set<String> = []

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
            .filter { !$0.isCompleted && $0.isActionable && !$0.isNextUp && !dismissedTaskIDs.contains($0.id) }
            .sorted { $0.priorityScore > $1.priorityScore }
            .prefix(5)
            .map { $0 }
    }

    @ViewBuilder
    private var morningContent: some View {
        if isLoading {
            ProgressView()
        } else if morningTopTasks.isEmpty {
            coachText("Alles geplant — guter Start! Du weißt was heute zählt.")
        } else {
            let groups = groupTasksByReason(morningTopTasks)

            // Nur Zusammenfassung wenn mehrere Gruppen
            if groups.count > 1 {
                coachHeadline(morningCoachingText)
            }

            coachTaskSection(
                title: "Vorschläge für heute",
                titleIcon: "lightbulb.fill",
                titleColor: .orange,
                tasks: morningTopTasks,
                showReason: true,
                showActions: true
            )
        }
    }

    private var morningCoachingText: String {
        let groups = groupTasksByReason(morningTopTasks)
        let count = morningTopTasks.count
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
        refreshID = UUID()
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
        }
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

        if showReason {
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
            BacklogRow(item: task, isCompletionPending: completed)

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
                        dismissedTaskIDs.insert(task.id)
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
            let recentlyCompleted = try await syncEngine.syncCompletedTasks(days: 1)

            nextUpTasks = allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }

            completedTasks = recentlyCompleted.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= today
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
    }
}