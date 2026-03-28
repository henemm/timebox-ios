import SwiftData
import SwiftUI

// MARK: - Day Timeline Segment

struct DayTimelineSegment: Identifiable, Equatable {
    let id = UUID()
    let startMinute: Int
    let endMinute: Int
    let kind: SegmentKind

    enum SegmentKind: Equatable {
        case completed
        case calendar
        case missed
    }

    var color: Color {
        switch kind {
        case .completed: .green
        case .calendar:  .secondary
        case .missed:    .orange
        }
    }

    static func == (lhs: DayTimelineSegment, rhs: DayTimelineSegment) -> Bool {
        lhs.startMinute == rhs.startMinute && lhs.endMinute == rhs.endMinute && lhs.kind == rhs.kind
    }
}

// MARK: - Day Timeline Bar

struct DayTimelineBar: View {
    let segments: [DayTimelineSegment]
    private let totalMinutes: CGFloat = 1440

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemFill))
                    .frame(height: 24)
                ForEach(segments) { seg in
                    let x = CGFloat(seg.startMinute) / totalMinutes * geo.size.width
                    let w = CGFloat(seg.endMinute - seg.startMinute) / totalMinutes * geo.size.width
                    RoundedRectangle(cornerRadius: 3)
                        .fill(seg.color)
                        .frame(width: max(w, 3), height: 24)
                        .offset(x: x)
                }
            }
        }
        .frame(height: 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayTimelineBar")
    }
}

// MARK: - Day Phase

enum DayPhase: Equatable {
    case morning
    case daytime
    case evening

    /// Determines the current phase from a given hour and settings.
    /// - Parameters:
    ///   - hour: Hour of day (0-23)
    ///   - morningEnd: Hour when morning ends (exclusive)
    ///   - eveningStart: Hour when evening starts (inclusive)
    static func from(hour: Int, morningEnd: Int, eveningStart: Int) -> DayPhase {
        if hour < morningEnd { return .morning }
        if hour < eveningStart { return .daytime }
        return .evening
    }
}

// MARK: - Day View

struct DayView: View {
    @AppStorage("morningEndHour") private var morningEndHour = 12
    @AppStorage("eveningStartHour") private var eveningStartHour = 18
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext

    @State private var calendarEvents: [CalendarEvent] = []
    @State private var focusBlocks: [FocusBlock] = []
    @State private var nextUpTasks: [PlanItem] = []
    @State private var freeSlots: [TimeSlot] = []
    @State private var morningSuggestions: [NextUpSuggestion] = []
    @State private var scheduledTasks: [TimelineItem] = []
    @State private var completedTasks: [PlanItem] = []
    @State private var unfinishedTasks: [PlanItem] = []
    @State private var timelineSegments: [DayTimelineSegment] = []
    @State private var isLoading = false
    @State private var isPermissionDenied = false
    @State private var behavioralProfile: BehavioralProfile?
    @State private var limitationWarningDismissed = false

    private var activeLimitationWarning: LimitationWarning? {
        guard !limitationWarningDismissed, let profile = behavioralProfile else { return nil }
        return LimitationGuardService.evaluate(tasks: nextUpTasks, profile: profile)
    }

