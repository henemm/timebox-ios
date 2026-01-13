import SwiftUI

struct EventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int
    let onTap: (() -> Void)?

    init(event: CalendarEvent, hourHeight: CGFloat, startHour: Int, onTap: (() -> Void)? = nil) {
        self.event = event
        self.hourHeight = hourHeight
        self.startHour = startHour
        self.onTap = onTap
    }

    var body: some View {
        let yOffset = calculateYOffset()
        let height = calculateHeight()

        RoundedRectangle(cornerRadius: 6)
            .fill(.blue.opacity(0.3))
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(timeRangeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(6),
                alignment: .topLeading
            )
            .frame(height: max(height, 25))
            .padding(.leading, 55)
            .padding(.trailing, 8)
            .offset(y: yOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    private func calculateYOffset() -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }

    private func calculateHeight() -> CGFloat {
        let durationHours = CGFloat(event.durationMinutes) / 60.0
        return durationHours * hourHeight
    }
}
