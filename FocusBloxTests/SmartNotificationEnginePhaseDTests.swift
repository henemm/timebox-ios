import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for SmartNotificationEngine Phase D (Review + Settings UI)
/// TDD RED: Tests MUST FAIL — buildReviewRequests is a private empty stub
/// without `now:` parameter.
@MainActor
final class SmartNotificationEnginePhaseDTests: XCTestCase {

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
        UserDefaults.standard.removeObject(forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.removeObject(forKey: "dueDateAdvanceReminderEnabled")
        UserDefaults.standard.removeObject(forKey: "morningReminderHour")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionHour")
    }

    // MARK: - buildReviewRequests Tests

    /// Verhalten: Um 15:00 liefert buildReviewRequests 13 Requests (7 Tage: heute Evening + 6× Morning+Evening).
    /// Bricht wenn: Multi-Day-Loop in buildReviewRequests entfernt wird.
    func test_buildReviewRequests_afternoon_returnsMultiDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // now = heute 15:00 → heute Morning vorbei, heute Evening + 6 weitere Tage komplett
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        // heute Evening (1) + 6 Tage Morning+Evening (12) = 13
        XCTAssertEqual(requests.count, 13,
                       "At 15:00, should return 7-day review requests (13 total)")
    }

    /// Verhalten: Um 21:00 liefert buildReviewRequests 12 Requests (heute vorbei, 6 Tage komplett).
    /// Bricht wenn: Vergangene Slots trotzdem eingeplant werden.
    func test_buildReviewRequests_afterEvening_returnsMultiDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // now = heute 21:00 → heute Morning+Evening vorbei, 6 weitere Tage komplett
        let now = cal.date(bySettingHour: 21, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        // 6 Tage Morning+Evening = 12
        XCTAssertEqual(requests.count, 12,
                       "At 21:00, today is past — should return 6 complete days (12)")
    }

    /// Verhalten: Review-IDs folgen Schema focusblox.review.{date} und focusblox.morning.{date}.
    /// Bricht wenn: Identifier-Schema in buildReviewRequests geaendert wird.
    func test_buildReviewRequests_identifierSchema() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let ids = requests.map(\.identifier)

        XCTAssertTrue(ids.contains(where: { $0.hasPrefix("focusblox.review.") }),
                      "Should contain evening review with prefix focusblox.review.")
        XCTAssertTrue(ids.contains(where: { $0.hasPrefix("focusblox.morning.") }),
                      "Should contain morning review with prefix focusblox.morning.")
    }

    /// Verhalten: Nie mehr als budgetReview (14) Requests.
    /// Bricht wenn: Budget-Cap `Array(requests.prefix(budgetReview))` entfernt wird.
    func test_buildReviewRequests_neverExceedsBudget() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Frueh morgens: beide Requests moeglich
        let now = cal.date(bySettingHour: 6, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        XCTAssertLessThanOrEqual(requests.count, SmartNotificationEngine.budgetReview,
                                  "Review requests must not exceed budget of \(SmartNotificationEngine.budgetReview)")
    }

    // MARK: - Budget Integration Tests (via buildAllRequests)

    /// Verhalten: Bei Profil "balanced" enthaelt buildAllRequests Review-Requests.
    /// Bricht wenn: Profil-Gating in buildAllRequests fuer Review falsch ist,
    ///   oder buildReviewRequests weiterhin [] zurueckgibt.
    func test_buildAllRequests_balanced_includesReview() async throws {
        // Disable due date reminders to isolate review testing
        UserDefaults.standard.set(false, forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.set(false, forKey: "dueDateAdvanceReminderEnabled")

        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced, container: container, eventKitRepo: repo
        )

        let reviewIDs = requests.filter { $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.") }

        XCTAssertGreaterThan(reviewIDs.count, 0,
                             "Balanced profile should include review requests")
    }

    /// Verhalten: Bei Profil "active" schliesst buildAllRequests Review-Requests ein.
    /// Bricht wenn: Active-Profil Reviews nicht einschliesst.
    func test_buildAllRequests_active_includesReview() async throws {
        UserDefaults.standard.set(false, forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.set(false, forKey: "dueDateAdvanceReminderEnabled")

        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .active, container: container, eventKitRepo: repo
        )

        // Review/Morning sollte immer mindestens 1 haben (Morning morgen)
        let reviewIDs = requests.filter { $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.") }
        XCTAssertGreaterThan(reviewIDs.count, 0,
                             "Active profile should include review requests")
    }

    /// Verhalten: Bei Profil "quiet" enthaelt buildAllRequests keine Review-Requests.
    /// Bricht wenn: Quiet-Profil ungewollt Reviews einschliesst.
    func test_buildAllRequests_quiet_excludesReview() async throws {
        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .quiet, container: container, eventKitRepo: repo
        )

        let reviewIDs = requests.filter { $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.") }

        XCTAssertEqual(reviewIDs.count, 0, "Quiet profile should NOT include review requests")
    }

    /// Verhalten: Gesamt-Budget bleibt <= 64 auch mit Review-Requests.
    /// Bricht wenn: Budget-Cap `Array(requests.prefix(64))` in buildAllRequests entfernt wird.
    func test_totalBudget_withReview_neverExceeds64() async throws {
        let cal = Calendar.current
        // Viele Tasks mit dueDate → fuellt Task-Budget
        let tasks = (0..<50).map { i in
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.day! += i + 2
            comps.hour = 18
            comps.minute = 0
            let dueDate = cal.date(from: comps)!
            return makeTask(title: "Task \(i)", dueDate: dueDate)
        }
        let blocks = (0..<5).map { i in
            makeFocusBlock(id: "block-\(i)", minutesFromNow: (i + 1) * 60)
        }
        let container = try makeTestContainer(with: tasks)

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .active,
            container: container,
            eventKitRepo: makeMockRepo(blocks: blocks)
        )

        XCTAssertLessThanOrEqual(requests.count, 64,
                                  "Total requests must never exceed 64 — even with review requests")
    }

    // MARK: - Regression: Phase A/B/C Container Overload bleibt funktional

    /// Verhalten: Container-Overload funktioniert weiterhin nach Phase D Signatur-Aenderungen.
    /// Bricht wenn: Signatur-Aenderungen an buildReviewRequests den Overload brechen.
    func test_containerOverload_stillFunctional() async throws {
        let container = try makeTestContainer()

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced,
            container: container,
            eventKitRepo: makeMockRepo(blocks: [])
        )

        XCTAssertNotNil(requests, "Container overload should still work after Phase D changes")
    }

    // MARK: - Helpers

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

    private func makeTask(title: String, dueDate: Date?) -> LocalTask {
        let task = LocalTask(title: title)
        task.dueDate = dueDate
        return task
    }

    private func makeFocusBlock(id: String, minutesFromNow: Int) -> FocusBlock {
        let start = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
        let end = start.addingTimeInterval(3600)
        return FocusBlock(
            id: id,
            title: "Test Block",
            startDate: start,
            endDate: end,
            taskIDs: [],
            completedTaskIDs: [],
            taskTimes: [:]
        )
    }

    private func makeMockRepo(blocks: [FocusBlock]) -> MockEventKitRepository {
        let repo = MockEventKitRepository()
        repo.mockFocusBlocks = blocks
        return repo
    }
}
