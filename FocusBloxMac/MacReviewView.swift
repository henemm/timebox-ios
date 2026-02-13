//
//  MacReviewView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData

/// Review Dashboard with daily and weekly statistics
struct MacReviewView: View {
    @Query(filter: #Predicate<LocalTask> { $0.isCompleted })
    private var completedTasks: [LocalTask]

    @Query private var allLocalTasks: [LocalTask]

    @State private var selectedView: ReviewScope = .today
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var blocks: [FocusBlock] = []
    @Environment(\.eventKitRepository) private var eventKitRepo
    private let statsCalculator = ReviewStatsCalculator()

    enum ReviewScope: String, CaseIterable {
        case today = "Heute"
        case week = "Diese Woche"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Zeitraum", selection: $selectedView) {
                ForEach(ReviewScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .frame(maxWidth: 300)

            Divider()

            // Content based on selection
            switch selectedView {
            case .today:
                DayReviewContent(
                    completedTasks: todayTasks,
                    blocks: todayBlocks,
                    calendarEvents: todayCalendarEvents,
                    allTasks: allPlanItems,
                    statsCalculator: statsCalculator
                )
            case .week:
                WeekReviewContent(
                    completedTasks: weekTasks,
                    blocks: weekBlocks,
                    calendarEvents: calendarEvents,
                    allTasks: allPlanItems,
                    statsCalculator: statsCalculator
                )
            }
        }
        .navigationTitle("Review")
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadData()
        }
    }

    // MARK: - Filtered Tasks

    private var todayTasks: [LocalTask] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfToday
        }
    }

    private var weekTasks: [LocalTask] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfWeek
        }
    }

    // MARK: - Filtered Blocks

    private var todayBlocks: [FocusBlock] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return blocks.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    private var weekBlocks: [FocusBlock] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return blocks.filter { block in
            block.startDate >= weekInterval.start && block.startDate < weekInterval.end
        }
    }

    /// All tasks as PlanItems (for planning accuracy)
    private var allPlanItems: [PlanItem] {
        allLocalTasks.map { PlanItem(localTask: $0) }
    }

    /// Calendar events filtered to today
    private var todayCalendarEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        return calendarEvents.filter {
            $0.startDate >= startOfToday && $0.startDate < endOfToday
        }
    }

    // MARK: - Load Data

    private func loadData() async {
        do {
            var allEvents: [CalendarEvent] = []
            var allBlocks: [FocusBlock] = []
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                var currentDate = weekInterval.start
                while currentDate < weekInterval.end {
                    let dayEvents = try eventKitRepo.fetchCalendarEvents(for: currentDate)
                    allEvents.append(contentsOf: dayEvents)
                    let dayBlocks = try eventKitRepo.fetchFocusBlocks(for: currentDate)
                    allBlocks.append(contentsOf: dayBlocks)
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? weekInterval.end
                }
            }
            calendarEvents = allEvents
            blocks = allBlocks
        } catch {
            calendarEvents = []
            blocks = []
        }
    }
}

// MARK: - Day Review Content

struct DayReviewContent: View {
    let completedTasks: [LocalTask]
    var blocks: [FocusBlock] = []
    var calendarEvents: [CalendarEvent] = []
    var allTasks: [PlanItem] = []
    var statsCalculator: ReviewStatsCalculator = ReviewStatsCalculator()

    private var totalCompleted: Int {
        blocks.reduce(0) { $0 + $1.completedTaskIDs.count }
    }

    private var totalPlanned: Int {
        blocks.reduce(0) { $0 + $1.taskIDs.count }
    }

    private var completionPercentage: Int {
        guard totalPlanned > 0 else { return 0 }
        return Int((Double(totalCompleted) / Double(totalPlanned)) * 100)
    }

    private var dayCategoryStats: [MacCategoryStat] {
        let grouped = Dictionary(grouping: completedTasks) { $0.taskType }
        var taskMinutes: [String: Int] = [:]
        for (category, tasks) in grouped {
            taskMinutes[category] = tasks.compactMap(\.estimatedDuration).reduce(0, +)
        }

        let combined = statsCalculator.computeCategoryMinutes(
            taskMinutesByCategory: taskMinutes,
            calendarEvents: calendarEvents
        )

        return combined.compactMap { (category, minutes) in
            guard minutes > 0 else { return nil }
            return MacCategoryStat(category: category, minutes: minutes)
        }.sorted { $0.minutes > $1.minutes }
    }

