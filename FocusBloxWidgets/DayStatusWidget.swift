import WidgetKit
import SwiftUI

/// Lock Screen Widget showing daily status: morning task overview, evening completion summary.
struct DayStatusWidget: Widget {
    static let kind = "com.focusblox.daystatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DayStatusProvider()) { entry in
            DayStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tagesstatus")
        .description("Morgens: wartende Tasks. Abends: Tagesbilanz.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Phase

enum WidgetPhase {
    case morning
    case evening

    static func current(hour: Int = Calendar.current.component(.hour, from: Date())) -> WidgetPhase {
        hour < 18 ? .morning : .evening
    }
}

// MARK: - Timeline Entry

struct DayStatusEntry: TimelineEntry {
    let date: Date
    let phase: WidgetPhase
    let nextUpCount: Int
    let completedCount: Int
    let totalCount: Int
    let oldestDays: Int
    var relevance: TimelineEntryRelevance?
}

// MARK: - Timeline Provider

struct DayStatusProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")

    func placeholder(in context: Context) -> DayStatusEntry {
        DayStatusEntry(date: Date(), phase: .morning,
                       nextUpCount: 3, completedCount: 0, totalCount: 3, oldestDays: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayStatusEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayStatusEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current

        // Create entries for morning (07:00), midday (12:00), evening (18:00)
        var entries: [DayStatusEntry] = []
        let today = calendar.startOfDay(for: now)

        let hours = [7, 12, 18]
        for hour in hours {
            guard let entryDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                  entryDate >= now else { continue }
            entries.append(makeEntry(for: entryDate))
        }

        // If no future entries today, add one for now
        if entries.isEmpty {
            entries.append(makeEntry(for: now))
        }

        // Next refresh: tomorrow at 07:00
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextMorning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!

        let timeline = Timeline(entries: entries, policy: .after(nextMorning))
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> DayStatusEntry {
        let hour = Calendar.current.component(.hour, from: date)
        let phase = WidgetPhase.current(hour: hour)

        let nextUp = defaults?.integer(forKey: "widget_nextUpCount") ?? 0
        let completed = defaults?.integer(forKey: "widget_completedTodayCount") ?? 0
        let total = defaults?.integer(forKey: "widget_totalTodayCount") ?? 0
        let oldest = defaults?.integer(forKey: "widget_oldestWaitingDays") ?? 0

        // Morning widget more relevant in morning, evening in evening
        let score: Float = (phase == .morning) ? 70 : 50

        return DayStatusEntry(
            date: date,
            phase: phase,
            nextUpCount: nextUp,
            completedCount: completed,
            totalCount: total,
            oldestDays: oldest,
            relevance: TimelineEntryRelevance(score: score)
        )
    }
}

// MARK: - Widget View

struct DayStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DayStatusEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            Text(inlineText)
        default:
            rectangularView
        }
    }

    // MARK: - Rectangular (Lock Screen)

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch entry.phase {
            case .morning:
                morningRectangular
            case .evening:
                eveningRectangular
            }
        }
        .widgetURL(URL(string: "focusblox://day-view"))
    }

    @ViewBuilder
    private var morningRectangular: some View {
        if entry.nextUpCount == 0 {
            Label("Alles erledigt", systemImage: "checkmark.circle")
                .font(.headline)
        } else {
            Label("\(entry.nextUpCount) Tasks warten", systemImage: "tray.full")
                .font(.headline)
            if entry.oldestDays > 0 {
                Text("Aelteste seit \(entry.oldestDays) Tagen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var eveningRectangular: some View {
        if entry.totalCount == 0 {
            Label("Freier Tag", systemImage: "sun.max")
                .font(.headline)
        } else {
            let emoji = (entry.totalCount > 0 && entry.completedCount * 2 >= entry.totalCount) ? " \u{2713}" : ""
            Label("\(entry.completedCount) von \(entry.totalCount) geschafft\(emoji)",
                  systemImage: "chart.bar")
                .font(.headline)
            Text("heute")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Inline (Lock Screen single line)

    private var inlineText: String {
        switch entry.phase {
        case .morning:
            if entry.nextUpCount == 0 { return "Alles erledigt" }
            if entry.oldestDays > 0 {
                return "\(entry.nextUpCount) Tasks \u{00B7} \(entry.oldestDays) Tage"
            }
            return "\(entry.nextUpCount) Tasks warten"
        case .evening:
            if entry.totalCount == 0 { return "Freier Tag" }
            let emoji = (entry.completedCount * 2 >= entry.totalCount) ? " \u{2713}" : ""
            return "\(entry.completedCount)/\(entry.totalCount) heute\(emoji)"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Rectangular Morning", as: .accessoryRectangular) {
    DayStatusWidget()
} timeline: {
    DayStatusEntry(date: Date(), phase: .morning,
                   nextUpCount: 5, completedCount: 0, totalCount: 5, oldestDays: 3)
}

#Preview("Rectangular Evening", as: .accessoryRectangular) {
    DayStatusWidget()
} timeline: {
    DayStatusEntry(date: Date(), phase: .evening,
                   nextUpCount: 0, completedCount: 4, totalCount: 6, oldestDays: 0)
}

#Preview("Inline Morning", as: .accessoryInline) {
    DayStatusWidget()
} timeline: {
    DayStatusEntry(date: Date(), phase: .morning,
                   nextUpCount: 3, completedCount: 0, totalCount: 3, oldestDays: 7)
}
#endif
