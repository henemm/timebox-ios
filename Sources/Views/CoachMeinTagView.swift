import SwiftUI
import SwiftData

/// Coach-specific "Mein Tag" view (shared iOS + macOS).
/// Replaces DailyReviewView when coach mode is enabled.
/// Shows coach selection, day progress, and evening reflection.
struct CoachMeinTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var allLocalTasks: [LocalTask] = []
    @State private var todayBlocks: [FocusBlock] = []
    @State private var weekBlocks: [FocusBlock] = []
    @State private var aiReflectionText: String?
    @State private var weeklyAIReflectionText: String?
    @State private var reviewMode: ReviewMode = .today
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    private enum ReviewMode: String, CaseIterable {
        case today = "Heute"
        case week = "Diese Woche"
    }

    /// Show evening reflection card after 18:00 or when forced via launch arg.
    private var showEveningReflection: Bool {
        if ProcessInfo.processInfo.arguments.contains("-ForceEveningReflection") {
            return true
        }
        return Calendar.current.component(.hour, from: Date()) >= 18
    }

    /// All tasks as PlanItems for coach mission logic.
    private var planItems: [PlanItem] {
        allLocalTasks.map { PlanItem(localTask: $0) }
    }

    /// Tasks completed this week.
    private var weekCompletedCount: Int {
        IntentionEvaluationService.completedThisWeek(allLocalTasks).count
    }

    var body: some View {
        #if os(macOS)
        content
            .frame(minWidth: 600, minHeight: 400)
        #else
        NavigationStack {
            content
                .withSettingsToolbar()
        }
        #endif
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                MorningIntentionView(allTasks: planItems)
                    .padding(.horizontal)

                if let coach = DailyCoachSelection.load().coach {
                    CoachMissionCard(
                        coach: coach,
                        mission: CoachMissionService.generateMission(coach: coach, allTasks: planItems)
                    )
                    .padding(.horizontal)
                }

                Picker("Zeitraum", selection: $reviewMode) {
                    ForEach(ReviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch reviewMode {
                case .today:
                    if showEveningReflection, let coach = DailyCoachSelection.load().coach {
                        EveningReflectionCard(
                            coach: coach,
                            tasks: allLocalTasks,
                            focusBlocks: todayBlocks,
                            aiText: aiReflectionText
                        )
                        .padding(.horizontal)
                    }

                case .week:
                    weekProgressSection
                        .padding(.horizontal)

                    if let coach = DailyCoachSelection.load().coach {
                        weeklyReflectionSection(coach: coach)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Mein Tag")
        .task {
            await loadData()
            await loadAIReflectionText()
        }
        .onChange(of: intentionJustSet) {
            if intentionJustSet {
                Task { await loadAIReflectionText() }
            }
        }
        .onChange(of: reviewMode) {
            if reviewMode == .week {
                Task { await loadWeeklyAIReflectionText() }
            }
        }
    }

    // MARK: - Week Progress

    private var weekProgressSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(weekCompletedCount) Tasks diese Woche erledigt")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Weekly Reflection

    private func weeklyReflectionSection(coach: CoachType) -> some View {
        let level = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: coach, tasks: allLocalTasks, focusBlocks: weekBlocks
        )
        let text = weeklyAIReflectionText
            ?? IntentionEvaluationService.weeklyFallbackTemplate(coach: coach, level: level)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Wochen-Rückblick")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(coach.monsterImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    Text("\(coach.displayName) — \(coach.subtitle)")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    weeklyFulfillmentBadge(coach: coach, level: level)
                }

                if !text.isEmpty {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(weeklyBackgroundColor(for: coach, level: level))
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private func weeklyFulfillmentBadge(coach: CoachType, level: FulfillmentLevel) -> some View {
        let (icon, color): (String, Color) = switch level {
        case .fulfilled:    ("checkmark.circle.fill", coach.color)
        case .partial:      ("exclamationmark.circle.fill", coach.color.opacity(0.6))
        case .notFulfilled: ("xmark.circle", .secondary)
        }
        return Image(systemName: icon)
            .foregroundStyle(color)
            .font(.title3)
    }

    private func weeklyBackgroundColor(for coach: CoachType, level: FulfillmentLevel) -> Color {
        switch level {
        case .fulfilled:    return coach.color.opacity(0.15)
        case .partial:      return coach.color.opacity(0.08)
        case .notFulfilled: return Color.secondary.opacity(0.08)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            let descriptor = FetchDescriptor<LocalTask>()
            allLocalTasks = try modelContext.fetch(descriptor)
        } catch {
            allLocalTasks = []
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        do {
            todayBlocks = try eventKitRepo.fetchFocusBlocks(for: today)
        } catch {
            todayBlocks = []
        }

        // Load week blocks for weekly view
        do {
            var allWeekBlocks: [FocusBlock] = []
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                var currentDate = weekInterval.start
                while currentDate < weekInterval.end {
                    let dayBlocks = try eventKitRepo.fetchFocusBlocks(for: currentDate)
                    allWeekBlocks.append(contentsOf: dayBlocks)
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? weekInterval.end
                }
            }
            weekBlocks = allWeekBlocks
        } catch {
            weekBlocks = []
        }
    }

    private func loadAIReflectionText() async {
        guard showEveningReflection else { return }
        let selection = DailyCoachSelection.load()
        guard let coach = selection.coach else { return }

        if ProcessInfo.processInfo.arguments.contains("-AIDisabled") {
            AppSettings.shared.aiScoringEnabled = false
        }

        let service = EveningReflectionTextService()
        aiReflectionText = await service.generateTextForCoach(
            coach: coach,
            tasks: allLocalTasks,
            focusBlocks: todayBlocks
        )
    }

    private func loadWeeklyAIReflectionText() async {
        let selection = DailyCoachSelection.load()
        guard let coach = selection.coach else { return }

        if ProcessInfo.processInfo.arguments.contains("-AIDisabled") {
            AppSettings.shared.aiScoringEnabled = false
        }

        let service = EveningReflectionTextService()
        weeklyAIReflectionText = await service.generateWeeklyTextForCoach(
            coach: coach,
            tasks: allLocalTasks,
            focusBlocks: weekBlocks
        )
    }
}
