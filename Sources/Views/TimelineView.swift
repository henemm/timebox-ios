import SwiftUI

struct TimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let scheduledTasks: [TimelineItem]
    let onScheduleTask: ((PlanItemTransfer, Date) -> Void)?
    let onMoveEvent: ((CalendarEventTransfer, Date) -> Void)?
    let onEventTap: ((CalendarEvent) -> Void)?
    let onScheduledTaskTap: ((String) -> Void)?
    let onRefresh: (() async -> Void)?

    private let hourHeight: CGFloat = 60
    private let startHour = 6
    private let endHour = 22

    init(
        date: Date,
        events: [CalendarEvent],
        scheduledTasks: [TimelineItem] = [],
        onScheduleTask: ((PlanItemTransfer, Date) -> Void)? = nil,
        onMoveEvent: ((CalendarEventTransfer, Date) -> Void)? = nil,
        onEventTap: ((CalendarEvent) -> Void)? = nil,
        onScheduledTaskTap: ((String) -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.date = date
        self.events = events
        self.scheduledTasks = scheduledTasks
        self.onScheduleTask = onScheduleTask
        self.onMoveEvent = onMoveEvent
        self.onEventTap = onEventTap
        self.onScheduledTaskTap = onScheduledTaskTap
        self.onRefresh = onRefresh
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid with individual drop zones for better precision
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            TimelineHourSlot(
                                hour: hour,
                                hourHeight: hourHeight,
                                date: date,
                                onScheduleTask: onScheduleTask,
                                onMoveEvent: onMoveEvent
                            )
                        }
                    }

                    // Events overlay
                    ForEach(filteredEvents) { event in
                        EventBlock(
                            event: event,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            onTap: onEventTap != nil ? { onEventTap?(event) } : nil
                        )
                    }

                    // Scheduled tasks overlay (RW_3.1b)
                    ForEach(scheduledTasks) { item in
                        ScheduledTaskOverlay(
                            item: item,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            onTap: scheduledTaskTapHandler(for: item)
                        )
                    }
                }
                .padding(.top, 8)
                .frame(minHeight: CGFloat(endHour - startHour) * hourHeight)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh?()
            }
        }
    }

    private var filteredEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }
    }

    private func scheduledTaskTapHandler(for item: TimelineItem) -> (() -> Void)? {
        guard let onTap = onScheduledTaskTap else { return nil }
        if case .scheduledTask(let id, _) = item.type {
            return { onTap(id) }
        }
        return nil
    }
}

// MARK: - Scheduled Task Overlay (RW_3.1b)

struct ScheduledTaskOverlay: View {
    let item: TimelineItem
    let hourHeight: CGFloat
    let startHour: Int
    let onTap: (() -> Void)?

    private var taskTitle: String {
        if case .scheduledTask(_, let title) = item.type { return title }
        return ""
    }

    private var taskID: String {
        if case .scheduledTask(let id, _) = item.type { return id }
        return item.id
    }

    var body: some View {
        let startMinutes = minutesSinceMidnight(item.startDate)
        let endMinutes = minutesSinceMidnight(item.endDate)
        let topOffset = CGFloat(startMinutes - startHour * 60) * hourHeight / 60
        let height = max(CGFloat(endMinutes - startMinutes) * hourHeight / 60, 20)

        HStack {
            Spacer().frame(width: 53)
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.orange, lineWidth: 1.5)
                )
                .overlay(alignment: .leading) {
                    Text(taskTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
                .frame(height: height)
                .accessibilityIdentifier("scheduledTaskBlock_\(taskID)")
                .onTapGesture { onTap?() }
            Spacer().frame(width: 16)
        }
        .offset(y: topOffset)
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - Hour Slot with Quarter-Hour Drop Zones

struct TimelineHourSlot: View {
    let hour: Int
    let hourHeight: CGFloat
    let date: Date
    let onScheduleTask: ((PlanItemTransfer, Date) -> Void)?
    let onMoveEvent: ((CalendarEventTransfer, Date) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Four 15-minute drop zones per hour
            ForEach(0..<4, id: \.self) { quarter in
                QuarterHourDropZone(
                    hour: hour,
                    quarter: quarter,
                    slotHeight: hourHeight / 4,
                    date: date,
                    onScheduleTask: onScheduleTask,
                    onMoveEvent: onMoveEvent,
                    showLabel: quarter == 0
                )
            }
        }
        .frame(height: hourHeight)
    }
}

// MARK: - Quarter Hour Drop Zone with Visual Feedback

struct QuarterHourDropZone: View {
    let hour: Int
    let quarter: Int
    let slotHeight: CGFloat
    let date: Date
    let onScheduleTask: ((PlanItemTransfer, Date) -> Void)?
    let onMoveEvent: ((CalendarEventTransfer, Date) -> Void)?
    let showLabel: Bool

    @State private var isTargeted = false

    private var minute: Int { quarter * 15 }

    private var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    private var dropTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? date
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Time label (only for :00)
            Group {
                if showLabel {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                }
            }
            .frame(width: 45, alignment: .trailing)

            // Drop zone
            ZStack(alignment: .leading) {
                // Background line (only at hour marks)
                if showLabel {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 1)
                }

                // Drop highlight
                if isTargeted {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.blue, lineWidth: 2)
                        )
                        .overlay(alignment: .leading) {
                            Text(timeString)
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                                .padding(.leading, 8)
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: slotHeight)
        .padding(.trailing)
        .contentShape(Rectangle())
        .dropDestination(for: PlanItemTransfer.self) { items, _ in
            guard let item = items.first,
                  let onSchedule = onScheduleTask else {
                return false
            }
            onSchedule(item, dropTime)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = targeted
            }
        }
        .dropDestination(for: CalendarEventTransfer.self) { items, _ in
            guard let item = items.first,
                  let onMove = onMoveEvent else {
                return false
            }
            onMove(item, dropTime)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTargeted = targeted
            }
        }
    }
}
