import SwiftData
import SwiftUI

/// Coach Tab — Emotionale Tages-Timeline
/// Zeigt alle 3 Tages-Phasen als scrollbaren Fluss:
/// Morning (Intention) → Daytime (Status + erledigte Tasks) → Evening (Reflexion + Stats)
struct CoachView: View {
    @AppStorage("morningEndHour") private var morningEndHour = 12
    @AppStorage("eveningStartHour") private var eveningStartHour = 18
    @Environment(\.eventKitRepository) private var eventKitRepo
    @Environment(\.modelContext) private var modelContext

    // Intention data
    @State private var todayIntention: DayIntention?
    @State private var yesterdayIntention: DayIntention?
    @State private var intentionSuggestions: [String] = []

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
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        morningSection
                            .id("morning")
                        daytimeSection
                            .id("daytime")
                        eveningSection
                            .id("evening")
                    }
                    .padding()
                }
                .onAppear {
                    scrollToCurrentPhase(proxy: proxy)
                }
            }
            .navigationTitle("Coach")
            #if os(iOS)
            .withSettingsToolbar()
            #endif
        }
        .accessibilityIdentifier("coachView")
        .task(id: refreshID) {
            await loadAllData()
        }
        .onAppear {
            refreshID = UUID()
        }
    }

    // MARK: - Morning Section

    private var morningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Guten Morgen",
                icon: "sunrise.fill",
                color: .orange,
                isActive: currentPhase == .morning
            )

            if isLoading {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Gestern-Echo
                    if let yesterday = yesterdayIntention {
                        Text("Gestern: \(yesterday.text)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("yesterdayIntentionEcho")
                    }

                    if let intention = todayIntention {
                        // Intention already set — show it + task suggestions
                        intentionSetView(intention)
                    } else {
                        // No intention yet — show question + chips
                        intentionPickerView
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentPhase == .morning ? .orange.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachMorningSection")
    }

    // MARK: - Intention Picker (no intention set yet)

    private var intentionPickerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Was soll heute zählen?")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("coachMorningQuestion")

            if intentionSuggestions.isEmpty {
                ProgressView("Vorschläge werden generiert...")
                    .font(.subheadline)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(intentionSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        Button {
                            selectIntention(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("intentionChip_\(index)")
                    }
                }
            }
        }
    }

    // MARK: - Intention Set View (intention already chosen)

    private func intentionSetView(_ intention: DayIntention) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heute:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(intention.text)
                    .font(.title3.weight(.semibold))
            }
            .accessibilityIdentifier("todayIntentionText")

            // Show existing task suggestions + free slots below
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
                    limitationWarning: nil,
                    onDismissWarning: {}
                )
            }

            if !freeSlots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Freie Lücken")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
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

            if !nextUpTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heute geplant")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
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
        }
    }

    // MARK: - Intention Actions

    private func selectIntention(_ text: String) {
        let intention = DayIntention(date: Date(), text: text)
        modelContext.insert(intention)
        try? modelContext.save()
        #if os(macOS)
        NotificationCenter.default.post(name: .taskDataChanged, object: nil)
        #endif
        todayIntention = intention
    }

    // MARK: - Daytime Section

    private var daytimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Dein Tag",
                icon: "sun.max.fill",
                color: .blue,
                isActive: currentPhase == .daytime
            )

            if isLoading {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Intention prominent (the heart of daytime)
                    if let intention = todayIntention {
                        Text(intention.text)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            .accessibilityIdentifier("daytimeIntentionText")
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Setze oben deine Intention für heute")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    }

                    // Compact completion count (no task list)
                    if !completedTasks.isEmpty {
                        Label("\(completedTasks.count) Dinge geschafft", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("coachCompletedTasks")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentPhase == .daytime ? .blue.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachDaytimeSection")
    }

    // MARK: - Evening Section

    private var eveningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Tagesrückblick",
                icon: "moon.stars.fill",
                color: .purple,
                isActive: currentPhase == .evening
            )

            if isLoading {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Intention echo (from morning)
                    if let intention = todayIntention {
                        Text("Dein Vorsatz: \(intention.text)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("eveningIntentionEcho")
                    }

                    // Reflection text (AI or fallback)
                    Text(eveningReflectionText)
                        .font(.body)
                        .accessibilityIdentifier("eveningReflectionText")

                    // Collapsed Details
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentPhase == .evening ? .purple.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coachEveningSection")
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color, isActive: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
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
        }
    }

    private var nextUpcomingBlock: FocusBlock? {
        let now = Date()
        return todayBlocks
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private func scrollToCurrentPhase(proxy: ScrollViewProxy) {
        let target: String
        switch currentPhase {
        case .morning: target = "morning"
        case .daytime: target = "daytime"
        case .evening: target = "evening"
        }
        withAnimation(.smooth) {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Intention laden
        do {
            let todayPredicate = #Predicate<DayIntention> { $0.date == today }
            var todayDescriptor = FetchDescriptor(predicate: todayPredicate)
            todayDescriptor.fetchLimit = 1
            todayIntention = try modelContext.fetch(todayDescriptor).first

            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let yesterdayPredicate = #Predicate<DayIntention> { $0.date == yesterday }
            var yesterdayDescriptor = FetchDescriptor(predicate: yesterdayPredicate)
            yesterdayDescriptor.fetchLimit = 1
            yesterdayIntention = try modelContext.fetch(yesterdayDescriptor).first
        } catch {
            // Intention-Daten nicht verfügbar
        }

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

        // Intention-Vorschläge generieren (wenn noch keine Intention gesetzt)
        if todayIntention == nil {
            let topTasks = allTasks
                .filter { !$0.isCompleted && $0.isActionable }
                .sorted { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
            let totalFreeMinutes = freeSlots.reduce(0) { $0 + $1.durationMinutes }
            let meetingCount = calendarEvents.filter { !$0.isAllDay && !$0.isFocusBlock }.count

            intentionSuggestions = await IntentionSuggestionService.suggestions(
                topTasks: Array(topTasks.prefix(5)),
                freeMinutes: totalFreeMinutes,
                meetingCount: meetingCount,
                yesterdayIntention: yesterdayIntention?.text
            )
        }

        // Evening reflection generieren
        eveningReflectionText = await SuccessStoryService.generate(
            completedTasks: completedTasks,
            focusBlocks: focusBlocks,
            intention: todayIntention?.text
        )
    }
}
