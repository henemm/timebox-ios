import SwiftUI
import SwiftData

/// Coach-specific "Mein Tag" view (Phase 5b).
/// Replaces DailyReviewView when coach mode is enabled.
/// Shows MorningIntentionView, day progress, and EveningReflectionCard.
struct CoachMeinTagView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var allLocalTasks: [LocalTask] = []
    @State private var todayBlocks: [FocusBlock] = []
    @State private var aiReflectionTexts: [IntentionOption: String] = [:]
    @State private var eventKitRepo = EventKitRepository()
    /// Observes when MorningIntentionView saves an intention — triggers body re-render
    /// so that EveningReflectionCard condition is re-evaluated.
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    /// Show evening reflection card after 18:00 or when forced via launch arg.
    private var showEveningReflection: Bool {
        if ProcessInfo.processInfo.arguments.contains("-ForceEveningReflection") {
            return true
        }
        return Calendar.current.component(.hour, from: Date()) >= 18
    }

    /// Tasks completed today matching the current intention.
    private var todayCompletedCount: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return allLocalTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startOfToday
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MorningIntentionView()
                        .padding(.horizontal)

                    dayProgressSection
                        .padding(.horizontal)

                    if showEveningReflection && DailyIntention.load().isSet {
                        EveningReflectionCard(
                            intentions: DailyIntention.load().selections,
                            tasks: allLocalTasks,
                            focusBlocks: todayBlocks,
                            aiTexts: aiReflectionTexts
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Mein Tag")
            .withSettingsToolbar()
        }
        .task {
            await loadData()
            await loadAIReflectionTexts()
        }
        .onChange(of: intentionJustSet) {
            if intentionJustSet {
                Task { await loadAIReflectionTexts() }
            }
        }
    }

    // MARK: - Day Progress

    private var dayProgressSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(todayCompletedCount) Tasks erledigt")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .accessibilityIdentifier("coachDayProgress")
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            let descriptor = FetchDescriptor<LocalTask>()
            allLocalTasks = try modelContext.fetch(descriptor)
        } catch {
            allLocalTasks = []
        }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            todayBlocks = try eventKitRepo.fetchFocusBlocks(for: today)
        } catch {
            todayBlocks = []
        }
    }

    private func loadAIReflectionTexts() async {
        guard showEveningReflection else { return }
        let intention = DailyIntention.load()
        guard intention.isSet else { return }

        if ProcessInfo.processInfo.arguments.contains("-AIDisabled") {
            AppSettings.shared.aiScoringEnabled = false
        }

        let service = EveningReflectionTextService()
        aiReflectionTexts = await service.generateTexts(
            intentions: intention.selections,
            tasks: allLocalTasks,
            focusBlocks: todayBlocks
        )
    }
}
