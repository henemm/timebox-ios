import XCTest
import SwiftData
@testable import FocusBlox

@MainActor
final class PlanItemTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - LocalTask Initializer

    func test_init_fromLocalTask_copiesBasicProperties() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task", priority: 2)
        task.sortOrder = 5
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.id, task.id)
        XCTAssertEqual(planItem.title, "Test Task")
        XCTAssertEqual(planItem.priorityValue, 2)
        XCTAssertEqual(planItem.rank, 5)
        XCTAssertFalse(planItem.isCompleted)
    }

    func test_init_fromLocalTask_usesManualDuration() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", priority: 0)
        task.manualDuration = 45
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 45)
        XCTAssertEqual(planItem.durationSource, .manual)
    }

    func test_init_fromLocalTask_parsesDurationFromTitle() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Meeting #30min", priority: 0)
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 30)
        XCTAssertEqual(planItem.durationSource, .parsed)
    }

    func test_init_fromLocalTask_usesDefaultDuration() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Simple Task", priority: 0)
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 15)
        XCTAssertEqual(planItem.durationSource, .default)
    }

    func test_init_fromLocalTask_manualDurationOverridesParsed() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task #30min", priority: 0)
        task.manualDuration = 60  // Should override the parsed 30min
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 60)
        XCTAssertEqual(planItem.durationSource, .manual)
    }
}
