import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for Backlog Hygiene Nudges (#215)
/// TDD RED: All tests MUST FAIL — buildBacklogHygieneRequest() does not exist yet.
@MainActor
final class BacklogHygieneNudgeTests: XCTestCase {

    // MARK: - Notification Request Tests

    /// Verhalten: Bei stale Tasks + balanced Profile → genau 1 Notification-Request
    /// Bricht wenn: buildBacklogHygieneRequest() nicht existiert oder keine Requests zurückgibt
    func test_buildHygieneRequest_withStaleTasks_returnsOneRequest() async throws {
        let tasks = (0..<3).map { i in
            makeStaleTask(title: "Stale \(i)", daysOld: 20 + i)
        }
        let container = try makeTestContainer(with: tasks)

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .balanced,
            container: container
        )

        XCTAssertEqual(requests.count, 1, "Should create exactly 1 hygiene notification")
    }

    /// Verhalten: Notification-Content enthält Task-Anzahl
    /// Bricht wenn: body-Text nicht den Count enthält
    func test_buildHygieneRequest_contentContainsCount() async throws {
        let tasks = (0..<5).map { i in
            makeStaleTask(title: "Task \(i)", daysOld: 15 + i)
        }
        let container = try makeTestContainer(with: tasks)

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .balanced,
            container: container
        )

        let body = requests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("5"), "Notification body should contain stale task count '5', got: \(body)")
    }

    /// Verhalten: Notification hat userInfo mit target=backlog
    /// Bricht wenn: userInfo["target"] nicht gesetzt wird
    func test_buildHygieneRequest_hasBacklogTarget() async throws {
        let tasks = [makeStaleTask(title: "Old", daysOld: 20)]
        let container = try makeTestContainer(with: tasks)

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .balanced,
            container: container
        )

        let target = requests.first?.content.userInfo["target"] as? String
        XCTAssertEqual(target, "backlog", "userInfo target should be 'backlog'")
    }

    /// Verhalten: Keine stale Tasks → kein Request
    /// Bricht wenn: guard !staleTasks.isEmpty entfernt wird
    func test_buildHygieneRequest_noStaleTasks_returnsEmpty() async throws {
        let container = try makeTestContainer()

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .balanced,
            container: container
        )

        XCTAssertTrue(requests.isEmpty, "No stale tasks → no hygiene request")
    }

    /// Verhalten: Quiet Profile → kein Request
    /// Bricht wenn: guard profile != .quiet entfernt wird
    func test_buildHygieneRequest_quietProfile_returnsEmpty() async throws {
        let tasks = [makeStaleTask(title: "Old", daysOld: 20)]
        let container = try makeTestContainer(with: tasks)

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .quiet,
            container: container
        )

        XCTAssertTrue(requests.isEmpty, "Quiet profile should not produce hygiene requests")
    }

    /// Verhalten: Flag disabled → kein Request
    /// Bricht wenn: guard backlogHygieneNudgeEnabled entfernt wird
    func test_buildHygieneRequest_disabledFlag_returnsEmpty() async throws {
        let tasks = [makeStaleTask(title: "Old", daysOld: 20)]
        let container = try makeTestContainer(with: tasks)

        let previousValue = AppSettings.shared.backlogHygieneNudgeEnabled
        AppSettings.shared.backlogHygieneNudgeEnabled = false
        defer { AppSettings.shared.backlogHygieneNudgeEnabled = previousValue }

        let requests = try await SmartNotificationEngine.buildBacklogHygieneRequest(
            profile: .balanced,
            container: container
        )

        XCTAssertTrue(requests.isEmpty, "Disabled flag should not produce hygiene requests")
    }

    // MARK: - ReviewedAt Filter Tests

    /// Verhalten: Task mit reviewedAt < 30 Tage → wird NICHT als stale gezählt
    /// Bricht wenn: hygieneReviewedAt-Filter in findStaleTasks() fehlt
    func test_staleTasksExcludesRecentlyReviewed() {
        let task = makeReviewedPlanItem(title: "Reviewed", daysOld: 20, reviewedDaysAgo: 10)

        let result = BacklogHealthService.findStaleTasks(in: [task])

        XCTAssertTrue(result.isEmpty, "Task reviewed 10 days ago should NOT be stale")
    }

    /// Verhalten: Task mit reviewedAt > 30 Tage → wird als stale gezählt
    /// Bricht wenn: 30-Tage-Schwelle in findStaleTasks() nicht korrekt implementiert
    func test_staleTasksIncludesOldReview() {
        let task = makeReviewedPlanItem(title: "Old Review", daysOld: 45, reviewedDaysAgo: 35)

        let result = BacklogHealthService.findStaleTasks(in: [task])

        XCTAssertEqual(result.count, 1, "Task reviewed 35 days ago should be stale again")
    }

    // MARK: - Helpers

    private func makeStaleTask(title: String, daysOld: Int) -> LocalTask {
        LocalTask(title: title, createdAt: daysAgo(daysOld))
    }

    private func makeReviewedPlanItem(
        title: String,
        daysOld: Int,
        reviewedDaysAgo: Int
    ) -> PlanItem {
        let task = LocalTask(title: title, createdAt: daysAgo(daysOld))
        task.hygieneReviewedAt = daysAgo(reviewedDaysAgo)
        return PlanItem(localTask: task)
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    private func makeTestContainer(with tasks: [LocalTask] = []) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalTask.self, configurations: config)
        let context = container.mainContext
        for task in tasks {
            context.insert(task)
        }
        try context.save()
        return container
    }
}
