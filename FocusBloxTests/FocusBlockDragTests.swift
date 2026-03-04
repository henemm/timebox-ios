import XCTest
@testable import FocusBlox

/// Tests for Bug 70b: FocusBlock Drag & Drop on Timeline
/// Verifies CalendarEventTransfer.init(from: FocusBlock) and move logic.
///
/// TDD RED: These tests FAIL because CalendarEventTransfer.init(from: FocusBlock)
/// does not exist yet.
final class FocusBlockDragTests: XCTestCase {

    private let calendar = Calendar.current

    private func makeFocusBlock(
        id: String = "test-block",
        title: String = "Test Block",
        hour: Int = 14,
        durationMinutes: Int = 120,
        taskIDs: [String] = ["task-1", "task-2"]
    ) -> FocusBlock {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .hour, value: hour, to: today)!
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start)!
        return FocusBlock(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            taskIDs: taskIDs,
            completedTaskIDs: []
        )
    }

    // MARK: - CalendarEventTransfer from FocusBlock

    /// CalendarEventTransfer.init(from: FocusBlock) preserves the block's calendar event ID
    func test_transferFromFocusBlock_preservesID() {
        let block = makeFocusBlock(id: "my-block-123")
        let transfer = CalendarEventTransfer(from: block)
        XCTAssertEqual(transfer.id, "my-block-123")
    }

    /// CalendarEventTransfer.init(from: FocusBlock) preserves the block title
    func test_transferFromFocusBlock_preservesTitle() {
        let block = makeFocusBlock(title: "Deep Work 14:00")
        let transfer = CalendarEventTransfer(from: block)
        XCTAssertEqual(transfer.title, "Deep Work 14:00")
    }

    /// CalendarEventTransfer.init(from: FocusBlock) calculates duration correctly
    func test_transferFromFocusBlock_preservesDuration() {
        let block = makeFocusBlock(durationMinutes: 90)
        let transfer = CalendarEventTransfer(from: block)
        XCTAssertEqual(transfer.duration, 90)
    }

    /// FocusBlocks have no associated reminder — reminderID must be nil
    func test_transferFromFocusBlock_hasNilReminderID() {
        let block = makeFocusBlock()
        let transfer = CalendarEventTransfer(from: block)
        XCTAssertNil(transfer.reminderID)
    }

    // MARK: - Move Logic (Duration Preservation)

    /// Moving a block preserves its duration: newEnd = newStart + originalDuration
    func test_movePreservesDuration() {
        let block = makeFocusBlock(hour: 14, durationMinutes: 120)
        let originalDuration = block.durationMinutes

        // Simulate move to 10:00
        let today = calendar.startOfDay(for: Date())
        let newStart = calendar.date(byAdding: .hour, value: 10, to: today)!
        let newEnd = calendar.date(byAdding: .minute, value: originalDuration, to: newStart)!

        // Duration must be preserved
        let newDuration = Int(newEnd.timeIntervalSince(newStart) / 60)
        XCTAssertEqual(newDuration, 120, "Duration must be preserved after move")
    }

    /// Moving a block applies 15-minute snapping to the new start time
    func test_moveAppliesSnapping() {
        let today = calendar.startOfDay(for: Date())
        // Simulate drop at 10:13 — should snap to 10:15
        let rawDropTime = calendar.date(bySettingHour: 10, minute: 13, second: 0, of: today)!
        let snapped = FocusBlock.snapToQuarterHour(rawDropTime)

        let comps = calendar.dateComponents([.hour, .minute], from: snapped)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 15, "Drop time should snap to nearest 15-min boundary")
    }

    // MARK: - Draggability Constraints

    /// Only future blocks should be draggable — active blocks must not move
    func test_activeBlockIsNotFuture() {
        let now = Date()
        let start = calendar.date(byAdding: .minute, value: -30, to: now)!
        let end = calendar.date(byAdding: .minute, value: 30, to: now)!
        let block = FocusBlock(id: "active", title: "Active", startDate: start, endDate: end, taskIDs: [])
        XCTAssertTrue(block.isActive)
        XCTAssertFalse(block.isFuture, "Active blocks must not be considered future")
    }

    /// Only future blocks should be draggable — past blocks must not move
    func test_pastBlockIsNotFuture() {
        let now = Date()
        let start = calendar.date(byAdding: .hour, value: -3, to: now)!
        let end = calendar.date(byAdding: .hour, value: -1, to: now)!
        let block = FocusBlock(id: "past", title: "Past", startDate: start, endDate: end, taskIDs: [])
        XCTAssertTrue(block.isPast)
        XCTAssertFalse(block.isFuture, "Past blocks must not be considered future")
    }

    /// Future blocks ARE draggable
    func test_futureBlockIsFuture() {
        let now = Date()
        let start = calendar.date(byAdding: .hour, value: 2, to: now)!
        let end = calendar.date(byAdding: .hour, value: 4, to: now)!
        let block = FocusBlock(id: "future", title: "Future", startDate: start, endDate: end, taskIDs: [])
        XCTAssertTrue(block.isFuture, "Future blocks should be draggable")
    }

    // MARK: - Mock Repository Tracking

    /// MockEventKitRepository.updateFocusBlockTime should track the call
    func test_mockRepository_tracksFocusBlockTimeUpdate() {
        let mock = MockEventKitRepository()
        mock.mockCalendarAuthStatus = .fullAccess

        let today = calendar.startOfDay(for: Date())
        let newStart = calendar.date(byAdding: .hour, value: 16, to: today)!
        let newEnd = calendar.date(byAdding: .hour, value: 18, to: today)!

        XCTAssertNoThrow(try mock.updateFocusBlockTime(eventID: "block-1", startDate: newStart, endDate: newEnd))

        // After implementation, mock should track the last updated block ID and times
        XCTAssertEqual(mock.lastUpdatedFocusBlockID, "block-1", "Mock should track updateFocusBlockTime calls")
        XCTAssertEqual(mock.lastUpdatedFocusBlockStart, newStart)
        XCTAssertEqual(mock.lastUpdatedFocusBlockEnd, newEnd)
    }
}
