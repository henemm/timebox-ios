//
//  MacTimelineView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

// MARK: - Event Layout Model

/// Unified time item for combined collision detection
private struct TimelineItem: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let type: ItemType

    enum ItemType {
        case event(CalendarEvent)
        case focusBlock(FocusBlock)
    }

    init(event: CalendarEvent) {
        self.id = event.id
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.type = .event(event)
    }

    init(block: FocusBlock) {
        self.id = block.id
        self.startDate = block.startDate
        self.endDate = block.endDate
        self.type = .focusBlock(block)
    }
}

/// Represents a positioned item with column information for side-by-side layout
private struct PositionedItem: Identifiable {
    let id: String
    let item: TimelineItem
    let column: Int
    let totalColumns: Int
}

/// Represents a positioned event with column information for side-by-side layout
private struct PositionedEvent: Identifiable {
    let id: String
    let event: CalendarEvent
    let column: Int
    let totalColumns: Int
}

/// Timeline view showing calendar events and focus blocks for a day
struct MacTimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    var freeSlots: [TimeSlot] = []
    var onCreateFocusBlock: ((Date, Int, String) -> Void)?
    var onAddTaskToBlock: ((String, String) -> Void)?
    var onTapBlock: ((FocusBlock) -> Void)?
    var onTapEditBlock: ((FocusBlock) -> Void)?
    var onTapFreeSlot: ((TimeSlot) -> Void)?
    var onTapEvent: ((CalendarEvent) -> Void)?

    // Timeline configuration
    private let startHour = 6
    private let endHour = 22
    private let hourHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 50

    // Drop target state
    @State private var isDropTargeted = false
    @State private var dropLocation: CGPoint = .zero

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid background
                    hourGrid

                    // Events container with proper width
                    let contentWidth = geometry.size.width - timeColumnWidth - 16

                    // TimelineLayout positions ALL views with correct hit-testing!
                    // Uses place() instead of offset() so Hit-Areas match visual position
                    TimelineLayout(hourHeight: hourHeight, startHour: startHour, endHour: endHour) {
                        // Regular calendar events (with collision detection)
                        ForEach(positionedEvents) { positioned in
                            EventBlockView(event: positioned.event, onTap: {
                                onTapEvent?(positioned.event)
                            })
                                .timelinePosition(
                                    hour: Calendar.current.component(.hour, from: positioned.event.startDate),
                                    minute: Calendar.current.component(.minute, from: positioned.event.startDate),
                                    durationMinutes: positioned.event.durationMinutes,
                                    column: positioned.column,
                                    totalColumns: positioned.totalColumns
                                )
                        }

                        // Focus blocks (with collision detection)
                        ForEach(positionedFocusBlocks) { positioned in
                            FocusBlockView(
                                block: positioned.block,
                                onAddTask: { taskID in
                                    onAddTaskToBlock?(positioned.block.id, taskID)
                                },
                                onTapBlock: {
                                    onTapBlock?(positioned.block)
                                },
                                onTapEdit: {
                                    onTapEditBlock?(positioned.block)
                                }
                            )
                            .timelinePosition(
                                hour: Calendar.current.component(.hour, from: positioned.block.startDate),
                                minute: Calendar.current.component(.minute, from: positioned.block.startDate),
                                durationMinutes: positioned.block.durationMinutes,
                                column: positioned.column,
                                totalColumns: positioned.totalColumns
                            )
                        }

                        // Free slots (suggestions for new blocks)
                        ForEach(freeSlots) { slot in
                            FreeSlotView(
                                slot: slot,
                                onTap: {
                                    onTapFreeSlot?(slot)
                                }
                            )
                            .timelinePosition(
                                hour: Calendar.current.component(.hour, from: slot.startDate),
                                minute: Calendar.current.component(.minute, from: slot.startDate),
                                durationMinutes: slot.durationMinutes,
                                column: 0,
                                totalColumns: 1
                            )
                        }
                    }
                    .padding(.leading, timeColumnWidth)

                    // Drop preview indicator (separate from TimelineLayout - uses offset for realtime preview)
                    if isDropTargeted {
                        DropPreviewIndicator(
                            location: dropLocation,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            date: date
                        )
                        .padding(.leading, timeColumnWidth)
                    }

                    // Current time indicator (separate from TimelineLayout - special styling)
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(hourHeight: hourHeight, startHour: startHour)
                            .padding(.leading, timeColumnWidth - 4)
                    }
                }
                .frame(height: totalHeight)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .dropDestination(for: MacTaskTransfer.self) { items, location in
            guard let task = items.first else { return false }

            // Check if drop is over an existing focus block - assign to that block
            if let blockID = focusBlockAtLocation(location) {
                onAddTaskToBlock?(blockID, task.id)
                return true
            }

            // Otherwise create new focus block at this time
            let dropTime = calculateTimeFromLocation(location)
            onCreateFocusBlock?(dropTime, task.duration, task.id)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                dropLocation = location
            case .ended:
                break
            }
        }
    }

    // MARK: - Collision Detection & Layout (Combined)

    /// All positioned items (events + focus blocks) with unified collision detection
    private var positionedItems: [PositionedItem] {
        // Filter regular events (exclude FocusBlocks, all-day, and very long events)
        let regularEvents = events.filter { event in
            !event.isFocusBlock &&
            !event.isAllDay &&
            event.durationMinutes <= 480 // 8 hours max
        }

        // Combine events and focus blocks into unified items
        var allItems: [TimelineItem] = []
        allItems.append(contentsOf: regularEvents.map { TimelineItem(event: $0) })
        allItems.append(contentsOf: focusBlocks.map { TimelineItem(block: $0) })

        // Run unified collision detection
        let groups = groupOverlappingItems(allItems)

        // Build positioned items with correct column assignments
        var result: [PositionedItem] = []
        for group in groups {
            for (index, item) in group.enumerated() {
                result.append(PositionedItem(
                    id: item.id,
                    item: item,
                    column: index,
                    totalColumns: group.count
                ))
            }
        }
        return result
    }

    /// Extracts positioned events from the unified positioned items
    private var positionedEvents: [PositionedEvent] {
        positionedItems.compactMap { positioned -> PositionedEvent? in
            if case .event(let event) = positioned.item.type {
                return PositionedEvent(
                    id: positioned.id,
                    event: event,
                    column: positioned.column,
                    totalColumns: positioned.totalColumns
                )
            }
            return nil
        }
    }

    /// Extracts positioned focus blocks from the unified positioned items
    private var positionedFocusBlocks: [PositionedFocusBlock] {
        positionedItems.compactMap { positioned -> PositionedFocusBlock? in
            if case .focusBlock(let block) = positioned.item.type {
                return PositionedFocusBlock(
                    id: positioned.id,
                    block: block,
                    column: positioned.column,
                    totalColumns: positioned.totalColumns
                )
            }
            return nil
        }
    }

    /// Groups items that overlap in time - unified for both events and focus blocks
    private func groupOverlappingItems(_ items: [TimelineItem]) -> [[TimelineItem]] {
        guard !items.isEmpty else { return [] }

        let sorted = items.sorted { $0.startDate < $1.startDate }
        var groups: [[TimelineItem]] = []
        var currentGroup: [TimelineItem] = []
        var currentGroupEndTime: Date?

        for item in sorted {
            if let endTime = currentGroupEndTime, item.startDate < endTime {
                // Overlaps with current group
                currentGroup.append(item)
                // Extend group end time if needed
                if item.endDate > endTime {
                    currentGroupEndTime = item.endDate
                }
            } else {
                // No overlap, start new group
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [item]
                currentGroupEndTime = item.endDate
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    // MARK: - Hit Testing

    /// Returns the FocusBlock ID at the given location, or nil if not over a block
    private func focusBlockAtLocation(_ location: CGPoint) -> String? {
        let adjustedY = location.y

        for block in focusBlocks {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: block.startDate)
            let minute = calendar.component(.minute, from: block.startDate)
            let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
            let blockTop = hoursFromStart * hourHeight
            let blockHeight = CGFloat(block.durationMinutes) / 60.0 * hourHeight

            // Check Y (vertical) - is the drop within the block's time range?
            if adjustedY >= blockTop && adjustedY <= blockTop + blockHeight {
                return block.id
            }
        }
        return nil
    }

    // MARK: - Time Calculation

    private func calculateTimeFromLocation(_ location: CGPoint) -> Date {
        let adjustedY = location.y
        let hoursFromStart = adjustedY / hourHeight
        let hour = Int(hoursFromStart) + startHour
        let minute = Int((hoursFromStart - floor(hoursFromStart)) * 60)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), endHour - 1)
        components.minute = (minute / 15) * 15

        return Calendar.current.date(from: components) ?? date
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    // Hour label
                    Text(hourLabel(hour))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)

                    // Grid line
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 1)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

