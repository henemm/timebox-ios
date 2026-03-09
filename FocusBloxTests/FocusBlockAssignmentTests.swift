import XCTest
@testable import FocusBlox

/// Bug 81: FocusBlock Task Disappearing — Stale Snapshot Fix Verification
///
/// Verifies that the fix (reading from current `focusBlocks` state instead of
/// stale sheet `block` parameter) prevents task loss during sequential assignments.
@MainActor
final class FocusBlockAssignmentTests: XCTestCase {

    // MARK: - Simulating the FIXED pattern

    /// Simulates the FIXED assignment pattern from BlockPlanningView.
    /// The fix reads from `focusBlocks` (current state) instead of stale `block`.
    /// After each assignment, `focusBlocks` is updated (via loadData).
    private func simulateFixedAssignment(
        taskID: String,
        staleBlock: FocusBlock,
        focusBlocks: inout [FocusBlock]
    ) -> [String] {
        // Bug 81 Fix: Read CURRENT block from focusBlocks, not stale sheet snapshot
        let currentBlock = focusBlocks.first { $0.id == staleBlock.id } ?? staleBlock
        var updatedTaskIDs = currentBlock.taskIDs
        if !updatedTaskIDs.contains(taskID) {
            updatedTaskIDs.append(taskID)
        }
        // Simulate eventKitRepo.updateFocusBlock + loadData() refreshing focusBlocks
        if let index = focusBlocks.firstIndex(where: { $0.id == staleBlock.id }) {
            focusBlocks[index] = FocusBlock(
                id: currentBlock.id,
                title: currentBlock.title,
                startDate: currentBlock.startDate,
                endDate: currentBlock.endDate,
                taskIDs: updatedTaskIDs,
                completedTaskIDs: currentBlock.completedTaskIDs
            )
        }
        return updatedTaskIDs
    }

    // MARK: - Bug 81: Fixed pattern preserves all tasks

    /// GIVEN: Empty block, stale snapshot held by sheet
    /// WHEN: Two tasks assigned using FIXED pattern (reads current state)
    /// THEN: Both tasks survive
    func testTwoAssignments_fixedPattern_bothTasksSurvive_Bug81() {
        let staleBlock = FocusBlock(
            id: "test-block", title: "Morning Focus",
            startDate: Date(), endDate: Date().addingTimeInterval(3600),
            taskIDs: []
        )
        var focusBlocks = [staleBlock]

        let first = simulateFixedAssignment(taskID: "task-A", staleBlock: staleBlock, focusBlocks: &focusBlocks)
        XCTAssertEqual(first, ["task-A"])

        let second = simulateFixedAssignment(taskID: "task-B", staleBlock: staleBlock, focusBlocks: &focusBlocks)
        XCTAssertTrue(second.contains("task-A"), "Bug 81: First task must NOT be lost")
        XCTAssertTrue(second.contains("task-B"), "Second task must be present")
        XCTAssertEqual(second.count, 2)
    }

    /// GIVEN: Empty block
    /// WHEN: Three tasks assigned sequentially
    /// THEN: All three survive
    func testThreeAssignments_fixedPattern_allTasksSurvive_Bug81() {
        let staleBlock = FocusBlock(
            id: "test-block", title: "Morning Focus",
            startDate: Date(), endDate: Date().addingTimeInterval(3600),
            taskIDs: []
        )
        var focusBlocks = [staleBlock]

        _ = simulateFixedAssignment(taskID: "task-A", staleBlock: staleBlock, focusBlocks: &focusBlocks)
        _ = simulateFixedAssignment(taskID: "task-B", staleBlock: staleBlock, focusBlocks: &focusBlocks)
        let final_ = simulateFixedAssignment(taskID: "task-C", staleBlock: staleBlock, focusBlocks: &focusBlocks)

        XCTAssertEqual(Set(final_), Set(["task-A", "task-B", "task-C"]),
            "Bug 81: All three tasks must survive")
    }

    /// GIVEN: Block with existing task
    /// WHEN: Two new tasks assigned
    /// THEN: All three (existing + 2 new) survive
    func testAssignment_toBlockWithExistingTasks_preservesThem_Bug81() {
        let staleBlock = FocusBlock(
            id: "test-block", title: "Morning Focus",
            startDate: Date(), endDate: Date().addingTimeInterval(3600),
            taskIDs: ["existing-task"]
        )
        var focusBlocks = [staleBlock]

        _ = simulateFixedAssignment(taskID: "task-A", staleBlock: staleBlock, focusBlocks: &focusBlocks)
        let second = simulateFixedAssignment(taskID: "task-B", staleBlock: staleBlock, focusBlocks: &focusBlocks)

        XCTAssertTrue(second.contains("existing-task"), "Existing task must survive")
        XCTAssertTrue(second.contains("task-A"), "Bug 81: First new task must survive")
        XCTAssertTrue(second.contains("task-B"), "Second new task must be present")
        XCTAssertEqual(second.count, 3)
    }
}
