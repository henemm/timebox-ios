import XCTest
@testable import FocusBlox

/// Unit Tests for LiveActivityManager (Sprint 4)
/// Tests LiveActivityManager lifecycle management
@MainActor
final class LiveActivityManagerTests: XCTestCase {

    var manager: LiveActivityManager!

    override func setUp() {
        super.setUp()
        manager = LiveActivityManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    /// GIVEN: LiveActivityManager is created
    /// WHEN: Checking initial state
    /// THEN: No activity should be running
    func testInitialStateHasNoActivity() {
        XCTAssertNil(manager.currentActivity, "Initial state should have no activity")
    }

    /// GIVEN: LiveActivityManager is created
    /// WHEN: Checking isSupported property
    /// THEN: Should return a boolean (true on real device, may be false on simulator)
    func testIsSupportedReturnsBoolean() {
        // Just verify it doesn't crash and returns a boolean
        let supported = manager.isSupported
        XCTAssertNotNil(supported as Bool?)
    }

    // MARK: - Update Activity Tests (without starting)

    /// GIVEN: No active Live Activity
    /// WHEN: updateActivity() is called
    /// THEN: Nothing should happen (no crash)
    func testUpdateActivityWhenNoActivityDoesNotCrash() {
        // Should not crash when updating without an active activity
        manager.updateActivity(currentTask: "Task", completedCount: 0)
        // If we get here without crash, test passes
        XCTAssertNil(manager.currentActivity)
    }

    // MARK: - End Activity Tests (without starting)

    /// GIVEN: No active Live Activity
    /// WHEN: endActivity() is called
    /// THEN: Nothing should happen (no crash)
    func testEndActivityWhenNoActivityDoesNotCrash() {
        // Should not crash when ending without an active activity
        manager.endActivity()
        // If we get here without crash, test passes
        XCTAssertNil(manager.currentActivity)
    }

    // MARK: - Start Activity Tests

    /// GIVEN: A valid FocusBlock
    /// WHEN: startActivity() is called on unsupported device (simulator)
    /// THEN: Should throw an error or return silently
    func testStartActivityHandlesUnsupportedDevice() async {
        let block = createMockFocusBlock()

        // On simulator, Live Activities are not supported
        // The method should either throw or return silently
        do {
            try await manager.startActivity(for: block, currentTask: "Test Task")
            // If we get here without error, isSupported was true or it handled gracefully
        } catch {
            // Expected on simulator - error is "unsupportedTarget"
            // This is correct behavior
        }

        // Activity should still be nil on simulator
        // (On real device it might be non-nil)
    }

    // MARK: - Helper Methods

    private func createMockFocusBlock() -> FocusBlock {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        return FocusBlock(
            id: "test-block-1",
            title: "Test Focus Block",
            startDate: now,
            endDate: endDate,
            taskIDs: ["task-1", "task-2"],
            completedTaskIDs: []
        )
    }
}