/// Positioned focus block for layout
private struct PositionedFocusBlock: Identifiable {
    let id: String
    let block: FocusBlock
    let column: Int
    let totalColumns: Int
}

// MARK: - Event Block View (readonly calendar events)

/// Calendar event view - positioned by TimelineLayout using place()
struct EventBlockView: View {
    let event: CalendarEvent
    var onTap: (() -> Void)?

    var body: some View {
        // TimelineLayout provides size via ProposedViewSize - use frame modifiers
        HStack(spacing: 0) {
            // Category color stripe (left edge)
            if let category = event.category,
               let config = TaskCategory(rawValue: category) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(config.color)
                    .frame(width: 4)
                    .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let category = event.category,
                       let config = TaskCategory(rawValue: category) {
                        Image(systemName: config.icon)
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(displayTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                }
                .foregroundStyle(.white)

                Text(timeRange)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(categoryColor ?? eventColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(eventColor.opacity(0.8), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .accessibilityIdentifier("calendarEvent_\(event.id)")
    }

    private var displayTitle: String {
        event.title.isEmpty ? "(Kein Titel)" : event.title
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    /// Category-based background color (if categorized)
    private var categoryColor: Color? {
        guard let category = event.category,
              let config = TaskCategory(rawValue: category) else { return nil }
        return config.color.opacity(0.85)
    }

    /// Generates consistent color from event title
    private var eventColor: Color {
        let hash = abs(event.title.hashValue)
        let colors: [Color] = [
            Color(red: 0.35, green: 0.55, blue: 0.75),  // Blue
            Color(red: 0.55, green: 0.45, blue: 0.70),  // Purple
            Color(red: 0.45, green: 0.60, blue: 0.50),  // Green
            Color(red: 0.70, green: 0.50, blue: 0.45),  // Brown
            Color(red: 0.60, green: 0.55, blue: 0.45),  // Tan
        ]
        return colors[hash % colors.count]
    }
}

// MARK: - Focus Block View (interactive)

/// Interactive FocusBlock view - positioned by TimelineLayout using place()
/// Supports tap, hover, and drag & drop because place() sets correct hit-areas
struct FocusBlockView: View {
    let block: FocusBlock
    var onAddTask: ((String) -> Void)?
    var onTapBlock: (() -> Void)?
    var onTapEdit: (() -> Void)?

    @State private var isDropTargeted = false
    @State private var isHovered = false

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: block.startDate)) - \(formatter.string(from: block.endDate))"
    }

    var body: some View {
        // Same structure as EventBlockView that works
        VStack(alignment: .leading, spacing: 2) {
            // Header row with icon
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                Text(block.title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)

            // Time range
            Text(timeRange)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))

            // Task count
            Text("\(block.taskIDs.count) Tasks")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))

