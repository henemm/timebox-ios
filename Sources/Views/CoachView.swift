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
        }
        .accessibilityIdentifier("coachView")
        .task(id: refreshID) {
            await loadAllData()
        }
        .onAppear {
            refreshID = UUID()
            if activeDrawer == nil {
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

    @ViewBuilder
    private var morningContent: some View {
        if isLoading {
            ProgressView()
        } else if morningSuggestions.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                Text("Alles geplant — guter Start!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            MorningCoachingSection(
                suggestions: morningSuggestions,
                onConfirm: { suggestion in
                    let taskSource = LocalTaskSource(modelContext: modelContext)
                    let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
                    try? syncEngine.updateNextUp(itemID: suggestion.id, isNextUp: true)
                    NextUpSuggestionService.invalidateCache()
                    morningSuggestions.removeAll { $0.id == suggestion.id }
                },
                onDismiss: { suggestion in
                    morningSuggestions.removeAll { $0.id == suggestion.id }
                }
            )
        }
    }

    // MARK: - Daytime Content

    @ViewBuilder
    private var daytimeContent: some View {
        if isLoading {
            ProgressView()
        } else {
            if !completedTasks.isEmpty {
                Label("\(completedTasks.count) Dinge geschafft", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("coachCompletedTasks")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Noch nichts erledigt — starte mit dem Wichtigsten!")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Evening Content

    @ViewBuilder
    private var eveningContent: some View {
        if isLoading {
            ProgressView()
        } else {
            Text(eveningReflectionText)
                .font(.body)
                .accessibilityIdentifier("eveningReflectionText")

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    if !timelineSegments.isEmpty {
                        DayTimelineBar(segments: timelineSegments)
                    }

                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(completedTasks.count) erledigt", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline.weight(.semibold))
                            ForEach(completedTasks) { task in
                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if totalPlanned > 0 {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(.secondary.opacity(0.2), lineWidth: 6)
                                Circle()
                                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                                    .stroke(
                                        completionPercentage == 100 ? .green : .blue,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(), value: completionPercentage)
                                Text("\(completionPercentage)%")
                                    .font(.caption.weight(.bold))
                            }
                            .frame(width: 50, height: 50)

                            VStack(alignment: .leading) {
                                Text("\(totalCompleted) von \(totalPlanned) geplanten Tasks")
                                    .font(.subheadline)
                                Text("\(todayBlocks.count) Focus Blocks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("coachCompletionRing")
                    }
                }
            } label: {
                Label("Details", systemImage: "chart.bar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("eveningDetailsToggle")
        }
    }

    private var nextUpcomingBlock: FocusBlock? {
        let now = Date()
        return todayBlocks
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
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