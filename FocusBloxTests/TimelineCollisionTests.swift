//
//  TimelineCollisionTests.swift
//  FocusBloxTests
//
//  Tests for shared timeline collision detection logic.
//  Bug 70c-1a: Extracted from MacTimelineView into Sources/.
//

import XCTest
@testable import FocusBlox

final class TimelineCollisionTests: XCTestCase {

    // MARK: - Helper

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return cal.date(from: comps)!
    }

    private func makeItem(id: String, startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) -> TimelineItem {
        TimelineItem(
            id: id,
            startDate: makeDate(hour: startHour, minute: startMinute),
            endDate: makeDate(hour: endHour, minute: endMinute)
        )
    }

    // MARK: - groupOverlappingItems Tests

    func test_emptyItems_returnsEmptyGroups() {
        let result = TimelineItem.groupOverlapping([])
        XCTAssertTrue(result.isEmpty)
    }

    func test_singleItem_returnsSingleGroup() {
        let items = [makeItem(id: "a", startHour: 9, endHour: 10)]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 1)
        XCTAssertEqual(result[0][0].id, "a")
    }

    func test_nonOverlapping_returnsSeparateGroups() {
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 10),
            makeItem(id: "b", startHour: 11, endHour: 12)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 2)
    }

    func test_overlapping_returnsSingleGroup() {
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 11),
            makeItem(id: "b", startHour: 10, endHour: 12)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 2)
    }

    func test_threeOverlapping_allInOneGroup() {
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 11),
            makeItem(id: "b", startHour: 10, endHour: 12),
            makeItem(id: "c", startHour: 10, startMinute: 30, endHour: 11, endMinute: 30)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 3)
    }

    func test_adjacentButNotOverlapping_separateGroups() {
        // Block A: 9:00-10:00, Block B: 10:00-11:00 (adjacent, NOT overlapping)
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 10),
            makeItem(id: "b", startHour: 10, endHour: 11)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 2, "Adjacent blocks should NOT overlap")
    }

    func test_unsortedInput_sortsCorrectly() {
        // Items given in reverse order — algorithm should sort by startDate
        let items = [
            makeItem(id: "c", startHour: 14, endHour: 15),
            makeItem(id: "a", startHour: 9, endHour: 10),
            makeItem(id: "b", startHour: 11, endHour: 12)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0][0].id, "a")
        XCTAssertEqual(result[1][0].id, "b")
        XCTAssertEqual(result[2][0].id, "c")
    }

    func test_chainOverlap_allInOneGroup() {
        // A overlaps B, B overlaps C, but A does NOT overlap C
        // Still one group because chain-connected
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 10, endMinute: 30),
            makeItem(id: "b", startHour: 10, endHour: 11, endMinute: 30),
            makeItem(id: "c", startHour: 11, endHour: 12)
        ]
        let result = TimelineItem.groupOverlapping(items)
        XCTAssertEqual(result.count, 1, "Chain-overlapping items should form one group")
        XCTAssertEqual(result[0].count, 3)
    }

    // MARK: - Greedy Column Assignment Tests

    func test_assignColumns_singleItem_getsColumn0() {
        let items = [makeItem(id: "a", startHour: 9, endHour: 10)]
        let result = TimelineItem.assignColumns(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].column, 0)
        XCTAssertEqual(result[0].totalColumns, 1)
    }

    func test_assignColumns_twoOverlapping_getSeparateColumns() {
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 11),
            makeItem(id: "b", startHour: 10, endHour: 12)
        ]
        let result = TimelineItem.assignColumns(items)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].column, 0)
        XCTAssertEqual(result[1].column, 1)
        XCTAssertEqual(result[0].totalColumns, 2)
        XCTAssertEqual(result[1].totalColumns, 2)
    }

    func test_assignColumns_longEventWithShortOnes_sharesColumns() {
        // Scenario from bug: Steffi Praxis (08:00-12:00) spans multiple shorter events
        // Shorter events that DON'T overlap each other should share a column
        let items = [
            makeItem(id: "steffi", startHour: 8, endHour: 12),          // 08:00-12:00
            makeItem(id: "focus", startHour: 8, startMinute: 45, endHour: 9, endMinute: 45), // 08:45-09:45
            makeItem(id: "henning", startHour: 10, endHour: 10, endMinute: 20),   // 10:00-10:20
            makeItem(id: "ivo", startHour: 11, endHour: 11, endMinute: 25)        // 11:00-11:25
        ]
        let result = TimelineItem.assignColumns(items)

        // Steffi in column 0 (starts first)
        let steffi = result.first { $0.item.id == "steffi" }!
        XCTAssertEqual(steffi.column, 0)

        // FocusBlox overlaps Steffi → column 1
        let focus = result.first { $0.item.id == "focus" }!
        XCTAssertEqual(focus.column, 1)

        // Henning doesn't overlap FocusBlox (09:45 < 10:00) → reuse column 1
        let henning = result.first { $0.item.id == "henning" }!
        XCTAssertEqual(henning.column, 1)

        // Ivo doesn't overlap Henning (10:20 < 11:00) → reuse column 1
        let ivo = result.first { $0.item.id == "ivo" }!
        XCTAssertEqual(ivo.column, 1)

        // Only 2 columns needed, not 4
        XCTAssertEqual(steffi.totalColumns, 2)
        XCTAssertEqual(focus.totalColumns, 2)
    }

    func test_assignColumns_threeDirectlyOverlapping_threeColumns() {
        // All three events overlap at the same time → 3 separate columns
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 11),
            makeItem(id: "b", startHour: 9, startMinute: 30, endHour: 10, endMinute: 30),
            makeItem(id: "c", startHour: 10, endHour: 11, endMinute: 30)
        ]
        let result = TimelineItem.assignColumns(items)
        // a overlaps b, a overlaps c, b overlaps c → all 3 need separate columns
        XCTAssertEqual(result.first { $0.item.id == "a" }!.column, 0)
        XCTAssertEqual(result.first { $0.item.id == "b" }!.column, 1)
        XCTAssertEqual(result.first { $0.item.id == "c" }!.column, 2)
        XCTAssertEqual(result[0].totalColumns, 3)
    }

    func test_assignColumns_nonOverlapping_allColumn0() {
        let items = [
            makeItem(id: "a", startHour: 9, endHour: 10),
            makeItem(id: "b", startHour: 11, endHour: 12),
            makeItem(id: "c", startHour: 13, endHour: 14)
        ]
        let result = TimelineItem.assignColumns(items)
        // No overlaps → all in column 0
        XCTAssertEqual(result[0].column, 0)
        XCTAssertEqual(result[1].column, 0)
        XCTAssertEqual(result[2].column, 0)
        XCTAssertEqual(result[0].totalColumns, 1)
    }

    func test_assignColumns_sortsInputByStartDate() {
        // Input in reverse order — should still work correctly
        let items = [
            makeItem(id: "b", startHour: 10, endHour: 11),
            makeItem(id: "a", startHour: 9, endHour: 10, endMinute: 30)
        ]
        let result = TimelineItem.assignColumns(items)
        let a = result.first { $0.item.id == "a" }!
        let b = result.first { $0.item.id == "b" }!
        XCTAssertEqual(a.column, 0)
        XCTAssertEqual(b.column, 1)
        XCTAssertEqual(a.totalColumns, 2)
    }

    // MARK: - TimelineLayout Calculation Tests

    func test_calculateYPosition_atStartHour() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let y = layout.calculateYPosition(hour: 6, minute: 0)
        XCTAssertEqual(y, 0)
    }

    func test_calculateYPosition_oneHourIn() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let y = layout.calculateYPosition(hour: 7, minute: 0)
        XCTAssertEqual(y, 60)
    }

    func test_calculateYPosition_withMinutes() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let y = layout.calculateYPosition(hour: 9, minute: 30)
        XCTAssertEqual(y, 210) // (9-6)*60 + 30/60*60 = 180+30
    }

    func test_calculateBlockHeight_60min() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let h = layout.calculateBlockHeight(durationMinutes: 60)
        XCTAssertEqual(h, 60)
    }

    func test_calculateBlockHeight_15min() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let h = layout.calculateBlockHeight(durationMinutes: 15)
        XCTAssertEqual(h, 15)
    }

    func test_calculateBlockHeight_90min() {
        let layout = TimelineLayout(hourHeight: 60, startHour: 6, endHour: 22)
        let h = layout.calculateBlockHeight(durationMinutes: 90)
        XCTAssertEqual(h, 90)
    }
}
