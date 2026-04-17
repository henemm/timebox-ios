import XCTest
import SwiftData
@testable import FocusBlox

/// Tests for BUG: Crash when Dictionary(uniqueKeysWithValues:) encounters duplicate Task UUIDs.
/// Root cause: CloudKit sync can create duplicate LocalTask entries with the same UUID.
/// All crash sites must handle duplicates gracefully instead of crashing.
@MainActor
final class DuplicateKeysCrashTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - ReviewStatsCalculator (Primary crash site — CoachView Tagesrückblick)

    /// computePlanningAccuracy must not crash when allTasks contains duplicate IDs.
    /// This is the exact crash the user reported: Fatal error: Duplicate values for key.
    func test_computePlanningAccuracy_withDuplicateTaskIDs_doesNotCrash() throws {
        let context = container.mainContext
        let sharedUUID = UUID()

        // Create two LocalTasks with the SAME UUID (simulates CloudKit sync duplicate)
        let task1 = LocalTask(title: "Task A", importance: 2)
        task1.uuid = sharedUUID
        task1.estimatedDuration = 30
        context.insert(task1)

        let task2 = LocalTask(title: "Task A copy", importance: 2)
        task2.uuid = sharedUUID
        task2.estimatedDuration = 30
        context.insert(task2)

        let uniqueTask = LocalTask(title: "Task B", importance: 1)
        uniqueTask.estimatedDuration = 15
        context.insert(uniqueTask)

        let planItems = [task1, task2, uniqueTask].map { PlanItem(localTask: $0) }
        let duplicateID = sharedUUID.uuidString

        let block = FocusBlock(
            id: "block-1",
            title: "Morning Focus",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: [duplicateID, uniqueTask.id],
            completedTaskIDs: [],
            taskTimes: [duplicateID: 1800, uniqueTask.id: 900]
        )

        let calculator = ReviewStatsCalculator()

        // Before fix: Fatal Error. After fix: works normally.
        let stats = calculator.computePlanningAccuracy(blocks: [block], allTasks: planItems)

        XCTAssertEqual(stats.trackedTaskCount, 2, "Should process both tasks from the block")
        XCTAssertTrue(stats.hasData, "Should have data from the tracked tasks")
    }

    /// Edge case: all tasks have the same ID — must not crash.
    func test_computePlanningAccuracy_withOnlyDuplicates_doesNotCrash() throws {
        let context = container.mainContext
        let sharedUUID = UUID()

        let task1 = LocalTask(title: "Dup 1", importance: 1)
        task1.uuid = sharedUUID
        context.insert(task1)

        let task2 = LocalTask(title: "Dup 2", importance: 1)
        task2.uuid = sharedUUID
        context.insert(task2)

        let planItems = [task1, task2].map { PlanItem(localTask: $0) }

        let calculator = ReviewStatsCalculator()
        let stats = calculator.computePlanningAccuracy(blocks: [], allTasks: planItems)

        XCTAssertFalse(stats.hasData, "No blocks = no tracked data, but must not crash")
    }
}
