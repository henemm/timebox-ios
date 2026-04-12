import XCTest
@testable import FocusBlox

final class BacklogHealthServiceTests: XCTestCase {

    // MARK: - Helper

    private func makePlanItem(
        title: String = "Test Task",
        createdAt: Date = Date(),
        rescheduleCount: Int = 0,
        isCompleted: Bool = false,
        isParked: Bool = false,
        isTemplate: Bool = false
    ) -> PlanItem {
        let task = LocalTask(title: title, createdAt: createdAt)
        task.rescheduleCount = rescheduleCount
        task.isCompleted = isCompleted
        task.isParked = isParked
        task.isTemplate = isTemplate
        return PlanItem(localTask: task)
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    // MARK: - Age-based detection

    func test_findStaleTasks_oldTask_isIncluded() {
        let old = makePlanItem(title: "Alte Aufgabe", createdAt: daysAgo(15))
        let result = BacklogHealthService.findStaleTasks(in: [old])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Alte Aufgabe")
    }

    func test_findStaleTasks_recentTask_isExcluded() {
        let recent = makePlanItem(title: "Neue Aufgabe", createdAt: daysAgo(3))
        let result = BacklogHealthService.findStaleTasks(in: [recent])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Reschedule-based detection

    func test_findStaleTasks_highRescheduleCount_isIncluded() {
        let rescheduled = makePlanItem(title: "Oft verschoben", rescheduleCount: 3)
        let result = BacklogHealthService.findStaleTasks(in: [rescheduled])
        XCTAssertEqual(result.count, 1)
    }

    func test_findStaleTasks_lowRescheduleCount_isExcluded() {
        let once = makePlanItem(title: "Einmal verschoben", rescheduleCount: 1)
        let result = BacklogHealthService.findStaleTasks(in: [once])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Exclusions

    func test_findStaleTasks_completedTask_isExcluded() {
        let done = makePlanItem(title: "Erledigt", createdAt: daysAgo(30), isCompleted: true)
        let result = BacklogHealthService.findStaleTasks(in: [done])
        XCTAssertTrue(result.isEmpty)
    }

    func test_findStaleTasks_parkedTask_isExcluded() {
        let parked = makePlanItem(title: "Geparkt", createdAt: daysAgo(30), isParked: true)
        let result = BacklogHealthService.findStaleTasks(in: [parked])
        XCTAssertTrue(result.isEmpty)
    }

    func test_findStaleTasks_templateTask_isExcluded() {
        let template = makePlanItem(title: "Template", createdAt: daysAgo(30), isTemplate: true)
        let result = BacklogHealthService.findStaleTasks(in: [template])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Sorting

    func test_findStaleTasks_sortedOldestFirst() {
        let older = makePlanItem(title: "Älterer", createdAt: daysAgo(30))
        let newer = makePlanItem(title: "Neuerer", createdAt: daysAgo(15))
        let result = BacklogHealthService.findStaleTasks(in: [newer, older])
        XCTAssertEqual(result.first?.title, "Älterer")
        XCTAssertEqual(result.last?.title, "Neuerer")
    }

    // MARK: - Custom thresholds

    func test_findStaleTasks_customThresholds() {
        let task = makePlanItem(title: "7 Tage alt", createdAt: daysAgo(7))
        let resultDefault = BacklogHealthService.findStaleTasks(in: [task])
        XCTAssertTrue(resultDefault.isEmpty, "Should not be stale with default 14-day threshold")

        let resultCustom = BacklogHealthService.findStaleTasks(in: [task], staleAgeDays: 5)
        XCTAssertEqual(resultCustom.count, 1, "Should be stale with 5-day threshold")
    }

    // MARK: - Empty input

    func test_findStaleTasks_emptyInput_returnsEmpty() {
        let result = BacklogHealthService.findStaleTasks(in: [])
        XCTAssertTrue(result.isEmpty)
    }
}
