import SwiftUI
import SwiftData

/// Coach-specific Review view for macOS (Phase 6c).
/// Replaces MacReviewView when coach mode is enabled.
/// Shows MorningIntentionView and day progress.
struct MacCoachReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var allLocalTasks: [LocalTask] = []

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
            }
            .padding(.top, 8)
        }
        .navigationTitle("Mein Tag")
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadData()
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
    }
}
