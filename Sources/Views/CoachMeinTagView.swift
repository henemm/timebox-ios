import SwiftUI
import SwiftData

/// Coach-specific "Mein Tag" view.
/// Replaces DailyReviewView when coach mode is enabled.
/// Shows coach selection, day progress, and evening reflection.
struct CoachMeinTagView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var allLocalTasks: [LocalTask] = []
    @State private var todayBlocks: [FocusBlock] = []
    @State private var aiReflectionText: String?
    @State private var eventKitRepo = EventKitRepository()
    @AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

    /// Show evening reflection card after 18:00 or when forced via launch arg.
    private var showEveningReflection: Bool {
        if ProcessInfo.processInfo.arguments.contains("-ForceEveningReflection") {
            return true
        }
        return Calendar.current.component(.hour, from: Date()) >= 18
    }

    /// Tasks completed today.
    private var todayCompletedCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
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

                    if showEveningReflection, let coach = DailyCoachSelection.load().coach {
                        EveningReflectionCard(
                            coach: coach,
                            tasks: allLocalTasks,
                            focusBlocks: todayBlocks,
                            aiText: aiReflectionText
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
            await loadAIReflectionText()
        }
        .onChange(of: intentionJustSet) {
            if intentionJustSet {
                Task { await loadAIReflectionText() }
            }
        }
    }

    // MARK: - Day Progress (shared component)

    private var dayProgressSection: some View {
        DayProgressSection(completedCount: todayCompletedCount)
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
            let today = Calendar.current.startOfDay(for: Date())
            todayBlocks = try eventKitRepo.fetchFocusBlocks(for: today)
        } catch {
            todayBlocks = []
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
}
