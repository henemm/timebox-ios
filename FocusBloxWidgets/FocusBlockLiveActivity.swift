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
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.28))
                                .frame(width: 52, height: 52)
                            Image(systemName: "target")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 12)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Text(context.attributes.endDate, style: .timer)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .layoutPriority(1)
                            .padding(.top, 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentTaskTitle ?? context.attributes.blockTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(context.state.completedCount)/\(context.attributes.totalTaskCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(
                            value: Double(context.state.completedCount),
                            total: Double(max(context.attributes.totalTaskCount, 1))
                        )
                        .tint(.blue)
                    }
                    .padding(.horizontal, 16)
                }
            } compactLeading: {
                // Compact leading: Icon with explicit frame
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.28))
                        .frame(width: 20, height: 20)
                    Image(systemName: "target")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // OVERLAY-TRICK: Hidden placeholder fixes width jitter
                Text("00:00")
                    .hidden()
                    .overlay(alignment: .trailing) {
                        Text(context.attributes.endDate, style: .timer)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
            } minimal: {
                // Minimal: Explicit frame for consistent size
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.28))
                        .frame(width: 18, height: 18)
                    Image(systemName: "target")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .keylineTint(.blue)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusBlockActivityAttributes>

    var body: some View {
        HStack {
            // Leading: Icon with background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.28))
                    .frame(width: 40, height: 40)
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.leading)

            // Center: Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.blockTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let taskTitle = context.state.currentTaskTitle {
                    Text(taskTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Text("\(context.state.completedCount)/\(context.attributes.totalTaskCount) Tasks")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Trailing: Timer
            Text(context.attributes.endDate, style: .timer)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Lock Screen", as: .content, using: FocusBlockActivityAttributes.preview) {
    FocusBlockLiveActivity()
} contentStates: {
    FocusBlockActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: FocusBlockActivityAttributes.preview) {
    FocusBlockLiveActivity()
} contentStates: {
    FocusBlockActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: FocusBlockActivityAttributes.preview) {
    FocusBlockLiveActivity()
} contentStates: {
    FocusBlockActivityAttributes.ContentState.sample
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: FocusBlockActivityAttributes.preview) {
    FocusBlockLiveActivity()
} contentStates: {
    FocusBlockActivityAttributes.ContentState.sample
}
#endif
