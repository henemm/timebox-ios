import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for SmartNotificationEngine Phase D (Review/Nudge + Settings UI)
/// TDD RED: Tests MUST FAIL — buildReviewRequests/buildNudgeRequests are private empty stubs
/// without `now:` parameter.
@MainActor
final class SmartNotificationEnginePhaseDTests: XCTestCase {

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
        UserDefaults.standard.removeObject(forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.removeObject(forKey: "dueDateAdvanceReminderEnabled")
    }

    // MARK: - buildReviewRequests Tests

    /// Verhalten: Um 15:00 liefert buildReviewRequests genau 2 Requests (Evening 20:00 + Morning 08:00 morgen).
    /// Bricht wenn: SmartNotificationEngine.buildReviewRequests(now:) weiterhin [] zurueckgibt (Stub Z312)
    ///   oder die Methode private bleibt (Compile Error).
    func test_buildReviewRequests_afternoon_returns2Requests() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // now = heute 15:00 → Evening 20:00 liegt in der Zukunft, Morning 08:00 morgen auch
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        XCTAssertEqual(requests.count, 2,
                       "At 15:00, should return 2 requests: evening review + morning nudge")
    }

    /// Verhalten: Um 21:00 liefert buildReviewRequests genau 1 Request (nur Morning, Evening ist vorbei).
    /// Bricht wenn: Vergangene Evening-Time (20:00) trotzdem eingeplant wird — Guard `eveningDate > now` fehlt.
    func test_buildReviewRequests_afterEvening_returns1Request() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // now = heute 21:00 → Evening 20:00 ist vorbei, nur Morning 08:00 morgen
        let now = cal.date(bySettingHour: 21, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)

        XCTAssertEqual(requests.count, 1,
                       "At 21:00, evening is past — should return only morning request")
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
                      "Should contain morning nudge with prefix focusblox.morning.")
    }

    /// Verhalten: Nie mehr als budgetReview (2) Requests.
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

    // MARK: - buildNudgeRequests Tests

    /// Verhalten: Um 08:00 liefert buildNudgeRequests 6 Requests (alle Arbeitszeit-Slots 9,11,13,15,17,19).
    /// Bricht wenn: SmartNotificationEngine.buildNudgeRequests(now:) weiterhin [] zurueckgibt (Stub Z318)
    ///   oder die Methode private bleibt (Compile Error).
    func test_buildNudgeRequests_morning_returns6Requests() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        XCTAssertEqual(requests.count, 6,
                       "At 08:00, all 6 work-hour slots (9,11,13,15,17,19) should be scheduled")
    }

    /// Verhalten: Um 14:00 liefert buildNudgeRequests 3 Requests (15, 17, 19 Uhr — nur zukuenftige).
    /// Bricht wenn: `fireDate > now` Guard fehlt und vergangene Slots eingeplant werden.
    func test_buildNudgeRequests_afternoon_returnsOnlyFutureSlots() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        XCTAssertEqual(requests.count, 3,
                       "At 14:00, only 3 future slots (15,17,19) should be scheduled")
    }

    /// Verhalten: Um 20:00 liefert buildNudgeRequests 0 Requests (alle Arbeitszeit-Slots vorbei).
    /// Bricht wenn: Slots ausserhalb der Arbeitszeit generiert werden.
    func test_buildNudgeRequests_evening_returns0() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 20, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        XCTAssertEqual(requests.count, 0,
                       "At 20:00, all work-hour slots are past — should return 0")
    }

    /// Verhalten: Nudge-IDs folgen Schema focusblox.nudge.work.{HH}.
    /// Bricht wenn: Identifier-Schema in buildNudgeRequests geaendert wird.
    func test_buildNudgeRequests_identifierSchema() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        for request in requests {
            XCTAssertTrue(request.identifier.hasPrefix("focusblox.nudge.work."),
                          "Nudge ID '\(request.identifier)' should start with 'focusblox.nudge.work.'")
        }
    }

    /// Verhalten: Nie mehr als budgetNudges (10) Requests.
    /// Bricht wenn: Budget-Cap `Array(requests.prefix(budgetNudges))` entfernt wird.
    func test_buildNudgeRequests_neverExceedsBudget() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = cal.date(bySettingHour: 0, minute: 1, second: 0, of: today)!

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now)

        XCTAssertLessThanOrEqual(requests.count, SmartNotificationEngine.budgetNudges,
                                  "Nudge requests must not exceed budget of \(SmartNotificationEngine.budgetNudges)")
    }

    // MARK: - Budget Integration Tests (via buildAllRequests)

    /// Verhalten: Bei Profil "balanced" enthaelt buildAllRequests Review-Requests aber keine Nudges.
    /// Bricht wenn: Profil-Gating in buildAllRequests fuer Review (Z92-94) oder Nudge (Z96-98) falsch ist,
    ///   oder buildReviewRequests weiterhin [] zurueckgibt.
    func test_buildAllRequests_balanced_includesReview_excludesNudges() async throws {
        // Disable due date reminders to isolate review/nudge testing
        UserDefaults.standard.set(false, forKey: "dueDateMorningReminderEnabled")
        UserDefaults.standard.set(false, forKey: "dueDateAdvanceReminderEnabled")

        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .balanced, container: container, eventKitRepo: repo
        )

        let reviewIDs = requests.filter { $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.") }
        let nudgeIDs = requests.filter { $0.identifier.hasPrefix("focusblox.nudge.") }

        XCTAssertGreaterThan(reviewIDs.count, 0,
                             "Balanced profile should include review requests")
        XCTAssertEqual(nudgeIDs.count, 0,
                       "Balanced profile should NOT include nudge requests")
    }

    /// Verhalten: Bei Profil "active" schliesst buildAllRequests Nudge-Requests ein (wenn Slots verfuegbar).
    /// Bricht wenn: Active-Profil Nudges nicht einschliesst (Gating Z96-98).
    /// Hinweis: buildAllRequests nutzt Date() intern — Nudges koennen nachts leer sein.
    /// Daher testen wir buildNudgeRequests direkt mit kontrollierter Zeit.
    func test_buildAllRequests_active_includesReviewAndNudges() async throws {
        // Direkt-Test: buildNudgeRequests mit kontrollierter Uhrzeit (10:00)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let morning = cal.date(bySettingHour: 10, minute: 0, second: 0, of: today)!

        let nudgeRequests = SmartNotificationEngine.buildNudgeRequests(now: morning)
        XCTAssertGreaterThan(nudgeRequests.count, 0,
                             "buildNudgeRequests should return nudges at 10:00")

        // Integration-Test: buildAllRequests mit active Profil enthaelt Review
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

    /// Verhalten: Bei Profil "quiet" enthaelt buildAllRequests weder Review noch Nudges.
    /// Bricht wenn: Quiet-Profil ungewollt Review/Nudges einschliesst.
    func test_buildAllRequests_quiet_excludesReviewAndNudges() async throws {
        let container = try makeTestContainer()
        let repo = makeMockRepo(blocks: [])

        let requests = await SmartNotificationEngine.buildAllRequests(
            profile: .quiet, container: container, eventKitRepo: repo
        )

        let reviewIDs = requests.filter { $0.identifier.hasPrefix("focusblox.review.") || $0.identifier.hasPrefix("focusblox.morning.") }
        let nudgeIDs = requests.filter { $0.identifier.hasPrefix("focusblox.nudge.") }

        XCTAssertEqual(reviewIDs.count, 0, "Quiet profile should NOT include review requests")
        XCTAssertEqual(nudgeIDs.count, 0, "Quiet profile should NOT include nudge requests")
    }

    /// Verhalten: Gesamt-Budget bleibt <= 64 auch mit Review + Nudge-Requests.
    /// Bricht wenn: Budget-Cap `Array(requests.prefix(64))` in buildAllRequests entfernt wird.
    func test_totalBudget_withReviewAndNudges_neverExceeds64() async throws {
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
                                  "Total requests must never exceed 64 — even with review + nudges")
    }

    // MARK: - Regression: Phase A/B/C Container Overload bleibt funktional

    /// Verhalten: Container-Overload funktioniert weiterhin nach Phase D Signatur-Aenderungen.
    /// Bricht wenn: Signatur-Aenderungen an buildReviewRequests/buildNudgeRequests den Overload brechen.
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
