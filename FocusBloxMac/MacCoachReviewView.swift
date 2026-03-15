import SwiftUI
import SwiftData

/// Coach-specific Review view for macOS (Phase 6c + 6d).
/// Replaces MacReviewView when coach mode is enabled.
/// Shows MorningIntentionView, day progress, and evening reflection.
struct MacCoachReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.eventKitRepository) private var eventKitRepo
    @State private var allLocalTasks: [LocalTask] = []
    @State private var todayBlocks: [FocusBlock] = []

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
                        focusBlocks: todayBlocks
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Mein Tag")
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadData()
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

}
