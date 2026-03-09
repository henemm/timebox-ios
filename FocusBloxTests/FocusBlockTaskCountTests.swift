import XCTest
@testable import FocusBlox

/// Bug 83: Focus View shows "2/3 Tasks" but "Alle Tasks erledigt!" simultaneously.
/// Root cause: Counter denominator uses block.taskIDs.count (includes orphan IDs)
/// while "all completed" check uses tasksForBlock() which drops orphan IDs via compactMap.
///
/// Fix: Use resolvedTaskCount(knownTaskIDs:) everywhere instead of block.taskIDs.count
final class FocusBlockTaskCountTests: XCTestCase {

    // MARK: - Helper

    private func makeBlock(taskIDs: [String], completedTaskIDs: [String] = []) -> FocusBlock {
        FocusBlock(
            id: "block-1",
            title: "Test Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: taskIDs,
            completedTaskIDs: completedTaskIDs
        )
    }

    // MARK: - Tests: resolvedTaskCount (NEW method — should NOT compile yet = TDD RED)

    /// GIVEN: Block with 3 taskIDs, all 3 exist in knownTaskIDs
    /// WHEN: resolvedTaskCount is called
    /// THEN: Returns 3 (all tasks found)
    func test_resolvedTaskCount_allTasksExist_returnsFullCount() {
        let block = makeBlock(taskIDs: ["A", "B", "C"])
        let known: Set<String> = ["A", "B", "C"]

        let count = block.resolvedTaskCount(knownTaskIDs: known)

        XCTAssertEqual(count, 3)
    }

    /// GIVEN: Block with 3 taskIDs, only 2 exist (1 orphan)
    /// WHEN: resolvedTaskCount is called
    /// THEN: Returns 2 (orphan ID not counted)
    ///
    /// THIS IS THE BUG SCENARIO: block.taskIDs.count would return 3 here
    func test_resolvedTaskCount_oneOrphanTask_returnsOnlyExisting() {
        let block = makeBlock(taskIDs: ["A", "B", "C"])
        let known: Set<String> = ["A", "B"]
        // "C" is NOT known (deleted from SwiftData)

        let count = block.resolvedTaskCount(knownTaskIDs: known)

        XCTAssertEqual(count, 2, "Orphan task ID should NOT be counted in total")
    }

    /// GIVEN: Block with 3 taskIDs, none exist
    /// WHEN: resolvedTaskCount is called
    /// THEN: Returns 0
    func test_resolvedTaskCount_noTasksExist_returnsZero() {
        let block = makeBlock(taskIDs: ["A", "B", "C"])
        let known: Set<String> = []

        let count = block.resolvedTaskCount(knownTaskIDs: known)

        XCTAssertEqual(count, 0)
    }

    // MARK: - Tests: resolvedCompletedCount

    /// GIVEN: Block with 3 taskIDs, 2 completed, all exist
    /// WHEN: resolvedCompletedCount is called
    /// THEN: Returns 2
    func test_resolvedCompletedCount_allExist_returnsCorrectCount() {
        let block = makeBlock(taskIDs: ["A", "B", "C"], completedTaskIDs: ["A", "B"])
        let known: Set<String> = ["A", "B", "C"]

        let completed = block.resolvedCompletedCount(knownTaskIDs: known)

        XCTAssertEqual(completed, 2)
    }

    /// GIVEN: Block with 3 taskIDs, 2 completed, 1 orphan (the uncompleted one)
    /// WHEN: Both counts are computed
    /// THEN: total=2, completed=2, remaining=0 — CONSISTENT with "Alle erledigt!"
    ///
    /// THIS IS THE EXACT BUG SCENARIO from Henning's screenshot:
    /// Before fix: "2/3 Tasks" + "Alle erledigt!" (inconsistent)
    /// After fix:  "2/2 Tasks" + "Alle erledigt!" (consistent)
    func test_orphanTask_counterAndCompletedAreConsistent_Bug83() {
        let block = makeBlock(taskIDs: ["A", "B", "C"], completedTaskIDs: ["A", "B"])
        let known: Set<String> = ["A", "B"]
        // "C" deleted from SwiftData — the orphan

        let total = block.resolvedTaskCount(knownTaskIDs: known)
        let completed = block.resolvedCompletedCount(knownTaskIDs: known)
        let remaining = total - completed

        XCTAssertEqual(total, 2, "Total should only count existing tasks")
        XCTAssertEqual(completed, 2, "Both existing tasks are completed")
        XCTAssertEqual(remaining, 0, "No remaining tasks — consistent with 'Alle erledigt!'")
    }

    // MARK: - Edge cases

    /// GIVEN: Block with no tasks
    /// THEN: Both counts are 0
    func test_emptyBlock_zeroCounts() {
        let block = makeBlock(taskIDs: [])

        XCTAssertEqual(block.resolvedTaskCount(knownTaskIDs: []), 0)
        XCTAssertEqual(block.resolvedCompletedCount(knownTaskIDs: []), 0)
    }

    /// GIVEN: completedTaskIDs contains an ID not in taskIDs (stale data)
    /// THEN: That stale completed ID is not counted
    func test_staleCompletedID_notCounted() {
        let block = makeBlock(taskIDs: ["A"], completedTaskIDs: ["A", "X"])
        let known: Set<String> = ["A", "X"]

        let completed = block.resolvedCompletedCount(knownTaskIDs: known)

        XCTAssertEqual(completed, 1, "Only 'A' is both in taskIDs AND completed")
    }
}
