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
        let task = LocalTask(title: "Test Task", importance: 2)
        task.sortOrder = 5
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.id, task.id)
        XCTAssertEqual(planItem.title, "Test Task")
        XCTAssertEqual(planItem.importance, 2)
        XCTAssertEqual(planItem.rank, 5)
        XCTAssertFalse(planItem.isCompleted)
    }

    func test_init_fromLocalTask_usesEstimatedDuration() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task", importance: 0)
        task.estimatedDuration = 45
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 45)
        XCTAssertEqual(planItem.durationSource, DurationSource.manual)
    }

    func test_init_fromLocalTask_parsesDurationFromTitle() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Meeting #30min", importance: 0)
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 30)
        XCTAssertEqual(planItem.durationSource, DurationSource.parsed)
    }

    func test_init_fromLocalTask_usesDefaultDuration() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Simple Task", importance: 0)
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 15)
        XCTAssertEqual(planItem.durationSource, DurationSource.default)
    }

    func test_init_fromLocalTask_estimatedDurationOverridesParsed() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Task #30min", importance: 0)
        task.estimatedDuration = 60  // Should override the parsed 30min
        context.insert(task)

        let planItem = PlanItem(localTask: task)

        XCTAssertEqual(planItem.effectiveDuration, 60)
        XCTAssertEqual(planItem.durationSource, DurationSource.manual)
    }
}
