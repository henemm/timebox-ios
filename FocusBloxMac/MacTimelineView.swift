//
//  MacTimelineView.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import SwiftUI

/// Timeline view showing calendar events and focus blocks for a day
struct MacTimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    var onCreateFocusBlock: ((Date, Int, String) -> Void)?
    var onAddTaskToBlock: ((String, String) -> Void)?

    // Timeline configuration
    private let startHour = 6
    private let endHour = 22
    private let hourHeight: CGFloat = 60

    // Drop target state
    @State private var isDropTargeted = false
    @State private var dropLocation: CGPoint = .zero

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Hour grid background
                hourGrid

                // Drop preview indicator
                if isDropTargeted {
                    DropPreviewIndicator(
                        location: dropLocation,
                        hourHeight: hourHeight,
                        startHour: startHour,
                        date: date
                    )
                    .padding(.leading, 50)
                }

                // Regular calendar events (readonly)
                ForEach(regularEvents) { event in
                    EventBlockView(
                        event: event,
                        hourHeight: hourHeight,
                        startHour: startHour
                    )
                }

                // Focus blocks (interactive)
                ForEach(focusBlocks) { block in
                    FocusBlockView(
                        block: block,
                        hourHeight: hourHeight,
                        startHour: startHour,
                        onAddTask: { taskID in
                            onAddTaskToBlock?(block.id, taskID)
                        }
                    )
                }

                // Current time indicator
                if Calendar.current.isDateInToday(date) {
                    CurrentTimeIndicator(hourHeight: hourHeight, startHour: startHour)
                }
            }
            .frame(height: totalHeight)
            .padding(.leading, 50) // Space for hour labels
        }
        .background(Color(nsColor: .textBackgroundColor))
        .dropDestination(for: MacTaskTransfer.self) { items, location in
            guard let task = items.first else { return false }
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

    // MARK: - Time Calculation

    private func calculateTimeFromLocation(_ location: CGPoint) -> Date {
        // Account for left padding (50pt for hour labels)
        let adjustedY = location.y
        let hoursFromStart = adjustedY / hourHeight
        let hour = Int(hoursFromStart) + startHour
        let minute = Int((hoursFromStart - floor(hoursFromStart)) * 60)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = min(max(hour, startHour), endHour - 1)
        components.minute = (minute / 15) * 15  // Round to 15 min intervals

        return Calendar.current.date(from: components) ?? date
    }

    // Filter out focus blocks from regular events
    private var regularEvents: [CalendarEvent] {
        events.filter { !$0.isFocusBlock }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    // Hour label
                    Text(hourLabel(hour))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)

                    // Grid line
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
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

// MARK: - Event Block View (readonly calendar events)

struct EventBlockView: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    let startHour: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(timeRange)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(6),
                alignment: .topLeading
            )
            .frame(height: blockHeight)
            .offset(y: topOffset)
            .padding(.horizontal, 4)
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
}

// MARK: - Focus Block View (interactive)

struct FocusBlockView: View {
    let block: FocusBlock
    let hourHeight: CGFloat
    let startHour: Int
    var onAddTask: ((String) -> Void)?

    @State private var isDropTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(blockColor.opacity(isDropTargeted ? 0.4 : 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(blockColor, lineWidth: isDropTargeted ? 3 : 2)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "target")
                            .font(.caption)
                        Text(block.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(blockColor)

                    Text("\(block.taskIDs.count) Tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isDropTargeted {
                        Label("Hier ablegen", systemImage: "plus.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(blockColor)
                    }
                }
                .padding(8),
                alignment: .topLeading
            )
            .frame(height: blockHeight)
            .offset(y: topOffset)
            .padding(.horizontal, 4)
            .dropDestination(for: MacTaskTransfer.self) { items, _ in
                guard let task = items.first else { return false }
                onAddTask?(task.id)
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTargeted = targeted
                }
            }
    }

    private var blockColor: Color {
        if block.isActive {
            return .green
        } else if block.isPast {
            return .gray
        } else {
            return .blue
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