    private var dayTotalMinutes: Int {
        dayCategoryStats.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        if blocks.isEmpty && completedTasks.isEmpty && calendarEvents.isEmpty {
            ContentUnavailableView(
                "Noch keine Focus Blocks heute",
                systemImage: "clock.arrow.circlepath",
                description: Text("Plane einen Focus Block im Planen-Tab.")
            )
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Completion Ring + Stats
                    reviewStatsHeader

                    Divider()

                    // Category Time Breakdown
                    if !dayCategoryStats.isEmpty {
                        categorySection
                        Divider()
                    }

                    // Planning Accuracy
                    planningAccuracySection(blocks: blocks)

                    // Focus Block Cards
                    if !blocks.isEmpty {
                        blocksSection
                    }
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Planning Accuracy Section

    @ViewBuilder
    private func planningAccuracySection(blocks: [FocusBlock]) -> some View {
        let stats = statsCalculator.computePlanningAccuracy(blocks: blocks, allTasks: allTasks)

        if stats.hasData {
            VStack(alignment: .leading, spacing: 12) {
                Text("Planungsgenauigkeit")
                    .font(.headline)
                    .padding(.horizontal)

                if stats.trackedTaskCount > 0 {
                    HStack {
                        Image(systemName: stats.averageDeviation < -0.05 ? "hare" : stats.averageDeviation > 0.05 ? "tortoise" : "checkmark.seal")
                            .foregroundStyle(stats.averageDeviation < -0.05 ? .green : stats.averageDeviation > 0.05 ? .orange : .blue)
                        Text("Durchschnitt: \(stats.averageDeviationFormatted)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(stats.trackedTaskCount) Tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 0) {
                        macAccuracyPill(count: stats.fasterCount, label: "Schneller", color: .green, icon: "arrow.up.circle.fill")
                        macAccuracyPill(count: stats.onTimeCount, label: "Im Plan", color: .blue, icon: "checkmark.circle.fill")
                        macAccuracyPill(count: stats.slowerCount, label: "Langsamer", color: .orange, icon: "arrow.down.circle.fill")
                    }
                    .padding(.horizontal)
                }

                if stats.rescheduledTaskCount > 0 {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.purple)
                        Text("\(stats.rescheduledTaskCount) Tasks umgeplant")
                            .font(.subheadline)
                        Spacer()
                        Text("\(stats.totalReschedules)x total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                Divider()
            }
        }
    }

    private func macAccuracyPill(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Header with Completion Ring

    private var reviewStatsHeader: some View {
        VStack(spacing: 16) {
            Text(todayDateString)
                .font(.title2.weight(.semibold))

            // Completion Ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
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
            .frame(width: 100, height: 100)

            // Stats Row
            HStack(spacing: 32) {
                MacStatItem(value: "\(totalCompleted)", label: "Erledigt", color: .green)
                MacStatItem(
                    value: "\(totalPlanned - totalCompleted)",
                    label: "Offen",
                    color: totalPlanned == totalCompleted ? .secondary : .orange
                )
                MacStatItem(value: "\(blocks.count)", label: "Blocks", color: .blue)
            }
        }
        .padding()
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zeit pro Kategorie")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(dayCategoryStats) { stat in
                    MacCategoryBar(stat: stat, totalMinutes: dayTotalMinutes)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Blocks Section

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Blocks")
                .font(.headline)
                .padding(.horizontal)

            ForEach(blocks.sorted { $0.startDate < $1.startDate }) { block in
                MacBlockCard(block: block, completedTasks: completedTasks)
            }
            .padding(.horizontal)
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "'Heute,' d. MMMM"
        return formatter.string(from: Date())
    }
}

// MARK: - Week Review Content

struct WeekReviewContent: View {
    let completedTasks: [LocalTask]
    var blocks: [FocusBlock] = []
    var calendarEvents: [CalendarEvent] = []
    var allTasks: [PlanItem] = []
    var statsCalculator: ReviewStatsCalculator = ReviewStatsCalculator()

    private var totalCompleted: Int {
        blocks.reduce(0) { $0 + $1.completedTaskIDs.count }
    }

    private var totalPlanned: Int {
        blocks.reduce(0) { $0 + $1.taskIDs.count }
    }

    private var completionPercentage: Int {
        guard totalPlanned > 0 else { return 0 }
        return Int((Double(totalCompleted) / Double(totalPlanned)) * 100)
    }

    private var weekCategoryStats: [MacCategoryStat] {
        let grouped = Dictionary(grouping: completedTasks) { $0.taskType }
        var taskMinutes: [String: Int] = [:]
        for (category, tasks) in grouped {
            taskMinutes[category] = tasks.compactMap(\.estimatedDuration).reduce(0, +)
        }

        let combined = statsCalculator.computeCategoryMinutes(
            taskMinutesByCategory: taskMinutes,
            calendarEvents: calendarEvents
        )

        return combined.compactMap { (category, minutes) in
            guard minutes > 0 else { return nil }
            return MacCategoryStat(category: category, minutes: minutes)
        }.sorted { $0.minutes > $1.minutes }
    }

    private var weekTotalMinutes: Int {
        weekCategoryStats.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        if blocks.isEmpty && completedTasks.isEmpty {
            ContentUnavailableView(
                "Noch keine Focus Blocks diese Woche",
                systemImage: "calendar.badge.clock",
                description: Text("Plane Focus Blocks im Planen-Tab.")
            )
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    // Completion Ring + Stats
                    weekStatsHeader

                    Divider()

                    // Category Time Breakdown
                    if !weekCategoryStats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zeit pro Kategorie")
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(weekCategoryStats) { stat in
                                    MacCategoryBar(stat: stat, totalMinutes: weekTotalMinutes)
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                    }

                    // Planning Accuracy
                    weekPlanningAccuracySection
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Week Planning Accuracy

    @ViewBuilder
    private var weekPlanningAccuracySection: some View {
        let stats = statsCalculator.computePlanningAccuracy(blocks: blocks, allTasks: allTasks)

        if stats.hasData {
            VStack(alignment: .leading, spacing: 12) {
                Text("Planungsgenauigkeit")
                    .font(.headline)
                    .padding(.horizontal)

                if stats.trackedTaskCount > 0 {
                    HStack {
                        Image(systemName: stats.averageDeviation < -0.05 ? "hare" : stats.averageDeviation > 0.05 ? "tortoise" : "checkmark.seal")
                            .foregroundStyle(stats.averageDeviation < -0.05 ? .green : stats.averageDeviation > 0.05 ? .orange : .blue)
                        Text("Durchschnitt: \(stats.averageDeviationFormatted)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(stats.trackedTaskCount) Tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 0) {
                        weekAccuracyPill(count: stats.fasterCount, label: "Schneller", color: .green, icon: "arrow.up.circle.fill")
                        weekAccuracyPill(count: stats.onTimeCount, label: "Im Plan", color: .blue, icon: "checkmark.circle.fill")
                        weekAccuracyPill(count: stats.slowerCount, label: "Langsamer", color: .orange, icon: "arrow.down.circle.fill")
                    }
                    .padding(.horizontal)
                }

                if stats.rescheduledTaskCount > 0 {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.purple)
                        Text("\(stats.rescheduledTaskCount) Tasks umgeplant")
                            .font(.subheadline)
                        Spacer()
                        Text("\(stats.totalReschedules)x total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func weekAccuracyPill(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week Stats Header

    private var weekStatsHeader: some View {
        VStack(spacing: 16) {
            Text(weekDateRangeString)
                .font(.title2.weight(.semibold))

            // Completion Ring
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? .green : .blue,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
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
            .frame(width: 100, height: 100)

            // Stats Row
            HStack(spacing: 32) {
                MacStatItem(value: "\(totalCompleted)", label: "Erledigt", color: .green)
                MacStatItem(
                    value: "\(totalPlanned - totalCompleted)",
                    label: "Offen",
                    color: totalPlanned == totalCompleted ? .secondary : .orange
                )
                MacStatItem(value: "\(blocks.count)", label: "Blocks", color: .blue)
            }
        }
        .padding()
    }

    private var weekDateRangeString: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return "Diese Woche"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d."
        let startDay = formatter.string(from: weekInterval.start)
        let endDate = weekInterval.end.addingTimeInterval(-1)
        formatter.dateFormat = "d. MMM"
        let endDayMonth = formatter.string(from: endDate)
        return "\(startDay) - \(endDayMonth)"
    }
}

// MARK: - Supporting Views

// MARK: - Block Card

struct MacBlockCard: View {
    let block: FocusBlock
    let completedTasks: [LocalTask]

    private var tasksForBlock: [LocalTask] {
        completedTasks.filter { block.taskIDs.contains($0.id) }
    }

    private var completedCount: Int {
        block.completedTaskIDs.count
    }

    private var totalCount: Int {
        block.taskIDs.count
    }

    private var blockPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(completedCount) / Double(totalCount)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Block header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.headline)
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(blockPercentage)%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(blockPercentage == 100 ? .green : .blue)
            }

            // Completed tasks in this block
            if tasksForBlock.isEmpty {
                Text("Keine Tasks erledigt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(tasksForBlock, id: \.uuid) { task in
                        HStack(spacing: 8) {
                            Image(systemName: block.completedTaskIDs.contains(task.id)
                                ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(block.completedTaskIDs.contains(task.id) ? .green : .secondary)
                                .font(.subheadline)

                            Text(task.title)
                                .font(.subheadline)
                                .strikethrough(block.completedTaskIDs.contains(task.id), color: .secondary)

                            Spacer()

                            if let category = TaskCategory(rawValue: task.taskType) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                            }

                            if let duration = task.estimatedDuration {
                                Text("\(duration) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }
}

// MARK: - Time-based Category Stat (for daily/weekly time breakdown)

struct MacCategoryStat: Identifiable {
    let id = UUID()
    let category: String
    let minutes: Int

    var label: String {
        TaskCategory(rawValue: category)?.displayName ?? category
    }

    var color: Color {
        TaskCategory(rawValue: category)?.color ?? .gray
    }

    var icon: String {
        TaskCategory(rawValue: category)?.icon ?? "questionmark.circle"
    }

    var formattedTime: String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Category Time Bar

struct MacCategoryBar: View {
    let stat: MacCategoryStat
    let totalMinutes: Int

    private var percentage: CGFloat {
        guard totalMinutes > 0 else { return 0 }
        return CGFloat(stat.minutes) / CGFloat(totalMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: stat.icon)
                    .foregroundStyle(stat.color)
                Text(stat.label)
                    .font(.subheadline)
                Spacer()
                Text(stat.formattedTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stat.color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(stat.color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    MacReviewView()
        .frame(width: 700, height: 500)
}
