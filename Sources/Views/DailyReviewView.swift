import SwiftUI
import SwiftData

/// Daily Review View (Sprint 5)
/// Shows all completed tasks for the current day, grouped by Focus Blocks.
struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var blocks: [FocusBlock] = []
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = true

    // MARK: - Computed Properties

    private var todayBlocks: [FocusBlock] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return blocks.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    private var totalCompleted: Int {
        todayBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
    }

    private var totalPlanned: Int {
        todayBlocks.reduce(0) { $0 + $1.taskIDs.count }
    }

    private var completionPercentage: Int {
        guard totalPlanned > 0 else { return 0 }
        return Int((Double(totalCompleted) / Double(totalPlanned)) * 100)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if todayBlocks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        dailyStatsHeader
                        blocksSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Rückblick")
            .withSettingsToolbar()
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Heute noch keine Focus Blocks")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Plane einen Focus Block im Blöcke-Tab")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 100)
    }

    // MARK: - Daily Stats Header

    private var dailyStatsHeader: some View {
        VStack(spacing: 16) {
            // Date header
            Text(todayDateString)
                .font(.title2.weight(.semibold))

            // Completion ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: completionPercentage)

                VStack(spacing: 4) {
                    Text("\(completionPercentage)%")
                        .font(.title.weight(.bold))
                    Text("geschafft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            // Stats row
            HStack(spacing: 32) {
                StatItem(
                    value: "\(totalCompleted)",
                    label: "Erledigt",
                    color: .green
                )

                StatItem(
                    value: "\(totalPlanned - totalCompleted)",
                    label: "Offen",
                    color: totalPlanned == totalCompleted ? .secondary : .orange
                )

                StatItem(
                    value: "\(todayBlocks.count)",
                    label: "Blocks",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Blocks Section

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(todayBlocks.sorted { $0.startDate < $1.startDate }) { block in
                blockCard(for: block)
            }
        }
    }

    private func blockCard(for block: FocusBlock) -> some View {
        let tasksForBlock = allTasks.filter { block.taskIDs.contains($0.id) }
        let completedTasks = tasksForBlock.filter { block.completedTaskIDs.contains($0.id) }
        let blockPercentage = tasksForBlock.isEmpty ? 0 : Int((Double(completedTasks.count) / Double(tasksForBlock.count)) * 100)

        return VStack(alignment: .leading, spacing: 12) {
            // Block header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.headline)

                    Text(timeRangeText(for: block))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(blockPercentage)%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(blockPercentage == 100 ? .green : .blue)
            }

            // Completed tasks
            if completedTasks.isEmpty {
                Text("Keine Tasks erledigt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(completedTasks) { task in
                        ReviewTaskRow(task: task, isCompleted: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "'Heute,' d. MMMM"
        return formatter.string(from: Date())
    }

    private func timeRangeText(for block: FocusBlock) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    private func loadData() async {
        isLoading = true

        do {
            // Load focus blocks for today
            blocks = try eventKitRepo.fetchFocusBlocks(for: Date())

            // Load all tasks via SyncEngine
            let taskSource = LocalTaskSource(modelContext: modelContext)
            let syncEngine = SyncEngine(taskSource: taskSource, modelContext: modelContext)
            allTasks = try await syncEngine.sync()
        } catch {
            // Silently fail - UI will show empty state
            blocks = []
            allTasks = []
        }

        isLoading = false
    }
}
