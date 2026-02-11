//
//  MacReviewView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI
import SwiftData
import Charts

/// Review Dashboard with daily and weekly statistics
struct MacReviewView: View {
    @Query(filter: #Predicate<LocalTask> { $0.isCompleted })
    private var completedTasks: [LocalTask]

    @State private var selectedView: ReviewScope = .today
    @State private var calendarEvents: [CalendarEvent] = []
    private let eventKitRepo = EventKitRepository()
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
                DayReviewContent(completedTasks: todayTasks)
            case .week:
                WeekReviewContent(
                    completedTasks: weekTasks,
                    calendarEvents: calendarEvents,
                    statsCalculator: statsCalculator
                )
            }
        }
        .navigationTitle("Review")
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadCalendarEvents()
        }
    }

    // MARK: - Filtered Tasks

    private var todayTasks: [LocalTask] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return completedTasks.filter { task in
            task.createdAt >= startOfToday
        }
    }

    private var weekTasks: [LocalTask] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }
        return completedTasks.filter { task in
            task.createdAt >= startOfWeek
        }
    }

    // MARK: - Calendar Events

    private func loadCalendarEvents() async {
        do {
            var allEvents: [CalendarEvent] = []
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                var currentDate = weekInterval.start
                while currentDate < weekInterval.end {
                    let dayEvents = try eventKitRepo.fetchCalendarEvents(for: currentDate)
                    allEvents.append(contentsOf: dayEvents)
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? weekInterval.end
                }
            }
            calendarEvents = allEvents
        } catch {
            calendarEvents = []
        }
    }
}

// MARK: - Day Review Content

struct DayReviewContent: View {
    let completedTasks: [LocalTask]

    private var totalFocusMinutes: Int {
        completedTasks.compactMap(\.estimatedDuration).reduce(0, +)
    }

    var body: some View {
        if completedTasks.isEmpty {
            ContentUnavailableView(
                "Noch keine Tasks erledigt",
                systemImage: "checkmark.circle",
                description: Text("Erledigte Tasks werden hier angezeigt.")
            )
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Row
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Erledigt",
                            value: "\(completedTasks.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        StatCard(
                            title: "Fokuszeit",
                            value: formatDuration(totalFocusMinutes),
                            icon: "clock.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Task List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Erledigte Tasks")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(completedTasks, id: \.uuid) { task in
                            CompletedTaskRow(task: task)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Week Review Content

struct WeekReviewContent: View {
    let completedTasks: [LocalTask]
    var calendarEvents: [CalendarEvent] = []
    var statsCalculator: ReviewStatsCalculator = ReviewStatsCalculator()

    private var categoryStats: [CategoryStat] {
        let grouped = Dictionary(grouping: completedTasks) { $0.taskType }
        var stats = grouped.map { CategoryStat(category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Add event minutes to matching categories
        let eventMinutes = statsCalculator.computeCategoryMinutes(
            tasks: [],
            calendarEvents: calendarEvents
        )
        for (category, minutes) in eventMinutes {
            if let index = stats.firstIndex(where: { $0.category == category }) {
                stats[index] = CategoryStat(
                    category: category,
                    count: stats[index].count,
                    eventMinutes: minutes
                )
            } else {
                stats.append(CategoryStat(category: category, count: 0, eventMinutes: minutes))
            }
        }

        return stats.sorted { $0.count + ($0.eventMinutes ?? 0) > $1.count + ($1.eventMinutes ?? 0) }
    }

    private var totalFocusMinutes: Int {
        completedTasks.compactMap(\.estimatedDuration).reduce(0, +)
    }

    var body: some View {
        if completedTasks.isEmpty {
            ContentUnavailableView(
                "Noch keine Tasks diese Woche",
                systemImage: "chart.bar",
                description: Text("Erledigte Tasks werden hier als Statistik angezeigt.")
            )
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats Row
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Erledigt",
                            value: "\(completedTasks.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        StatCard(
                            title: "Fokuszeit",
                            value: formatDuration(totalFocusMinutes),
                            icon: "clock.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Category Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kategorien-Verteilung")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(categoryStats) { stat in
                            BarMark(
                                x: .value("Anzahl", stat.count),
                                y: .value("Kategorie", stat.label)
                            )
                            .foregroundStyle(stat.color)
                            .cornerRadius(4)
                        }
                        .frame(height: CGFloat(categoryStats.count * 44))
                        .padding(.horizontal)

                        // Marker for UI tests: events contribute to stats
                        if categoryStats.contains(where: { $0.hasEventContribution }) {
                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityIdentifier("eventMinutesIncluded")
                        }
                    }

                    Divider()

                    // Category Cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kategorien im Detail")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150, maximum: 200))
                        ], spacing: 12) {
                            ForEach(categoryStats) { stat in
                                CategoryStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CompletedTaskRow: View {
    let task: LocalTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(true, color: .secondary)

                HStack(spacing: 8) {
                    ReviewCategoryBadge(taskType: task.taskType)

                    if let duration = task.estimatedDuration {
                        Text("\(duration) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct CategoryStatCard: View {
    let stat: CategoryStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.icon)
                    .foregroundStyle(stat.color)
                Text(stat.label)
                    .font(.subheadline.bold())
            }

            Text("\(stat.count) Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(stat.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Category badge for review view (local to avoid conflicts)
struct ReviewCategoryBadge: View {
    let taskType: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch taskType {
        case "income": return .green
        case "maintenance": return .orange
        case "recharge": return .cyan
        case "learning": return .purple
        case "giving_back": return .pink
        default: return .gray
        }
    }

    private var icon: String {
        switch taskType {
        case "income": return "dollarsign.circle"
        case "maintenance": return "wrench.and.screwdriver"
        case "recharge": return "battery.100"
        case "learning": return "book"
        case "giving_back": return "gift"
        default: return "questionmark.circle"
        }
    }

    private var label: String {
        switch taskType {
        case "income": return "Geld"
        case "maintenance": return "Pflege"
        case "recharge": return "Energie"
        case "learning": return "Lernen"
        case "giving_back": return "Geben"
        default: return taskType
        }
    }
}

// MARK: - Data Model

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
    var eventMinutes: Int? = nil

    var label: String {
        TaskCategory(rawValue: category)?.displayName ?? category
    }

    var color: Color {
        TaskCategory(rawValue: category)?.color ?? .gray
    }

    var icon: String {
        TaskCategory(rawValue: category)?.icon ?? "questionmark.circle"
    }

    var hasEventContribution: Bool {
        (eventMinutes ?? 0) > 0
    }
}

// MARK: - Preview

#Preview {
    MacReviewView()
        .frame(width: 700, height: 500)
}
