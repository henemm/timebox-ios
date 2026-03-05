//
//  TimelineLayout.swift
//  FocusBlox (Shared)
//
//  Custom Layout Protocol for Timeline positioning.
//  Uses place() instead of offset() for correct hit-testing.
//  Shared between iOS and macOS.
//
//  Created: 2026-02-04
//  Moved to Sources/: 2026-03-04 (Bug 70c-1a)
//

import SwiftUI

// MARK: - Layout Value Keys

/// LayoutValueKey for hour position (0-23)
struct TimelineHourKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

/// LayoutValueKey for minute position (0-59)
struct TimelineMinuteKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

/// LayoutValueKey for block height in minutes
struct TimelineDurationKey: LayoutValueKey {
    static let defaultValue: Int = 60
}

/// LayoutValueKey for column index (for side-by-side layout)
struct TimelineColumnKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

/// LayoutValueKey for total columns count
struct TimelineTotalColumnsKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

/// LayoutValueKey for custom width (optional, for specific width)
struct TimelineWidthKey: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

// MARK: - View Extension

extension View {
    /// Sets the timeline position for this view using LayoutValueKeys.
    /// The TimelineLayout will use these values to position the view correctly.
    func timelinePosition(hour: Int, minute: Int, durationMinutes: Int = 60) -> some View {
        self
            .layoutValue(key: TimelineHourKey.self, value: hour)
            .layoutValue(key: TimelineMinuteKey.self, value: minute)
            .layoutValue(key: TimelineDurationKey.self, value: durationMinutes)
    }

    /// Sets the timeline position with column information for side-by-side layout.
    func timelinePosition(
        hour: Int,
        minute: Int,
        durationMinutes: Int = 60,
        column: Int,
        totalColumns: Int
    ) -> some View {
        self
            .layoutValue(key: TimelineHourKey.self, value: hour)
            .layoutValue(key: TimelineMinuteKey.self, value: minute)
            .layoutValue(key: TimelineDurationKey.self, value: durationMinutes)
            .layoutValue(key: TimelineColumnKey.self, value: column)
            .layoutValue(key: TimelineTotalColumnsKey.self, value: totalColumns)
    }
}

// MARK: - Timeline Layout

/// Custom Layout that positions views based on time.
/// Uses place() for correct hit-testing (unlike offset()).
///
/// Usage:
/// ```swift
/// TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22) {
///     ForEach(blocks) { block in
///         BlockView(block: block)
///             .timelinePosition(hour: block.startHour, minute: block.startMinute)
///     }
/// }
/// ```
struct TimelineLayout: Layout {
    /// Height in points per hour
    let hourHeight: CGFloat

    /// First hour to display (e.g., 6 for 06:00)
    let startHour: Int

    /// Last hour to display (e.g., 22 for 22:00)
    let endHour: Int

    // MARK: - Layout Protocol

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let totalHours = endHour - startHour
        let height = CGFloat(totalHours) * hourHeight

        return CGSize(
            width: proposal.width ?? 400,
            height: height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let spacing: CGFloat = 2

        for subview in subviews {
            let hour = subview[TimelineHourKey.self]
            let minute = subview[TimelineMinuteKey.self]
            let duration = subview[TimelineDurationKey.self]
            let column = subview[TimelineColumnKey.self]
            let totalColumns = subview[TimelineTotalColumnsKey.self]

            let y = calculateYPosition(hour: hour, minute: minute)
            let height = calculateBlockHeight(durationMinutes: duration)

            let availableWidth = bounds.width - (CGFloat(totalColumns - 1) * spacing)
            let columnWidth = availableWidth / CGFloat(totalColumns)
            let x = CGFloat(column) * (columnWidth + spacing)

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: height)
            )
        }
    }

    // MARK: - Helper Methods

    func calculateYPosition(hour: Int, minute: Int) -> CGFloat {
        let hoursFromStart = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return hoursFromStart * hourHeight
    }

    func calculateBlockHeight(durationMinutes: Int) -> CGFloat {
        return CGFloat(durationMinutes) / 60.0 * hourHeight
    }
}
