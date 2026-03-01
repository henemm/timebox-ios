import WidgetKit
import SwiftUI

/// Home Screen Widget for quick task capture
/// Tapping opens the app with QuickCaptureView
struct QuickCaptureWidget: Widget {
    static let kind: String = "com.focusblox.quickcapture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("Schnell einen neuen Task erfassen")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date(), relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: Date(), relevance: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        // ITB-G3: Read state from App Group UserDefaults for relevance scoring
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        let hasActiveFocusBlock = defaults?.bool(forKey: "widget_hasActiveFocusBlock") ?? false
        let urgentTaskCount = defaults?.integer(forKey: "widget_urgentTaskCount") ?? 0
        let totalTaskCount = defaults?.integer(forKey: "widget_totalTaskCount") ?? 0

        // Calculate relevance score for Smart Stack placement
        let score: Double
        if hasActiveFocusBlock {
            score = 100.0
        } else if urgentTaskCount > 0 {
            score = 80.0
        } else if totalTaskCount > 0 {
            score = 40.0
        } else {
            score = 10.0
        }

        var entry = QuickCaptureEntry(date: Date())
        entry.relevance = TimelineEntryRelevance(score: Float(score))

        // Update every 15 minutes to refresh relevance
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    var relevance: TimelineEntryRelevance?
}

// MARK: - Widget View

struct QuickCaptureWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickCaptureEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            Text("Quick Task")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "focusblox://create-task"))
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Task")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Tippe, um einen neuen Task zu erstellen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "focusblox://create-task"))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Small", as: .systemSmall) {
    QuickCaptureWidget()
} timeline: {
    QuickCaptureEntry(date: Date(), relevance: nil)
}

#Preview("Medium", as: .systemMedium) {
    QuickCaptureWidget()
} timeline: {
    QuickCaptureEntry(date: Date(), relevance: nil)
}
#endif