    private var phase: DayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        return DayPhase.from(hour: hour, morningEnd: morningEndHour, eveningStart: eveningStartHour)
    }

    var body: some View {
        NavigationStack {
            phaseContent
                .navigationTitle(navigationTitle)
        }
        .task {
            switch phase {
            case .morning: await loadMorningData()
            case .daytime: await loadDaytimeData()
            case .evening: await loadEveningData()
            }
        }
        .onChange(of: nextUpTasks.count) {
            limitationWarningDismissed = false
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .morning:
            morningContent
        case .daytime:
            daytimeContent
        case .evening:
            eveningContent
        }
    }

    // MARK: - Daytime Content

    @ViewBuilder
    private var daytimeContent: some View {
        if isLoading {
            ProgressView("Lade Timeline...")
        } else if isPermissionDenied {
            permissionDeniedContent
        } else if calendarEvents.isEmpty && scheduledTasks.isEmpty {
            ContentUnavailableView(
                "Keine Termine",
                systemImage: "calendar",
                description: Text("Dein Tag ist frei")
            )
        } else {
            #if os(iOS)
            TimelineView(
                date: Date(),
                events: calendarEvents,
                scheduledTasks: scheduledTasks,
                onRefresh: { await loadDaytimeData() }
            )
            #else
            ContentUnavailableView(
                "Dein Tag",
                systemImage: "sun.max",
                description: Text("Timeline kommt bald")
            )
            #endif
        }
    }

    // MARK: - Morning Content

    @ViewBuilder
    private var morningContent: some View {
        if isLoading {
            ProgressView("Lade Kalender...")
        } else if isPermissionDenied {
            permissionDeniedContent
        } else if calendarEvents.isEmpty && nextUpTasks.isEmpty {
            ContentUnavailableView(
                "Keine Vorschlaege",
                systemImage: "sunrise",
                description: Text("Plan deinen Tag selbst")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !calendarEvents.isEmpty { morningEventsSection }
                    if !freeSlots.isEmpty { morningGapsSection }
                    if !morningSuggestions.isEmpty {
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
                            },
                            limitationWarning: nextUpTasks.isEmpty ? activeLimitationWarning : nil,
                            onDismissWarning: { limitationWarningDismissed = true }
                        )
                    }
                    if !nextUpTasks.isEmpty { morningNextUpSection }
                }
                .padding()
            }
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Kein Kalender-Zugriff",
                systemImage: "lock.shield",
                description: Text("Bitte Kalender-Zugriff in den Einstellungen aktivieren.")
            )
            #if os(iOS)
            Button("Einstellungen oeffnen", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
    }

    // MARK: - Morning Sections

    private var morningEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Termine")
                .font(.headline)
            ForEach(calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }) { event in
                HStack {
                    Text(event.startDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Text(event.title)
                        .font(.subheadline)
                }
            }
        }
    }

    private var morningGapsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Freie Luecken")
                .font(.headline)
            ForEach(freeSlots) { slot in
                HStack {
                    Text(slot.startDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Text("\(slot.durationMinutes) Min frei")
                        .font(.subheadline)
                }
                .padding(8)
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var morningNextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Up")
                .font(.headline)

            if let warning = activeLimitationWarning {
                LimitationWarningBanner(warning: warning, onDismiss: { limitationWarningDismissed = true })
            }

            ForEach(nextUpTasks) { task in
                HStack {
                    Text(task.title)
                        .font(.subheadline)
                    Spacer()
                    if let duration = task.estimatedDuration {
                        Text("\(duration) Min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Evening Content

    @ViewBuilder
    private var eveningContent: some View {
        if isLoading {
            ProgressView("Lade Tagesrückblick...")
        } else if isPermissionDenied {
            permissionDeniedContent
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !timelineSegments.isEmpty {
                        DayTimelineBar(segments: timelineSegments)
                    }
                    if !completedTasks.isEmpty { completedTasksSection }
                    if !unfinishedTasks.isEmpty { unfinishedTasksSection }
                    #if os(iOS)
                    SuccessStoryView(completedTasks: completedTasks, focusBlocks: focusBlocks)
                    failureQuickSelectSection
                    #endif
                }
                .padding()
            }
        }
    }

    // MARK: - Evening Sections

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(completedTasks.count) erledigt", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
            ForEach(completedTasks) { task in
                Text(task.title)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eveningCompletedSection")
    }

    private var unfinishedTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nicht erledigt", systemImage: "circle.dotted")
                .foregroundStyle(.orange)
                .font(.headline)
            ForEach(unfinishedTasks) { task in
                Text(task.title)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eveningUnfinishedSection")
    }

    #if os(iOS)
    @ViewBuilder
    private var failureQuickSelectSection: some View {
        if !unfinishedTasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(unfinishedTasks) { task in
                    FailureQuickSelectView(task: task)
                }
            }
        }
    }
    #endif

    // MARK: - Data Loading

    private func loadMorningData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                isPermissionDenied = true
                return
            }
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: Date())
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: Date())

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let allTasks = try await syncEngine.sync()
            nextUpTasks = allTasks.filter { $0.isNextUp && !$0.isCompleted && $0.isActionable }

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

            let profile: BehavioralProfile
            if ProcessInfo.processInfo.arguments.contains("--mock-limitation-profile") {
                profile = BehavioralProfile(
                    computedAt: Date(), categoryTimeAffinity: nil,
                    avgTasksPerDay: 2.0, avgMinutesPerDay: 60.0,
                    estimationFactor: nil, capacityByMeetingLoad: nil, procrastinationPatterns: nil
                )
            } else if ProcessInfo.processInfo.arguments.contains("--mock-high-profile") {
                profile = BehavioralProfile(
                    computedAt: Date(), categoryTimeAffinity: nil,
                    avgTasksPerDay: 20.0, avgMinutesPerDay: 600.0,
                    estimationFactor: nil, capacityByMeetingLoad: nil, procrastinationPatterns: nil
                )
            } else {
                profile = BehavioralProfileService.profile(
                    tasks: try await LocalTaskSource(modelContext: modelContext).fetchIncompleteTasks(),
                    focusBlocks: focusBlocks,
                    calendarEvents: calendarEvents
                )
            }
            behavioralProfile = profile
            morningSuggestions = NextUpSuggestionService.suggestions(
                items: allTasks, slots: freeSlots,
                profile: profile, calendarEvents: calendarEvents
            )
        } catch {
            // Silently fail — view shows empty state
        }
    }

    private func loadDaytimeData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                isPermissionDenied = true
                return
            }
            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: Date())
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: Date())

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let allTasks = try await syncEngine.sync()

            scheduledTasks = Self.scheduledTimelineItems(from: allTasks, for: Date())
        } catch {
            // Silently fail — view shows empty state
        }
    }

    private func loadEveningData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hasAccess = try await eventKitRepo.requestAccess()
            guard hasAccess else {
                isPermissionDenied = true
                return
            }

            calendarEvents = try eventKitRepo.fetchCalendarEvents(for: Date())
            focusBlocks = try eventKitRepo.fetchFocusBlocks(for: Date())

            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            let allTasks = try await syncEngine.sync()
            let recentlyCompleted = try await syncEngine.syncCompletedTasks(days: 1)

            let startOfDay = Calendar.current.startOfDay(for: Date())

            completedTasks = recentlyCompleted.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= startOfDay
            }

            unfinishedTasks = allTasks.filter {
                !$0.isCompleted &&
                ($0.isNextUp || ($0.isScheduled && Calendar.current.isDateInToday($0.scheduledDate!)))
            }

            timelineSegments = Self.buildEveningSegments(
                events: calendarEvents, completed: completedTasks, unfinished: unfinishedTasks
            )
        } catch {
            // Silently fail — view stays in empty state
        }
    }

    // MARK: - Data Mapping

    /// Filters scheduled tasks for a given date and maps them to TimelineItems.
    /// Extracted for unit testability.
    static func scheduledTimelineItems(from tasks: [PlanItem], for date: Date) -> [TimelineItem] {
        tasks
            .filter { $0.isScheduled && Calendar.current.isDate($0.scheduledDate!, inSameDayAs: date) }
            .map { task in
                TimelineItem(
                    scheduledTaskID: task.id,
                    title: task.title,
                    scheduledDate: task.scheduledDate!,
                    durationMinutes: task.scheduledDuration ?? task.estimatedDuration ?? 30
                )
            }
    }

    /// Builds timeline segments for the evening summary bar.
    /// Pure function, extracted for unit testability.
    static func buildEveningSegments(
        events: [CalendarEvent],
        completed: [PlanItem],
        unfinished: [PlanItem]
    ) -> [DayTimelineSegment] {
        var segments: [DayTimelineSegment] = []

        for event in events where !event.isAllDay && !event.isFocusBlock {
            let start = minutesFromMidnight(event.startDate)
            let end = minutesFromMidnight(event.endDate)
            segments.append(DayTimelineSegment(startMinute: start, endMinute: end, kind: .calendar))
        }

        for task in completed {
            guard let date = task.completedAt else { continue }
            let start = minutesFromMidnight(date)
            let duration = task.estimatedDuration ?? 30
            segments.append(DayTimelineSegment(startMinute: start, endMinute: start + duration, kind: .completed))
        }

        for task in unfinished {
            guard let date = task.scheduledDate else { continue }
            let start = minutesFromMidnight(date)
            let duration = task.scheduledDuration ?? task.estimatedDuration ?? 30
            segments.append(DayTimelineSegment(startMinute: start, endMinute: start + duration, kind: .missed))
        }

        return segments.sorted { $0.startMinute < $1.startMinute }
    }

    static func minutesFromMidnight(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    // MARK: - Navigation

    private var navigationTitle: String {
        switch phase {
        case .morning: return "Guten Morgen"
        case .daytime: return "Dein Tag"
        case .evening: return "Tagesrückblick"
        }
    }
}
