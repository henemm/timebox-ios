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
