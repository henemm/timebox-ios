import SwiftUI

// MARK: - Shared Data Types

/// Category stat combining TaskCategory with aggregated minutes
struct CategoryStat: Identifiable {
    let id = UUID()
    let config: TaskCategory
    let minutes: Int
}

/// Task accuracy detail for drill-down into planning accuracy
struct TaskAccuracyDetail: Identifiable {
    var id: String { task.id }
    let task: PlanItem
    let plannedMinutes: Int
    let actualMinutes: Int
    let deviation: Double // -0.3 = 30% faster, 0.3 = 30% slower
}

/// Accuracy bucket for drill-down selection
enum AccuracyBucket: String, Identifiable {
    case faster, onTime, slower
    var id: String { rawValue }

    var title: String {
        switch self {
        case .faster: "Schneller"
        case .onTime: "Im Plan"
        case .slower: "Langsamer"
        }
    }

    var color: Color {
        switch self {
        case .faster: .green
        case .onTime: .blue
        case .slower: .orange
        }
    }

    var icon: String {
        switch self {
        case .faster: "arrow.up.circle.fill"
        case .onTime: "checkmark.circle.fill"
        case .slower: "arrow.down.circle.fill"
        }
    }
}

/// Drill-down target for stat items (Erledigt, Offen, Blocks)
enum StatDrillDown: Identifiable {
    case completed([PlanItem])
    case open([PlanItem])
    case blocks([FocusBlock])

    var id: String {
        switch self {
        case .completed: "completed"
        case .open: "open"
        case .blocks: "blocks"
        }
    }
}

// MARK: - Shared UI Components

/// Stat item showing value + label (used in stats headers)
struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Category bar with progress indicator
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

/// Accuracy pill showing count + label for faster/onTime/slower
struct AccuracyPill: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
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
}

// MARK: - Drill-Down Sheets

/// Shows tasks in an accuracy bucket (faster/on-time/slower)
struct AccuracyDetailSheet: View {
    let bucket: AccuracyBucket
    let tasks: [TaskAccuracyDetail]

    var body: some View {
        NavigationStack {
            List(tasks) { detail in
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.task.title)
                        .font(.subheadline)

                    HStack(spacing: 12) {
                        Label("\(detail.plannedMinutes) min geplant", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        Label("\(detail.actualMinutes) min gebraucht", systemImage: "stopwatch")
                            .font(.caption)
                            .foregroundStyle(.purple)

                        let diff = detail.actualMinutes - detail.plannedMinutes
                        if diff != 0 {
                            Text(diff > 0 ? "+\(diff)" : "\(diff)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(diff < 0 ? .green : .orange)
                        }
                    }
                }
            }
            .navigationTitle("\(tasks.count) \(bucket.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

/// Shows tasks and events for a specific category
struct CategoryDetailSheet: View {
    let category: TaskCategory
    let tasks: [PlanItem]
    let events: [CalendarEvent]

    var body: some View {
        NavigationStack {
            List {
                if !tasks.isEmpty {
                    Section("Tasks (\(tasks.count))") {
                        ForEach(tasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                                Text(task.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(task.effectiveDuration) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !events.isEmpty {
                    Section("Kalender-Events (\(events.count))") {
                        ForEach(events) { event in
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(category.color)
                                Text(event.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(event.durationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(category.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

/// Shows a simple task list (for Erledigt/Offen drill-down)
struct TaskListSheet: View {
    let title: String
    let tasks: [PlanItem]

    var body: some View {
        NavigationStack {
            List(tasks) { task in
                HStack {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                    Text(task.title)
                        .font(.subheadline)
                    Spacer()
                    if let cat = TaskCategory(rawValue: task.taskType) {
                        Image(systemName: cat.icon)
                            .font(.caption)
                            .foregroundStyle(cat.color)
                    }
                    Text("\(task.effectiveDuration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

/// Shows focus blocks list (for Blocks drill-down)
struct BlockListSheet: View {
    let blocks: [FocusBlock]
    let allTasks: [PlanItem]

    var body: some View {
        NavigationStack {
            List(blocks.sorted { $0.startDate < $1.startDate }) { block in
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.subheadline.weight(.medium))
                    HStack {
                        Text(block.timeRangeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(block.completedTaskIDs.count)/\(block.taskIDs.count) Tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(blocks.count) Blocks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

}
