//
//  IOSTimelineCanvasTests.swift
//  FocusBloxTests
//
//  Unit tests for Bug 70c-1b: iOS Timeline Canvas Rebuild.
//  Tests the business logic for canvas-based timeline positioning.
//
//  Created: 2026-03-05
//

import XCTest
@testable import FocusBlox

final class IOSTimelineCanvasTests: XCTestCase {

    // MARK: - PositionedFocusBlock Shared Type

    /// Verhalten: PositionedFocusBlock existiert als shared Typ in TimelineItem.swift
    ///   und kann aus groupOverlapping-Ergebnis extrahiert werden.
    /// Bricht wenn: PositionedFocusBlock nicht in Sources/Models/TimelineItem.swift definiert ist
    func test_positionedFocusBlock_existsAsSharedType() {
        let block = FocusBlock(
            id: "test-block",
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: [],
            completedTaskIDs: []
        )

        // PositionedFocusBlock must be accessible from shared code (not private in MacTimelineView)
        let positioned = PositionedFocusBlock(
            id: block.id,
            block: block,
            column: 0,
            totalColumns: 1
        )

        XCTAssertEqual(positioned.id, "test-block")
        XCTAssertEqual(positioned.column, 0)
        XCTAssertEqual(positioned.totalColumns, 1)
        XCTAssertEqual(positioned.block.title, "Test")
    }

    // MARK: - FocusBlock → TimelineItem → PositionedFocusBlock Pipeline

    /// Verhalten: FocusBlocks + CalendarEvents werden zu TimelineItems kombiniert,
    ///   gruppiert, und als PositionedFocusBlocks extrahiert.
    /// Bricht wenn: Die Extraktion von PositionedFocusBlock aus PositionedItem nicht funktioniert
    func test_focusBlockPositioning_nonOverlapping_singleColumn() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let block1 = FocusBlock(
            id: "block-1",
            title: "Morning",
            startDate: cal.date(byAdding: .hour, value: 9, to: today)!,
            endDate: cal.date(byAdding: .hour, value: 11, to: today)!,
            taskIDs: [],
            completedTaskIDs: []
        )

        let block2 = FocusBlock(
            id: "block-2",
            title: "Afternoon",
            startDate: cal.date(byAdding: .hour, value: 14, to: today)!,
            endDate: cal.date(byAdding: .hour, value: 16, to: today)!,
            taskIDs: [],
            completedTaskIDs: []
        )

        let items: [TimelineItem] = [
            TimelineItem(block: block1),
            TimelineItem(block: block2)
        ]

        let groups = TimelineItem.groupOverlapping(items)

        // Non-overlapping → 2 separate groups
        XCTAssertEqual(groups.count, 2, "Non-overlapping blocks should be in separate groups")

        // Extract PositionedFocusBlocks (same logic as new positionedFocusBlocks computed var)
        var positioned: [PositionedFocusBlock] = []
        for group in groups {
            for (index, item) in group.enumerated() {
                if case .focusBlock(let block) = item.type {
                    positioned.append(PositionedFocusBlock(
                        id: item.id,
                        block: block,
                        column: index,
                        totalColumns: group.count
                    ))
                }
            }
        }

