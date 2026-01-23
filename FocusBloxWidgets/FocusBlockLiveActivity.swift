import ActivityKit
import FocusBloxCore
import SwiftUI
import WidgetKit

/// Live Activity widget for Focus Block
/// Displays on Lock Screen and Dynamic Island
struct FocusBlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusBlockActivityAttributes.self) { context in
            // Lock Screen view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (when tapped)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "target")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerView(endDate: context.attributes.endDate)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentTaskTitle ?? context.attributes.blockTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: Double(context.state.completedCount),
                        total: Double(context.attributes.totalTaskCount)
                    )
                    .tint(.blue)
                }
            } compactLeading: {
                // Compact leading (small pill)
                Image(systemName: "target")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                // Compact trailing (timer)
                TimerView(endDate: context.attributes.endDate)
            } minimal: {
                // Minimal (single icon when space is limited)
                Image(systemName: "target")
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusBlockActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Leading: Icon
            Image(systemName: "target")
                .font(.title)
                .foregroundStyle(.blue)

            // Center: Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.blockTitle)
                    .font(.headline)

                if let taskTitle = context.state.currentTaskTitle {
                    Text(taskTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(context.state.completedCount)/\(context.attributes.totalTaskCount) Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Trailing: Timer
            TimerView(endDate: context.attributes.endDate)
                .font(.title2.monospacedDigit().weight(.semibold))
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }
}

// MARK: - Timer View

private struct TimerView: View {
    let endDate: Date

    var body: some View {
        Text(timerInterval: Date()...endDate, countsDown: true)
            .monospacedDigit()
            .foregroundStyle(.blue)
    }
}