            // Drop indicator
            if isDropTargeted {
                Label("Ablegen", systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(blockColor.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(isDropTargeted ? 0.5 : 0.2), lineWidth: isDropTargeted ? 2 : 1)
        )
        .shadow(color: blockColor.opacity(0.3), radius: isDropTargeted ? 8 : 4, y: 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTapBlock?()
        }
        .dropDestination(for: MacTaskTransfer.self) { items, _ in
            guard let task = items.first else { return false }
            onAddTask?(task.id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = targeted
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focusBlock_\(block.id)")
    }

    private var blockColor: Color {
        if block.isActive {
            return Color(red: 0.2, green: 0.7, blue: 0.4)  // Green
        } else if block.isPast {
            return Color(red: 0.4, green: 0.4, blue: 0.45) // Gray
        } else {
            return Color(red: 0.25, green: 0.5, blue: 0.85) // Blue
        }
    }
}

// MARK: - Current Time Indicator

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    let startHour: Int

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(y: currentTimeOffset)
    }

    private var currentTimeOffset: CGFloat {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }
}

// MARK: - Drop Preview Indicator

struct DropPreviewIndicator: View {
    let location: CGPoint
    let hourHeight: CGFloat
    let startHour: Int
    let date: Date

    private var dropTime: Date {
        let hoursFromStart = location.y / hourHeight
        let hour = Int(hoursFromStart) + startHour
        let minute = Int((hoursFromStart - floor(hoursFromStart)) * 60)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), 21)
        components.minute = (minute / 15) * 15

        return Calendar.current.date(from: components) ?? date
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dropTime)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(timeString)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Rectangle()
                .fill(Color.blue)
                .frame(height: 2)
        }
        .offset(y: snappedOffset)
    }

    private var snappedOffset: CGFloat {
        // Snap to 15-minute intervals
        let hoursFromStart = location.y / hourHeight
        let snappedMinutes = (Int(hoursFromStart * 60) / 15) * 15
        return CGFloat(snappedMinutes) / 60.0 * hourHeight
    }
}

// MARK: - Free Slot View (Smart Suggestions)

/// View for displaying a free time slot - positioned by TimelineLayout using place()
struct FreeSlotView: View {
    let slot: TimeSlot
    var onTap: (() -> Void)?

    @State private var isHovered = false

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        // TimelineLayout provides size via ProposedViewSize - use frame modifiers
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("Freie Zeit")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(slot.durationMinutes) min")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.green)

            Text("\(timeFormatter.string(from: slot.startDate)) - \(timeFormatter.string(from: slot.endDate))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                )
                .foregroundStyle(.green.opacity(isHovered ? 0.6 : 0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.green.opacity(isHovered ? 0.15 : 0.05))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
        .accessibilityIdentifier("freeSlot_\(slot.id)")
    }
}

#Preview {
    MacTimelineView(
        date: Date(),
        events: [],
        focusBlocks: [],
        freeSlots: []
    )
    .frame(width: 400, height: 600)
}