        XCTAssertEqual(positioned.count, 2)
        XCTAssertEqual(positioned[0].totalColumns, 1, "Non-overlapping block should have 1 column")
        XCTAssertEqual(positioned[1].totalColumns, 1, "Non-overlapping block should have 1 column")
    }

    /// Verhalten: Ueberlappende FocusBlock + CalendarEvent werden in Spalten aufgeteilt.
    /// Bricht wenn: groupOverlapping() oder PositionedFocusBlock-Extraktion nicht korrekt
    func test_focusBlockPositioning_overlapping_multipleColumns() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Block: 09:00-11:00
        let block = FocusBlock(
            id: "block-overlap",
            title: "Focus",
            startDate: cal.date(byAdding: .hour, value: 9, to: today)!,
            endDate: cal.date(byAdding: .hour, value: 11, to: today)!,
            taskIDs: [],
            completedTaskIDs: []
        )

        // Event: 10:00-11:00 (overlaps with block)
        let event = CalendarEvent(
            id: "event-overlap",
            title: "Meeting",
            startDate: cal.date(byAdding: .hour, value: 10, to: today)!,
            endDate: cal.date(byAdding: .hour, value: 11, to: today)!,
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )

        let items: [TimelineItem] = [
            TimelineItem(block: block),
            TimelineItem(event: event)
        ]

        let groups = TimelineItem.groupOverlapping(items)

        // Overlapping → 1 group with 2 items
        XCTAssertEqual(groups.count, 1, "Overlapping items should be in one group")
        XCTAssertEqual(groups[0].count, 2, "Group should contain 2 overlapping items")

        // Extract positioned items
        var positionedBlocks: [PositionedFocusBlock] = []
        var positionedEvents: [PositionedEvent] = []
        for group in groups {
            for (index, item) in group.enumerated() {
                switch item.type {
                case .focusBlock(let b):
                    positionedBlocks.append(PositionedFocusBlock(
                        id: item.id, block: b,
                        column: index, totalColumns: group.count
                    ))
                case .event(let e):
                    positionedEvents.append(PositionedEvent(
                        id: item.id, event: e,
                        column: index, totalColumns: group.count
                    ))
                }
            }
        }

        XCTAssertEqual(positionedBlocks.count, 1)
        XCTAssertEqual(positionedBlocks[0].totalColumns, 2, "Block in overlap group should have 2 columns")
        XCTAssertEqual(positionedBlocks[0].column, 0, "Block starts earlier → column 0")

        XCTAssertEqual(positionedEvents.count, 1)
        XCTAssertEqual(positionedEvents[0].totalColumns, 2, "Event in overlap group should have 2 columns")
        XCTAssertEqual(positionedEvents[0].column, 1, "Event starts later → column 1")
    }

    // MARK: - calculateTimeFromLocation

    /// Verhalten: Y-Position auf der Timeline → korrekte Uhrzeit.
    ///   180pt bei hourHeight=60 und startHour=6 → 09:00
    /// Bricht wenn: calculateTimeFromLocation() in BlockPlanningView nicht existiert oder falsch rechnet
    func test_calculateTimeFromLocation_standardPosition() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Y=180 with hourHeight=60, startHour=6 → 3 hours from start → 09:00
        let result = TimelineLocationCalculator.timeFromLocation(
            y: 180,
            hourHeight: 60,
            startHour: 6,
            referenceDate: today
        )

        let hour = cal.component(.hour, from: result)
        let minute = cal.component(.minute, from: result)

        XCTAssertEqual(hour, 9, "Y=180 should map to hour 9")
        XCTAssertEqual(minute, 0, "Y=180 should map to minute 0")
    }

    /// Verhalten: Y-Position mit Minutenanteil → auf 15-Min gerundet.
    ///   210pt bei hourHeight=60, startHour=6 → 09:30 (halbe Stunde = 30pt)
    /// Bricht wenn: 15-Minuten-Snapping fehlt oder falsch implementiert
    func test_calculateTimeFromLocation_halfHour() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Y=210 → 3.5 hours from start → 09:30
        let result = TimelineLocationCalculator.timeFromLocation(
            y: 210,
            hourHeight: 60,
            startHour: 6,
            referenceDate: today
        )

        let hour = cal.component(.hour, from: result)
        let minute = cal.component(.minute, from: result)

        XCTAssertEqual(hour, 9, "Y=210 should map to hour 9")
        XCTAssertEqual(minute, 30, "Y=210 should map to minute 30")
    }

    /// Verhalten: Y-Position mit unrundem Minutenanteil → auf naechste 15-Min gerundet.
    ///   195pt → 09:15 (15 Min = 15pt)
    /// Bricht wenn: Snapping-to-quarter-hour nicht funktioniert
    func test_calculateTimeFromLocation_snapsToQuarterHour() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Y=200 → 3.33 hours → 09:20 → should snap to 09:15
        let result = TimelineLocationCalculator.timeFromLocation(
            y: 200,
            hourHeight: 60,
            startHour: 6,
            referenceDate: today
        )

        let minute = cal.component(.minute, from: result)
        XCTAssertTrue(
            minute % 15 == 0,
            "Minutes should be snapped to quarter hour, got \(minute)"
        )
    }

    /// Verhalten: Y-Position am Anfang der Timeline → startHour (06:00)
    /// Bricht wenn: Clamping am Anfang fehlt
    func test_calculateTimeFromLocation_topOfTimeline() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let result = TimelineLocationCalculator.timeFromLocation(
            y: 0,
            hourHeight: 60,
            startHour: 6,
            referenceDate: today
        )

        let hour = cal.component(.hour, from: result)
        XCTAssertEqual(hour, 6, "Y=0 should map to startHour (6)")
    }

    /// Verhalten: Negative Y-Position → clamped auf startHour
    /// Bricht wenn: Clamping fuer negative Werte fehlt
    func test_calculateTimeFromLocation_negativeY_clamped() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let result = TimelineLocationCalculator.timeFromLocation(
            y: -50,
            hourHeight: 60,
            startHour: 6,
            referenceDate: today
        )

        let hour = cal.component(.hour, from: result)
        XCTAssertGreaterThanOrEqual(hour, 6, "Negative Y should clamp to startHour")
    }
}
