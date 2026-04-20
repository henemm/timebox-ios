import SwiftUI

/// Visual representation of a scheduled task on the timeline (RW_3.1c).
/// Replaces the Phase B placeholders (ScheduledTaskOverlay + TimelineScheduledTaskRow).
struct ScheduledTaskBlock: View {
    let taskID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let onUnschedule: () -> Void
    let onStartFocusSprint: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.orange)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(timeRangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if let onSprint = onStartFocusSprint {
                Button {
                    onSprint()
                } label: {
                    Label("Focus Sprint starten", systemImage: "bolt.fill")
                }
                Divider()
            }
            Button(role: .destructive) {
                onUnschedule()
            } label: {
                Label("Entplanen", systemImage: "arrow.uturn.backward")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scheduledTaskBlock_\(taskID)")
        .draggable(CalendarEventTransfer(
            taskID: taskID,
            title: title,
            durationMinutes: Int(endDate.timeIntervalSince(startDate) / 60)
        ))
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}
