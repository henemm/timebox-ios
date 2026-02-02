//
//  MacTimelineView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

// MARK: - Event Layout Model

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
    var onCreateFocusBlock: ((Date, Int, String) -> Void)?
    var onAddTaskToBlock: ((String, String) -> Void)?
    var onTapBlock: ((FocusBlock) -> Void)?
    var onTapEditBlock: ((FocusBlock) -> Void)?

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

                    // Regular calendar events (with collision detection)
                    ForEach(positionedEvents) { positioned in
                        EventBlockView(
                            event: positioned.event,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            column: positioned.column,
                            totalColumns: positioned.totalColumns,
                            containerWidth: contentWidth
                        )
                        .padding(.leading, timeColumnWidth)
                    }

                    // Focus blocks (with collision detection)
                    ForEach(positionedFocusBlocks) { positioned in
                        FocusBlockView(
                            block: positioned.block,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            column: positioned.column,
                            totalColumns: positioned.totalColumns,
                            containerWidth: contentWidth,
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
                        .padding(.leading, timeColumnWidth)
                    }

                    // Drop preview indicator
                    if isDropTargeted {
                        DropPreviewIndicator(
                            location: dropLocation,
                            hourHeight: hourHeight,
                            startHour: startHour,
                            date: date
                        )
                        .padding(.leading, timeColumnWidth)
                    }

                    // Current time indicator
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

            // Check if drop is over an existing focus block - if so, let the block handle it
            if isLocationOverFocusBlock(location) {
                return false
            }

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

    // MARK: - Collision Detection & Layout

    /// Groups overlapping events and assigns columns
    private var positionedEvents: [PositionedEvent] {
        let regularEvents = events.filter { !$0.isFocusBlock }
        let groups = groupOverlappingEvents(regularEvents)

        var result: [PositionedEvent] = []
        for group in groups {
            for (index, event) in group.enumerated() {
                result.append(PositionedEvent(
                    id: event.id,
                    event: event,
                    column: index,
                    totalColumns: group.count
                ))
            }
        }
        return result
    }

    /// Groups overlapping focus blocks
    private var positionedFocusBlocks: [PositionedFocusBlock] {
        let groups = groupOverlappingFocusBlocks(focusBlocks)

        var result: [PositionedFocusBlock] = []
        for group in groups {
            for (index, block) in group.enumerated() {
                result.append(PositionedFocusBlock(
                    id: block.id,
                    block: block,
                    column: index,
                    totalColumns: group.count
                ))
            }
        }
        return result
    }

    /// Groups events that overlap in time
    private func groupOverlappingEvents(_ events: [CalendarEvent]) -> [[CalendarEvent]] {
        guard !events.isEmpty else { return [] }

        let sorted = events.sorted { $0.startDate < $1.startDate }
        var groups: [[CalendarEvent]] = []
        var currentGroup: [CalendarEvent] = []
        var currentGroupEndTime: Date?

        for event in sorted {
            if let endTime = currentGroupEndTime, event.startDate < endTime {
                // Overlaps with current group
                currentGroup.append(event)
                // Extend group end time if needed
                if event.endDate > endTime {
                    currentGroupEndTime = event.endDate
                }
            } else {
                // No overlap, start new group
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [event]
                currentGroupEndTime = event.endDate
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    /// Groups focus blocks that overlap in time
    private func groupOverlappingFocusBlocks(_ blocks: [FocusBlock]) -> [[FocusBlock]] {
        guard !blocks.isEmpty else { return [] }

        let sorted = blocks.sorted { $0.startDate < $1.startDate }
        var groups: [[FocusBlock]] = []
        var currentGroup: [FocusBlock] = []
        var currentGroupEndTime: Date?

        for block in sorted {
            if let endTime = currentGroupEndTime, block.startDate < endTime {
                currentGroup.append(block)
                if block.endDate > endTime {
                    currentGroupEndTime = block.endDate
                }
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [block]
                currentGroupEndTime = block.endDate
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    // MARK: - Hit Testing

    /// Checks if the given location is over an existing focus block
    private func isLocationOverFocusBlock(_ location: CGPoint) -> Bool {
        let adjustedX = location.x - timeColumnWidth
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
                // For simplicity, assume block spans full width if it's in the time range
                // This is good enough since we want drops in the time range to go to the block
                if adjustedX >= 0 {
                    return true
                }
            }
        }
        return false
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

struct EventBlockView: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int
    let column: Int
    let totalColumns: Int
    let containerWidth: CGFloat

    private let spacing: CGFloat = 2
    private let minHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(blockHeight > 40 ? 2 : 1)

            if blockHeight > 35 {
                Text(timeRange)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: columnWidth, alignment: .leading)
        .frame(height: max(blockHeight, minHeight), alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(eventColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(eventColor.opacity(0.8), lineWidth: 0.5)
        )
        .offset(x: columnOffset, y: topOffset)
    }

    private var columnWidth: CGFloat {
        let availableWidth = containerWidth - (CGFloat(totalColumns - 1) * spacing)
        return availableWidth / CGFloat(totalColumns)
    }

    private var columnOffset: CGFloat {
        CGFloat(column) * (columnWidth + spacing)
    }

    private var blockHeight: CGFloat {
        CGFloat(event.durationMinutes) / 60.0 * hourHeight
    }

    private var topOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    /// Generates consistent color from event title
    private var eventColor: Color {
        // Generate consistent color from event title hash
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

struct FocusBlockView: View {
    let block: FocusBlock
    let hourHeight: CGFloat
    let startHour: Int
    let column: Int
    let totalColumns: Int
    let containerWidth: CGFloat
    var onAddTask: ((String) -> Void)?
    var onTapBlock: (() -> Void)?
    var onTapEdit: (() -> Void)?

    @State private var isDropTargeted = false
    @State private var isHovered = false

    private let spacing: CGFloat = 2
    private let minHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with icon and title
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                Text(block.title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                Spacer()
                if isHovered || isDropTargeted {
                    Button {
                        onTapEdit?()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("focusBlockEditButton_\(block.id)")
                }
            }
            .foregroundStyle(.white)

            // Task count
            Text("\(block.taskIDs.count) Tasks")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))

            // Drop indicator
            if isDropTargeted {
                Label("Ablegen", systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(8)
        .frame(width: columnWidth, alignment: .leading)
        .frame(height: max(blockHeight, minHeight), alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(blockColor.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(isDropTargeted ? 0.5 : 0.2), lineWidth: isDropTargeted ? 2 : 1)
        )
        .shadow(color: blockColor.opacity(0.3), radius: isDropTargeted ? 8 : 4, y: 2)
        .offset(x: columnOffset, y: topOffset)
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

    private var columnWidth: CGFloat {
        let availableWidth = containerWidth - (CGFloat(totalColumns - 1) * spacing)
        return availableWidth / CGFloat(totalColumns)
    }

    private var columnOffset: CGFloat {
        CGFloat(column) * (columnWidth + spacing)
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

    private var blockHeight: CGFloat {
        CGFloat(block.durationMinutes) / 60.0 * hourHeight
    }

    private var topOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: block.startDate)
        let minute = calendar.component(.minute, from: block.startDate)
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
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

#Preview {
    MacTimelineView(
        date: Date(),
        events: [],
        focusBlocks: []
    )
    .frame(width: 400, height: 600)
}
