import XCTest
@testable import FocusBlox

/// Unit Tests for Live Activity Task Timer
/// Task 4: Live Activity zeigt Task-Restzeit statt Block-Restzeit
final class LiveActivityTaskTimerTests: XCTestCase {

    // MARK: - ContentState Tests

    /// GIVEN: A ContentState with taskEndDate
    /// WHEN: Created with task end date
    /// THEN: The taskEndDate should be stored correctly
    func testContentStateStoresTaskEndDate() {
        let now = Date()
        let taskEndDate = now.addingTimeInterval(15 * 60) // 15 minutes

        let state = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Test Task",
            completedCount: 1,
            taskEndDate: taskEndDate
        )

        XCTAssertEqual(state.taskEndDate, taskEndDate)
        XCTAssertEqual(state.currentTaskTitle, "Test Task")
        XCTAssertEqual(state.completedCount, 1)
    }

    /// GIVEN: A ContentState without taskEndDate
    /// WHEN: Created with nil taskEndDate
    /// THEN: The taskEndDate should be nil (fallback to block end)
    func testContentStateAllowsNilTaskEndDate() {
        let state = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Test Task",
            completedCount: 0,
            taskEndDate: nil
        )

        XCTAssertNil(state.taskEndDate)
    }

    /// GIVEN: A ContentState with taskEndDate
    /// WHEN: Default parameter is used
    /// THEN: The taskEndDate should default to nil
    func testContentStateDefaultTaskEndDateIsNil() {
        let state = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Test Task",
            completedCount: 0
        )

        XCTAssertNil(state.taskEndDate)
    }

    // MARK: - Task End Date Calculation Tests

    /// GIVEN: A task with 15 minute duration
    /// WHEN: Calculating task end date from current time
    /// THEN: End date should be 15 minutes from now
    func testTaskEndDateCalculation() {
        let startTime = Date()
        let taskDuration = 15 // minutes
        let expectedEndDate = startTime.addingTimeInterval(Double(taskDuration * 60))

        // Simulate the calculation done in FocusLiveView
        let calculatedEndDate = startTime.addingTimeInterval(Double(taskDuration * 60))

        XCTAssertEqual(
            calculatedEndDate.timeIntervalSince1970,
            expectedEndDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    /// GIVEN: A task that started 5 minutes ago with 15 minute duration
    /// WHEN: Calculating remaining time
    /// THEN: Should show 10 minutes remaining
    func testTaskRemainingTimeCalculation() {
        let taskStartTime = Date().addingTimeInterval(-5 * 60) // 5 minutes ago
        let taskDuration = 15 // minutes
        let taskEndDate = taskStartTime.addingTimeInterval(Double(taskDuration * 60))

        let now = Date()
        let remainingSeconds = taskEndDate.timeIntervalSince(now)
        let remainingMinutes = Int(remainingSeconds / 60)

        // Should be approximately 10 minutes (15 - 5)
        XCTAssertEqual(remainingMinutes, 10, accuracy: 1)
    }

    // MARK: - Attributes Tests

    /// GIVEN: FocusBlockActivityAttributes
    /// WHEN: Created for a focus block
    /// THEN: Should store block end date separately from task end date
    func testAttributesStoreBlockEndDate() {
        let now = Date()
        let blockEndDate = now.addingTimeInterval(60 * 60) // 1 hour block

        let attributes = FocusBlockActivityAttributes(
            blockTitle: "Focus Block",
            startDate: now,
            endDate: blockEndDate,
            totalTaskCount: 3
        )

        XCTAssertEqual(attributes.endDate, blockEndDate)
        XCTAssertEqual(attributes.blockTitle, "Focus Block")
        XCTAssertEqual(attributes.totalTaskCount, 3)
    }

    /// GIVEN: A block with task that ends before block ends
    /// WHEN: Comparing task end date to block end date
    /// THEN: Task end date should be earlier
    func testTaskEndDateIsBeforeBlockEndDate() {
        let now = Date()
        let blockEndDate = now.addingTimeInterval(60 * 60) // 1 hour block
        let taskEndDate = now.addingTimeInterval(15 * 60) // 15 min task

        XCTAssertTrue(taskEndDate < blockEndDate)
    }

    // MARK: - Codable Conformance

    /// GIVEN: A ContentState with taskEndDate
    /// WHEN: Encoded and decoded
    /// THEN: All values including taskEndDate should be preserved
    func testContentStateIsCodable() throws {
        let taskEndDate = Date().addingTimeInterval(15 * 60)
        let original = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Codable Test",
            completedCount: 2,
            taskEndDate: taskEndDate
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FocusBlockActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.currentTaskTitle, original.currentTaskTitle)
        XCTAssertEqual(decoded.completedCount, original.completedCount)
        XCTAssertEqual(
            decoded.taskEndDate?.timeIntervalSince1970,
            original.taskEndDate?.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    // MARK: - Hashable Conformance

    /// GIVEN: Two ContentStates with same values
    /// WHEN: Comparing for equality
    /// THEN: They should be equal and have same hash
    func testContentStateIsHashable() {
        let taskEndDate = Date()
        let state1 = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Task",
            completedCount: 1,
            taskEndDate: taskEndDate
        )
        let state2 = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Task",
            completedCount: 1,
            taskEndDate: taskEndDate
        )

        XCTAssertEqual(state1, state2)
        XCTAssertEqual(state1.hashValue, state2.hashValue)
    }
}
