import SwiftUI

struct TimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let onScheduleTask: ((PlanItemTransfer, Date) -> Void)?

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22

    init(date: Date, events: [CalendarEvent], onScheduleTask: ((PlanItemTransfer, Date) -> Void)? = nil) {
        self.date = date
        self.events = events
        self.onScheduleTask = onScheduleTask
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HourRow(hour: hour)
                                .frame(height: hourHeight)
                        }
                    }

                    // Events overlay
                    ForEach(filteredEvents) { event in
                        EventBlock(
                            event: event,
                            hourHeight: hourHeight,
                            startHour: startHour
                        )
                    }
                }
                .padding(.top, 8)
                .frame(minHeight: CGFloat(endHour - startHour) * hourHeight)
            }
            .scrollIndicators(.hidden)
            .dropDestination(for: PlanItemTransfer.self) { items, location in
                guard let item = items.first,
                      let onSchedule = onScheduleTask else {
                    return false
                }

                let dropTime = timeFromYPosition(location.y)
                onSchedule(item, dropTime)
                return true
            }
        }
    }

    private var filteredEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    private func timeFromYPosition(_ y: CGFloat) -> Date {
        let hoursFromStart = y / hourHeight
        let hour = startHour + Int(hoursFromStart)
        let minute = Int((hoursFromStart - floor(hoursFromStart)) * 60)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), endHour - 1)
        components.minute = (minute / 15) * 15 // Snap to 15-minute intervals

        return Calendar.current.date(from: components) ?? date
    }
}
