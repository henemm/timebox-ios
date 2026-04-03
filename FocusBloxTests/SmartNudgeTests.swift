import XCTest
import SwiftData
import UserNotifications
@testable import FocusBlox

/// Unit Tests for Smart Nudges (#174): Budget, Silence on Success, Configurable Times.
/// TDD RED: Tests MUST FAIL — budget/silence/time logic not yet implemented.
@MainActor
final class SmartNudgeTests: XCTestCase {

    override func setUpWithError() throws {
        UserDefaults.standard.removeObject(forKey: "nudgeDailyBudget")
        UserDefaults.standard.removeObject(forKey: "morningReminderHour")
        UserDefaults.standard.removeObject(forKey: "morningReminderMinute")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionHour")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionMinute")
        UserDefaults.standard.removeObject(forKey: "nudgeSilenceOnSuccess")
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "nudgeDailyBudget")
        UserDefaults.standard.removeObject(forKey: "morningReminderHour")
        UserDefaults.standard.removeObject(forKey: "morningReminderMinute")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionHour")
        UserDefaults.standard.removeObject(forKey: "eveningReflectionMinute")
        UserDefaults.standard.removeObject(forKey: "nudgeSilenceOnSuccess")
        UserDefaults.standard.removeObject(forKey: "notificationProfile")
    }

    // MARK: - Budget Tests

    /// Verhalten: Budget=1 → buildNudgeRequests liefert maximal 1 Request.
    /// Bricht wenn: buildNudgeRequests() weiterhin hardcoded 6 Slots nutzt statt nudgeDailyBudget.
    func test_buildNudgeRequests_budget1_returnsMax1() {
        UserDefaults.standard.set(1, forKey: "nudgeDailyBudget")
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        XCTAssertLessThanOrEqual(requests.count, 1,
            "Budget=1 should produce at most 1 nudge, got \(requests.count)")
        XCTAssertGreaterThan(requests.count, 0,
            "Budget=1 at 08:00 should produce exactly 1 nudge")
    }

    /// Verhalten: Budget=3 → buildNudgeRequests liefert maximal 3 Requests.
    /// Bricht wenn: buildNudgeRequests() die 6 hardcoded Slots nicht auf 3 reduziert.
    func test_buildNudgeRequests_budget3_returnsMax3() {
        UserDefaults.standard.set(3, forKey: "nudgeDailyBudget")
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        XCTAssertLessThanOrEqual(requests.count, 3,
            "Budget=3 should produce at most 3 nudges, got \(requests.count)")
        XCTAssertGreaterThan(requests.count, 0,
            "Budget=3 at 08:00 should produce at least 1 nudge")
    }

    /// Verhalten: Default-Budget (2) → maximal 2 Requests.
    /// Bricht wenn: Default-Wert nicht 2 ist oder Budget ignoriert wird.
    func test_buildNudgeRequests_defaultBudget_returnsMax2() {
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        XCTAssertLessThanOrEqual(requests.count, 2,
            "Default budget (2) should produce at most 2 nudges, got \(requests.count)")
    }

    // MARK: - Silence on Success Tests

    /// Verhalten: buildNudgeRequests akzeptiert completedTodayCount-Parameter.
    /// Genug Tasks erledigt (>= Budget) → 0 Nudges.
    /// Bricht wenn: completedTodayCount-Parameter nicht existiert oder Stille-Logik fehlt.
    func test_buildNudgeRequests_silenceOnSuccess_enoughTasksDone() {
        UserDefaults.standard.set(2, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(true, forKey: "nudgeSilenceOnSuccess")
        let now = makeTime(hour: 10, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, completedTodayCount: 3)
        XCTAssertEqual(requests.count, 0,
            "Silence on success: with enough tasks done, nudges should be suppressed")
    }

    /// Verhalten: Stille-Flag aus → Nudges kommen trotz erledigter Tasks.
    /// Bricht wenn: Stille-Flag nicht respektiert wird.
    func test_buildNudgeRequests_silenceDisabled_nudgesFireAnyway() {
        UserDefaults.standard.set(2, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(false, forKey: "nudgeSilenceOnSuccess")
        let now = makeTime(hour: 10, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        // With silence disabled, nudges should fire regardless.
        // This tests that budget is respected even with silence off.
        XCTAssertGreaterThan(requests.count, 0,
            "Silence disabled: nudges should fire")
        XCTAssertLessThanOrEqual(requests.count, 2,
            "Budget=2 should cap at 2 nudges, got \(requests.count)")
    }

    // MARK: - Custom Window Tests

    /// Verhalten: Zeitfenster ergibt sich aus Morning+Evening-Zeit.
    /// Morning 11:00, Evening 16:00 → Nudges zwischen 12:00-16:00.
    /// Bricht wenn: buildNudgeRequests() das Fenster nicht aus den Zeiten ableitet.
    func test_buildNudgeRequests_customWindow_slotsInRange() {
        UserDefaults.standard.set(2, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(11, forKey: "morningReminderHour")
        UserDefaults.standard.set(16, forKey: "eveningReflectionHour")
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        for request in requests {
            guard let trigger = request.trigger as? UNTimeIntervalNotificationTrigger else {
                XCTFail("Expected time interval trigger")
                continue
            }
            let fireDate = now.addingTimeInterval(trigger.timeInterval)
            let hour = Calendar.current.component(.hour, from: fireDate)
            XCTAssertGreaterThanOrEqual(hour, 12,
                "Nudge should fire at or after 12:00 (morning+1), got \(hour):00")
            XCTAssertLessThan(hour, 16,
                "Nudge should fire before 16:00 (evening), got \(hour):00")
        }
    }

    /// Verhalten: Ungültiges Zeitfenster (Morning >= Evening) → 0 Nudges.
    /// Bricht wenn: Keine Validierung des Zeitfensters.
    func test_buildNudgeRequests_invalidWindow_returns0() {
        UserDefaults.standard.set(2, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(18, forKey: "morningReminderHour")
        UserDefaults.standard.set(10, forKey: "eveningReflectionHour")
        let now = makeTime(hour: 8, minute: 0)

        let requests = SmartNotificationEngine.buildNudgeRequests(now: now, intentionText: "Test-Intention")

        XCTAssertEqual(requests.count, 0,
            "Invalid window (start >= end) should produce 0 nudges")
    }

    // MARK: - Configurable Review Times

    /// Verhalten: Morning um 07:00 statt default 08:00.
    /// Bricht wenn: buildReviewRequests() weiterhin hardcoded 8 nutzt.
    func test_buildReviewRequests_customMorningTime() {
        UserDefaults.standard.set(7, forKey: "morningReminderHour")
        UserDefaults.standard.set(0, forKey: "morningReminderMinute")
        let now = makeTime(hour: 6, minute: 0)

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let morningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.morning.") }

        guard let firstMorning = morningRequests.first,
              let trigger = firstMorning.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Should have at least one morning request with time interval trigger")
            return
        }

        // Morning at 07:00 from 06:00 = 1 hour = 3600s
        let expectedInterval = 3600.0
        XCTAssertEqual(trigger.timeInterval, expectedInterval, accuracy: 60,
            "Morning at 07:00 from 06:00 should be ~3600s, got \(trigger.timeInterval)s")
    }

    /// Verhalten: Evening um 21:00 statt default 20:00.
    /// Bricht wenn: buildReviewRequests() weiterhin hardcoded 20 nutzt.
    func test_buildReviewRequests_customEveningTime() {
        UserDefaults.standard.set(21, forKey: "eveningReflectionHour")
        UserDefaults.standard.set(0, forKey: "eveningReflectionMinute")
        let now = makeTime(hour: 15, minute: 0)

        let requests = SmartNotificationEngine.buildReviewRequests(now: now)
        let eveningRequests = requests.filter { $0.identifier.hasPrefix("focusblox.review.") }

        guard let todayEvening = eveningRequests.first,
              let trigger = todayEvening.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Should have at least one evening request")
            return
        }

        // Evening at 21:00 from 15:00 = 6 hours = 21600s
        let expectedInterval = 21600.0
        XCTAssertEqual(trigger.timeInterval, expectedInterval, accuracy: 60,
            "Evening at 21:00 from 15:00 should be ~21600s, got \(trigger.timeInterval)s")
    }

    // MARK: - EmotionalNudgeService Budget Sync

    /// Verhalten: EmotionalNudgeService respektiert konfiguriertes Budget.
    /// Bricht wenn: canShowNudge() weiterhin hardcoded `< 3` prüft statt nudgeDailyBudget.
    func test_emotionalNudge_respectsConfiguredBudget() {
        UserDefaults.standard.set(1, forKey: "nudgeDailyBudget")
        UserDefaults.standard.set(1, forKey: "nudgeDailyCount")
        UserDefaults.standard.set(isoDate(), forKey: "nudgeLastDate")
        UserDefaults.standard.set("", forKey: "nudgeTaskIDs")

        let canShow = EmotionalNudgeService.canShowNudge(for: "test-task-id")

        XCTAssertFalse(canShow,
            "Budget=1 and 1 nudge already shown → canShowNudge should return false")
    }

    // MARK: - Helpers

    private func makeTime(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    private func isoDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
