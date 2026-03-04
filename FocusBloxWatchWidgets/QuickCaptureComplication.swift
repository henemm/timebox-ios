import WidgetKit
import SwiftUI

/// Watch Complication for 1-tap voice capture from the watch face
struct QuickCaptureComplication: Widget {
    static let kind: String = "com.focusblox.watch.quickcapture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickCaptureComplicationProvider()) { entry in
            QuickCaptureComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("1-Tap zum Diktat")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Timeline Provider

struct QuickCaptureComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureComplicationEntry {
        QuickCaptureComplicationEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureComplicationEntry) -> Void) {
        completion(QuickCaptureComplicationEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureComplicationEntry>) -> Void) {
        let entry = QuickCaptureComplicationEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct QuickCaptureComplicationEntry: TimelineEntry {
    let date: Date
}

// MARK: - Complication View

struct QuickCaptureComplicationView: View {
    var entry: QuickCaptureComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .widgetURL(URL(string: "focusblox://voice-capture"))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Circular", as: .accessoryCircular) {
    QuickCaptureComplication()
} timeline: {
    QuickCaptureComplicationEntry(date: Date())
}
#endif
