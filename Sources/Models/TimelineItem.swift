//
//  TimelineItem.swift
//  FocusBlox (Shared)
//
//  Unified time item for timeline collision detection.
//  Extracted from MacTimelineView for cross-platform use.
//
//  Created: 2026-03-04 (Bug 70c-1a)
//

import Foundation

// MARK: - Timeline Item

/// Unified time item for combined collision detection of events and focus blocks.
struct TimelineItem: Identifiable, Sendable {
    let id: String
    let startDate: Date
    let endDate: Date
    let type: ItemType

    enum ItemType: Sendable {
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

    init(id: String, startDate: Date, endDate: Date) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.type = .event(CalendarEvent(
            id: id,
            title: "",
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        ))
    }

    // MARK: - Collision Detection

    /// Groups items that overlap in time for side-by-side layout.
    /// Items within a group should be rendered in columns.
    static func groupOverlapping(_ items: [TimelineItem]) -> [[TimelineItem]] {
        guard !items.isEmpty else { return [] }

        let sorted = items.sorted { $0.startDate < $1.startDate }
        var groups: [[TimelineItem]] = []
        var currentGroup: [TimelineItem] = []
        var currentGroupEndTime: Date?

        for item in sorted {
            if let endTime = currentGroupEndTime, item.startDate < endTime {
                currentGroup.append(item)
                if item.endDate > endTime {
                    currentGroupEndTime = item.endDate
                }
            } else {
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
}

// MARK: - Positioned Items

/// Represents a positioned item with column information for side-by-side layout.
struct PositionedItem: Identifiable, Sendable {
    let id: String
    let item: TimelineItem
    let column: Int
    let totalColumns: Int
}

/// Represents a positioned calendar event with column information.
struct PositionedEvent: Identifiable, Sendable {
    let id: String
    let event: CalendarEvent
    let column: Int
    let totalColumns: Int
}
