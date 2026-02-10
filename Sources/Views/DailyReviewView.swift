import SwiftUI
import SwiftData

/// Review mode for segmented picker
enum ReviewMode: String, CaseIterable {
    case today = "Heute"
    case week = "Diese Woche"
}

/// Category configuration - delegates to central TaskCategory
typealias CategoryConfig = TaskCategory

/// Category stat for weekly view
struct CategoryStat: Identifiable {
    let id = UUID()
    let config: CategoryConfig
    let minutes: Int
}

/// Daily Review View (Sprint 5 + 6)
/// Shows completed tasks for today or the current week, grouped by Focus Blocks.
struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var eventKitRepo = EventKitRepository()
    @State private var blocks: [FocusBlock] = []
    @State private var allTasks: [PlanItem] = []
    @State private var isLoading = true
    @State private var reviewMode: ReviewMode = .today

    // MARK: - Computed Properties

    private var todayBlocks: [FocusBlock] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return blocks.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    /// Blocks for the current week (Monday to Sunday)
    private var weekBlocks: [FocusBlock] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return blocks.filter { block in
            block.startDate >= weekInterval.start && block.startDate < weekInterval.end
        }
    }

    /// Category statistics for weekly view
    private var categoryStats: [CategoryStat] {
        var stats: [String: Int] = [:]

        // Get all completed task IDs from week blocks
        let completedIDs = Set(weekBlocks.flatMap { $0.completedTaskIDs })

        // Calculate total minutes per category
        for task in allTasks where completedIDs.contains(task.id) {
            let category = task.taskType
            stats[category, default: 0] += task.effectiveDuration
        }

        // Convert to CategoryStat array sorted by minutes
        return CategoryConfig.allCases.compactMap { config in
            guard let minutes = stats[config.rawValue], minutes > 0 else { return nil }
            return CategoryStat(config: config, minutes: minutes)
        }.sorted { $0.minutes > $1.minutes }
    }

    /// Total minutes for weekly stats (for percentage calculation)
    private var weekTotalMinutes: Int {
        categoryStats.reduce(0) { $0 + $1.minutes }
    }

    /// Weekly completion stats
    private var weeklyTotalCompleted: Int {
        weekBlocks.reduce(0) { $0 + $1.completedTaskIDs.count }
    }

    private var weeklyTotalPlanned: Int {
        weekBlocks.reduce(0) { $0 + $1.taskIDs.count }
    }

    private var weeklyCompletionPercentage: Int {
        guard weeklyTotalPlanned > 0 else { return 0 }
        return Int((Double(weeklyTotalCompleted) / Double(weeklyTotalPlanned)) * 100)
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
                VStack(spacing: 16) {
                    // Segmented picker for today/week
                    Picker("Zeitraum", selection: $reviewMode) {
                        ForEach(ReviewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else {
                        switch reviewMode {
                        case .today:
                            if todayBlocks.isEmpty {
                                emptyState
                            } else {
                                VStack(spacing: 24) {
                                    dailyStatsHeader
                                    blocksSection
                                }
                                .padding(.horizontal)
                            }
                        case .week:
                            if weekBlocks.isEmpty {
                                weeklyEmptyState
                            } else {
                                VStack(spacing: 24) {
                                    weeklyStatsHeader
                                    categoryStatsSection
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
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

    // MARK: - Weekly Empty State

    private var weeklyEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Diese Woche noch keine Focus Blocks")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Plane Focus Blocks im Blöcke-Tab")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 100)
    }

    // MARK: - Weekly Stats Header

    private var weeklyStatsHeader: some View {
        VStack(spacing: 16) {
            // Week date header
            Text(weekDateRangeString)
                .font(.title2.weight(.semibold))

            // Completion ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: CGFloat(weeklyCompletionPercentage) / 100)
                    .stroke(
                        weeklyCompletionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: weeklyCompletionPercentage)

                VStack(spacing: 4) {
                    Text("\(weeklyCompletionPercentage)%")
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
                    value: "\(weeklyTotalCompleted)",
                    label: "Erledigt",
                    color: .green
                )

                StatItem(
                    value: "\(weeklyTotalPlanned - weeklyTotalCompleted)",
                    label: "Offen",
                    color: weeklyTotalPlanned == weeklyTotalCompleted ? .secondary : .orange
                )

                StatItem(
                    value: "\(weekBlocks.count)",
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

    // MARK: - Category Stats Section

    private var categoryStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zeit pro Kategorie")
                .font(.headline)

            if categoryStats.isEmpty {
                Text("Keine Daten vorhanden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryStats) { stat in
                        CategoryBar(stat: stat, totalMinutes: weekTotalMinutes)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    /// Week date range string (e.g., "20. - 26. Jan")
    private var weekDateRangeString: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return "Diese Woche"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")

        // Format start date
        formatter.dateFormat = "d."
        let startDay = formatter.string(from: weekInterval.start)

        // Format end date (subtract 1 second to get last day)
        let endDate = weekInterval.end.addingTimeInterval(-1)
        formatter.dateFormat = "d. MMM"
        let endDayMonth = formatter.string(from: endDate)

        return "\(startDay) - \(endDayMonth)"
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
            // Load focus blocks for the week (to support both today and week views)
            var allBlocks: [FocusBlock] = []
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                // Load blocks for each day of the week
                var currentDate = weekInterval.start
                while currentDate < weekInterval.end {
                    let dayBlocks = try eventKitRepo.fetchFocusBlocks(for: currentDate)
                    allBlocks.append(contentsOf: dayBlocks)
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? weekInterval.end
                }
            }
            blocks = allBlocks

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

// MARK: - Category Bar Component

struct CategoryBar: View {
    let stat: CategoryStat
    let totalMinutes: Int

    private var percentage: CGFloat {
        guard totalMinutes > 0 else { return 0 }
        return CGFloat(stat.minutes) / CGFloat(totalMinutes)
    }

    private var formattedTime: String {
        let hours = stat.minutes / 60
        let mins = stat.minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label row
            HStack {
                Image(systemName: stat.config.icon)
                    .foregroundStyle(stat.config.color)
                Text(stat.config.displayName)
                    .font(.subheadline)
                Spacer()
                Text(formattedTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stat.config.color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(stat.config.color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
}
